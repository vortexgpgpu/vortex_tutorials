# Assignment #5: Dot Product Acceleration (SimX)

This assignment will introduce you to the basics of extending GPU Microarchitecture to accelerate a kernel in hardware
You will add a new RISC-V custom instruction for computing the integer dot product: VX\_DOT8.
You will also implement this instruction in the SimX cycle-level simulator.

### Step 1: ISA Extension

VX\_DOT8 calculates the dot product of two 4x4 vectors of int8 integers.

```
Dot Product = (A1*B1 + A2*B2 + A3*B3 + A4*B4)
```

The instruction format is as follows:

```
VX_DOT8 rd, rs1, rs2
```
where each source registers rs1 and rs2 hold four int8 elements.

```
rs1 := {A1, A2, A3, A4}
rs2 := {B1, B2, B3, B4}
rd  := destination int32 result
```

Use the R-Type RISC-V instruction format.

```
| funct7  | rs2    | rs1    | funct3 | rd    | opcode |
|  7 bits | 5 bits | 5 bits | 3 bits | 5 bit | 7 bits |
```

where:

```
opcode: opcode reserved for custom instructions.
funct3 and funct7: opcode modifiers.
```
Use custom extension opcode=0x0B with func7=1 and func3=0;

You will need to modify `vx_intrinsics.h` to add your new VX_DOT8 instruction.

``` c++
// DOT8
inline int vx_dot8(int a, int b) {
  size_t ret;
  asm volatile (".insn r ?, ?, ?, ?, ?, ?" : "=r"(?) : "i"(?), "r"(?), "r"(?));
  return ret;
}

```

Read the following doc to understand insn speudo-instruction format
https://sourceware.org/binutils/docs/as/RISC_002dV_002dFormats.html

### Step 2: Matrix Multiplication Kernel

Implement a simple matrix multiplication GPU kernel that uses your new H/W extension.

Here is a basic C++ implementation of the kernel that uses our new VX\_DOT8 instruction:

``` c++
void MatrixMultiply(int8_t A[][N], int8_t B[][N], int32_t C[][N], int N) {
  for (int i = 0; i < N; ++i) {
    for (int j = 0; j < N; ++j) {
      C[i][j] = 0;
      for (int k = 0; k < N; k += 4) {
        // Pack 4 int8_t elements from A and B into 32-bit integers
        uint32_t packedA = *((int*)(A[i] + k));
        uint32_t packedB = (uint8_t)B[k][j]
                         | ((uint8_t)B[k+1][j] << 8)
                         | ((uint8_t)B[k+2][j] << 16)
                         | ((uint8_t)B[k+3][j] << 24);
        // Accumulate the dot product result into the C
        C[i][j] += vx_dot8(packedA, packedB);
      }
    }
  }
}

```

- Clone sgemmx test under https://github.com/vortexgpgpu/vortex/blob/master/tests/regression/sgemmx into a new folder `tests/regressions/dot8`.

- Set PROJECT name to `dot8` in `tests/regressions/dot8/Makefile`
- Update `matmul_cpu` in main.cpp to operate on `int8_t` matrices.
- Update `kernel_body` in `tests/regressions/dot8/kernel.cpp` to use `vx_dot8`

### Step 3: Simulation implementation

Modify the cycle level simulator to implement the custom ISA extension.
We recommend checking out how VX_SPLIT and VX_PRED instructions are decoded in SimX as reference.

 - Update `op_string()` in `decode.cpp` to print out the new instruction.
 - Update `Emulator::decode()` in `decode.cpp` to decode the new instruction format.

``` c++
switch (func7) {
case 1:
  switch (func3) {
  case 0:  // DOT8
    instr->setDestReg(rd, RegType::Integer);
    instr->addSrcReg(rs1, RegType::Integer);
    instr->addSrcReg(rs2, RegType::Integer);
    break;
 ```

 - Update `AluType` enum in `types.h` to add `DOT8` type
 - Update `Emulator::execute()` in `execute.cpp` to implement the actual `VX_DOT8` emulation. You will execute the new instruction on the ALU functional unit.

``` c++
switch (func7) {
case 1:
  switch (func3) {
  case 0: { // DOT8
      trace->fu_type = FUType::ALU;
      trace->alu_type = AluType::DOT8;
      trace->src_regs[0] = {RegType::Integer, rsrc0};
      trace->src_regs[1] = {RegType::Integer, rsrc1};
      for (uint32_t t = thread_start; t < num_threads; ++t) {
        if (!warp.tmask.test(t))
          continue;
        // TODO:
      }
      rd_write = true;
    } break;
  } break;
}
```

 - Update `AluUnit::tick()` in `func_unit.cpp` to implement the timing of `VX_DOT8`.
 You will assume 2 cycles latency for the dot-product execution.

 ``` c++
case AluType::DOT8:
  // TODO:
  break;
 ```

### Step 4: Testing

You will compare your new accelerated dot8 program with the existing sgemmx kernel under the regression codebase.
You will use N=128 and (warps=4, threads=4) and (Warps=16, threads=16) for 1 and 4 cores.
Plot the IPC to observe the performance improvement.
