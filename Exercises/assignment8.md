# Assignment #8: Tensor Core Extension (SimX)

This assignment will introduce you to the Vortex Tensor Core architecture. The Tensor Core in Vortex accelerates matrix multiply-accumulate (MMA) operations for machine learning workloads, supporting various input formats like fp16, bf16, int8, uint8, int4, and uint4. Outputs are typically accumulated in fp32 or int32.

You will extend the framework to add support for a new input matrix format: TF32 (Tensor Float 32). TF32 is a 19-bit floating-point format (1 sign bit, 8 exponent bits, 10 mantissa bits) padded to 32 bits, offering higher precision than bf16 while maintaining similar performance characteristics. You will implement this extension in the SimX cycle-level simulator, focusing on the functional emulation of fused multiply-add (FMA) operations used in MMA.

### Step 1: Add TF32 Format Definition

Modify `sim/common/tensor_cfg.h` to define the TF32 format. Add a new struct for TF32, similar to the existing formats (e.g., bf16).

```c++
struct tf32 {
  using dtype = uint32_t;
  static constexpr uint32_t id = 3;
  static constexpr uint32_t bits = 32;
  static constexpr const char* name = "tf32";
};
```

Update the `fmt_string` function in the same file to handle the new format:

```c++
inline const char* fmt_string(uint32_t fmt) {
  switch (fmt) {
  // TODO:
  default: return "unknown";
  }
}
```

This ensures the simulator can recognize and print the TF32 format correctly.

### Step 2: Extend FMA Specialization for TF32

In `sim/simx/tensor_unit.cpp`, add a template specialization for the FMA (Fused Multiply-Add) struct to handle TF32 inputs accumulating into fp32. This will convert TF32 values to standard IEEE fp32 for computation.

Use the `rv_xtof_s` function to convert the custom TF32 format (8 exponent bits, 10 mantissa bits) to fp32. Use `bit_cast` to reinterpret the bits as float.

```c++
template <>
struct FMA<vt::tf32, vt::fp32> {
  static float eval(uint32_t a, uint32_t b, float c) {
    // TODO:
  }
};
```

This specialization computes `a * b + c` where `a` and `b` are TF32 values.

### Step 3: Update FEDP Selection

FEDP (Fused Element-wise Dot Product) is the core operation in the Tensor Unit for MMA. 
Update the `select_FEDP` function in `sim/simx/tensor_unit.cpp` to select the appropriate FEDP evaluation function for TF32 inputs (with fp32 output accumulation).

```c++
static PFN_FEDP select_FEDP(uint32_t IT, uint32_t OT) {
  switch (IT) {
  // TODO:
  default:
    std::cout << "Error: unsupported mma format: " << IT << " -> " << OT << "!" << std::endl;
    std::abort();
  }
}
```

This integrates TF32 into the Tensor Unit's execution path.

### Step 4: Testing

Before running TF32 tests, compile the regression app for your target format and GPU thread configuration. 
The example below cleans the previous build and rebuilds with an **8‑thread GPU**, using **TF32 inputs** and **FP32 outputs**. 
Then it runs the test on **SimX** with the Tensor Core extension enabled.

```bash
# Clean the previous build of the sgemm_tcu regression
make -C tests/regression/sgemm_tcu clean

# Rebuild for 8 threads, TF32 input type, FP32 output type
CONFIGS="-DNUM_THREADS=8 -DITYPE=tf32 -DOTYPE=fp32" make -C tests/regression/sgemm_tcu

# Run on SimX with Tensor Core extension enabled
CONFIGS="-DNUM_THREADS=8 -DEXT_TCU_ENABLE" ./ci/blackbox.sh --driver=simx --app=sgemm_tcu
```

### Step 5 — Benchmark TF32 vs. FP16/BF16
Using the same kernel and grid settings, measure **instruction counts** and **cycles** for `fp16`, `bf16`, and `tf32` (all accumulating to FP32). Use a 4‑core GPU and try configurations `(warps, threads) ∈ {(4,4), (4,8), (8,4), (8,8)}` with `N = 256`.
Plot the total instruction count and execution cycles to observe the performance difference.
