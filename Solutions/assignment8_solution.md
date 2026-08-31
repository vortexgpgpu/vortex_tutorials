# Assignment 8: Tensor Core Extension (SimX) — Solution

This document walks through the complete solution for extending the Vortex Tensor Core to support the **TF32** input format in the SimX cycle-level simulator.

---

## Overview

TF32 (TensorFloat-32) is a 19-bit floating-point format padded to 32 bits:

| Field    | Width |
|----------|-------|
| Sign     | 1 bit |
| Exponent | 8 bits |
| Mantissa | 10 bits |
| Padding  | 13 bits (to fill 32-bit register) |

It shares the same exponent range as IEEE fp32 but has the same mantissa precision as fp16, making it a natural drop-in for MMA operations that want fp32 dynamic range without full fp32 compute cost.

The changes required are minimal and localized to two files: `sim/common/tensor_cfg.h` and `sim/simx/tensor_unit.cpp`.

---

## Step 1: Add TF32 Format Definition — `tensor_cfg.h`

Add the `tf32` struct alongside the existing format definitions (`fp16`, `bf16`, etc.):

```cpp
struct tf32 {
  using dtype = uint32_t;              // stored in a 32-bit register
  static constexpr uint32_t id   = 3; // unique format ID used in select_FEDP
  static constexpr uint32_t bits = 32;
  static constexpr const char* name = "tf32";
};
```

Then register it in `fmt_string()` so the simulator can print the format name in logs and error messages:

```cpp
inline const char* fmt_string(uint32_t fmt) {
  switch (fmt) {
  case fp16::id:  return fp16::name;
  case bf16::id:  return bf16::name;
  case fp32::id:  return fp32::name;
  case int8::id:  return int8::name;
  case uint8::id: return uint8::name;
  case int4::id:  return int4::name;
  case uint4::id: return uint4::name;
  case tf32::id:  return tf32::name;  // <-- add this
  default:        return "";
  }
}
```

---

## Step 2: FMA Specialization — `tensor_unit.cpp`

Add a template specialization of `FMA` for `<vt::tf32, vt::fp32>`. This handles the case where both input matrices hold TF32 values and the accumulator is fp32.

The two-step conversion process is:
1. Use `rv_xtof_s(raw_bits, exp_bits=8, mant_bits=10, rm, &fflags)` to convert a raw TF32 bit-pattern to an IEEE fp32 bit-pattern. This correctly handles the exponent bias and mantissa alignment.
2. Use `bit_cast<float>()` to reinterpret those bits as a C++ `float` without any numeric conversion.

```cpp
template <>
struct FMA<vt::tf32, vt::fp32> {
  static float eval(uint32_t a, uint32_t b, float c) {
    uint32_t fflags = 0;
    uint32_t rm = 0; // RNE: Round to Nearest, ties to Even

    // Convert TF32 bit-patterns to IEEE fp32 bit-patterns
    uint32_t a_bits = rv_xtof_s(a, 8, 10, rm, &fflags);
    uint32_t b_bits = rv_xtof_s(b, 8, 10, rm, &fflags);

    // Reinterpret bits as floats (no numeric conversion)
    float a_f = bit_cast<float>(a_bits);
    float b_f = bit_cast<float>(b_bits);

    // Multiply-accumulate into the fp32 accumulator
    return (a_f * b_f) + c;
  }
};
```

> **Note:** The Vortex Tensor Unit uses an unfused multiply-add here (`(a * b) + c`) rather than `std::fma`, consistent with how the hardware MMA pipeline accumulates partial products in separate stages.

---

## Step 3: Register TF32 in `select_FEDP` — `tensor_unit.cpp`

`select_FEDP` maps `(input_type_id, output_type_id)` pairs to their FEDP evaluation function pointer. Add the TF32→FP32 case inside the `fp32` output branch:

```cpp
static PFN_FEDP select_FEDP(uint32_t IT, uint32_t OT) {
  switch (OT) {
  case vt::fp32::id:
    switch (IT) {
    case vt::fp16::id:
      return FEDP<vt::fp16, vt::fp32>::eval;
    case vt::bf16::id:
      return FEDP<vt::bf16, vt::fp32>::eval;
    case vt::tf32::id:                          // <-- add this case
      return FEDP<vt::tf32, vt::fp32>::eval;
    default:
      std::cout << "Error: unsupported mma format: "
                << IT << " -> " << OT << "!" << std::endl;
      std::abort();
    }
  // ... other output type cases unchanged
  }
}
```

`FEDP` (Fused Element-wise Dot Product) wraps the `FMA` specialization in a loop over the vector elements, so no changes to `FEDP` itself are needed — the template instantiation is generated automatically from the specialization added in Step 2.

---

## Step 4: Testing

Clean any previous build and rebuild with the TF32 configuration before running, since input/output types are compiled into the kernel binary:

```bash
# Clean prior build
make -C tests/regression/sgemm_tcu clean

# Rebuild for 8 threads, TF32 input, FP32 output
CONFIGS="-DNUM_THREADS=8 -DITYPE=tf32 -DOTYPE=fp32" \
  make -C tests/regression/sgemm_tcu

# Run on SimX with Tensor Core extension enabled
CONFIGS="-DNUM_THREADS=8 -DEXT_TCU_ENABLE" \
  ./ci/blackbox.sh --driver=simx --app=sgemm_tcu
```

---

## Step 5: Benchmark TF32 vs. FP16/BF16

Using `N=256` on a 4-core GPU, sweep the following thread configurations for `fp16`, `bf16`, and `tf32` (all accumulating to FP32):

| Warps | Threads |
|-------|---------|
| 4     | 4       |
| 4     | 8       |
| 8     | 4       |
| 8     | 8       |

Record **total instruction count** and **execution cycles** for each format and configuration. Because all three formats execute the same MMA instruction count (the loop trip count is unchanged), differences in cycles will reflect the per-operation latency of the FMA specialization and any pipeline effects from the wider 32-bit TF32 operands versus the 16-bit fp16/bf16 operands.
