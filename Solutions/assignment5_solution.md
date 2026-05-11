# Assignment 5: Dot Product Acceleration (SimX) — Solution

This document walks through the complete solution for extending the Vortex GPU microarchitecture with a custom `VX_DOT8` RISC-V instruction and implementing it in the SimX cycle-level simulator.

---

## Overview

`VX_DOT8` computes the integer dot product of two packed vectors of four `int8` elements:

```
rd = A1*B1 + A2*B2 + A3*B3 + A4*B4
```

The instruction uses the **R-Type** RISC-V format with:
- `opcode = 0x0B` (RISC-V custom-0)
- `funct7 = 3`
- `funct3 = 0`

---

## Step 1: ISA Extension — `vx_intrinsics.h`

Add the `vx_dot8` inline intrinsic using GAS `.insn r` pseudo-instruction syntax.

```cpp
// DOT8: computes dot product of two packed int8x4 vectors
inline int vx_dot8(int a, int b) {
  int ret;
  asm volatile (".insn r %1, 0, 3, %0, %2, %3"
    : "=r"(ret)
    : "i"(RISCV_CUSTOM0), "r"(a), "r"(b));
  return ret;
}
```

**Breakdown of `.insn r` arguments:**
| Field    | Value           | Notes                          |
|----------|-----------------|--------------------------------|
| opcode   | `RISCV_CUSTOM0` | Expands to `0x0B`              |
| funct3   | `0`             | Selects DOT8 within custom ops |
| funct7   | `3`             | Selects DOT8 within custom ops |
| rd       | `%0`            | Output register                |
| rs1      | `%2`            | Packed A input                 |
| rs2      | `%3`            | Packed B input                 |

> Reference: [RISC-V `.insn` format — GNU Binutils docs](https://sourceware.org/binutils/docs/as/RISC_002dV_002dFormats.html)

---

## Step 2: Matrix Multiplication Kernel

### Directory Setup

Clone `tests/regression/sgemm` into `tests/regression/dot8` and update the Makefile:

```makefile
# tests/regression/dot8/Makefile
ROOT_DIR := $(realpath ../../..)
include $(ROOT_DIR)/config.mk

PROJECT := dot8

SRC_DIR := $(VORTEX_HOME)/tests/regression/$(PROJECT)
SRCS    := $(SRC_DIR)/main.cpp
VX_SRCS := $(SRC_DIR)/kernel.cpp

OPTS ?= -n32

include ../common.mk
```

### `common.h`

Define the source and destination types used across the kernel and host:

```cpp
#ifndef _COMMON_H_
#define _COMMON_H_

typedef int8_t  SrcType;
typedef int32_t DstType;

typedef struct {
  uint32_t grid_dim[2];
  uint32_t size;
  uint64_t A_addr;
  uint64_t B_addr;
  uint64_t C_addr;
} kernel_arg_t;

#endif
```

### `kernel.cpp`

Each GPU thread computes one output cell `C[row][col]`. Rows from A and columns from B are packed into `uint32_t` registers before calling `vx_dot8`.

```cpp
void kernel_body(kernel_arg_t* __UNIFORM__ arg) {
    auto A    = reinterpret_cast<SrcType*>(arg->A_addr);
    auto B    = reinterpret_cast<SrcType*>(arg->B_addr);
    auto C    = reinterpret_cast<DstType*>(arg->C_addr);
    auto size = arg->size;

    int row = blockIdx.x;
    int col = blockIdx.y;

    DstType sum(0);
    for (int k = 0; k < size; k += 4) {
        // Pack 4 consecutive elements from row of A (row-major)
        uint32_t packedA = *((uint32_t*)(A + (row * size + k)));

        // Pack 4 elements from column of B (row-major, non-contiguous)
        uint32_t packedB = ((uint8_t)B[(k + 0) * size + col] <<  0)
                         | ((uint8_t)B[(k + 1) * size + col] <<  8)
                         | ((uint8_t)B[(k + 2) * size + col] << 16)
                         | ((uint8_t)B[(k + 3) * size + col] << 24);

        sum += vx_dot8(packedA, packedB);
    }

    C[row * size + col] = sum;
}

int main() {
    kernel_arg_t* arg = (kernel_arg_t*)csr_read(VX_CSR_MSCRATCH);
    return vx_spawn_threads(2, arg->grid_dim, nullptr,
                            (vx_kernel_func_cb)kernel_body, arg);
}
```

### `main.cpp` — Key Changes from `sgemm`

**Types:** Use `SrcType` (`int8_t`) for input matrices and `DstType` (`int32_t`) for the output.

**Buffer sizes** must reflect the correct element size in bytes:
```cpp
uint32_t src_buf_size = size * size * sizeof(SrcType);  // int8_t buffers
uint32_t dst_buf_size = size * size * sizeof(DstType);  // int32_t buffer
```

**CPU reference implementation** for verification:
```cpp
static void matmul_cpu(DstType* out, const SrcType* A, const SrcType* B,
                       uint32_t width, uint32_t height) {
    for (uint32_t row = 0; row < height; ++row) {
        for (uint32_t col = 0; col < width; ++col) {
            DstType sum(0);
            for (uint32_t e = 0; e < width; ++e) {
                sum += (DstType)(A[row * width + e]) * (DstType)(B[e * width + col]);
            }
            out[row * width + col] = sum;
        }
    }
}
```

---

## Step 3: SimX Simulator Implementation

### `types.h` — Add `DOT8` to `AluType`

```cpp
enum class AluType {
  // ... existing types ...
  CZERO,
  DOT8   // <-- add this
};

// Also update the ostream operator:
inline std::ostream& operator<<(std::ostream& os, const AluType& type) {
  switch (type) {
    // ... existing cases ...
    case AluType::DOT8:  os << "DOT8"; break;
    default: assert(false);
  }
  return os;
}
```

### `decode.cpp` — Decode the New Instruction

Add the `DOT8` string in `op_string()`:

```cpp
case AluType::DOT8: return {"DOT8", ""};
```

Add a new `case 3` block inside the custom-instruction switch in `Emulator::decode()`:

```cpp
case 3: {
    switch (funct3) {
    case 0: { // DOT8
        auto instr = std::allocate_shared<Instr>(instr_pool_, uuid, FUType::ALU);
        instr->setOpType(AluType::DOT8);
        instr->setArgs(IntrAluArgs{0, 0, 0});
        instr->setDestReg(rd,  RegType::Integer);
        instr->setSrcReg(0, rs1, RegType::Integer);
        instr->setSrcReg(1, rs2, RegType::Integer);
        ibuffer.push_back(instr);
    } break;
    default:
        std::abort();
    }
} break;
```

### `execute.cpp` — Emulate the Dot Product

Add a `DOT8` case inside the ALU execution switch. Each byte is sign-extended to `int8_t` before multiplication, and products are accumulated as `int32_t`:

```cpp
case AluType::DOT8: {
    for (uint32_t t = thread_start; t < num_threads; ++t) {
        if (!warp.tmask.test(t))
            continue;

        uint32_t packedA = rs1_data[t].u;
        uint32_t packedB = rs2_data[t].u;

        // Extract and sign-extend each byte
        int8_t a0 = (int8_t)(packedA      ), b0 = (int8_t)(packedB      );
        int8_t a1 = (int8_t)(packedA >>  8), b1 = (int8_t)(packedB >>  8);
        int8_t a2 = (int8_t)(packedA >> 16), b2 = (int8_t)(packedB >> 16);
        int8_t a3 = (int8_t)(packedA >> 24), b3 = (int8_t)(packedB >> 24);

        int32_t sum = (int32_t)(a0 * b0)
                    + (int32_t)(a1 * b1)
                    + (int32_t)(a2 * b2)
                    + (int32_t)(a3 * b3);

        DP(3, "*** DOT8[" << t << "]: a=0x" << std::hex << packedA
               << ", b=0x" << packedB << ", c=0x" << sum << std::dec);

        rd_data[t].i = sum;
    }
} break;
```

### `func_unit.cpp` — Set 2-Cycle Latency

Add `DOT8` to the 2-cycle latency group in `AluUnit::tick()`:

```cpp
case AluType::AND:
case AluType::OR:
case AluType::CZERO:
case AluType::DOT8:   // <-- add here
    delay = 2;
    break;
```

---

## Step 4: Testing

### Build and Run

```bash
# Build the dot8 regression test
make -C tests/regression/dot8

# Build the simulator
make -s

# Run with SimX (4 cores, 4 warps, 4 threads)
./ci/blackbox.sh --driver=simx --cores=4 --warps=4 --threads=4 --app=dot8
```

### Performance Sweep

Run the following configurations with `N=256` on a 4-core GPU and record **total instruction count** and **execution cycles**:

| Warps | Threads |
|-------|---------|
| 4     | 4       |
| 4     | 8       |
| 8     | 4       |
| 8     | 8       |

Compare against the scalar `int8_t` baseline kernel. The `VX_DOT8` version should show a meaningful reduction in instruction count by replacing 4 multiplies + 3 adds with a single fused instruction.
