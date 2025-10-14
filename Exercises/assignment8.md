# Assignment #8: Tensor Core Extension (SimX)

This assignment will introduce you to the Vortex Tensor Core architecture. The Tensor Core in Vortex accelerates matrix multiply-accumulate (MMA) operations for machine learning workloads, supporting various input formats like fp16, bf16, int8, uint8, int4, and uint4. Outputs are typically accumulated in fp32 or int32.

You will extend the framework to add support for a new input matrix format: TF32 (Tensor Float 32). TF32 is a 19-bit floating-point format (1 sign bit, 8 exponent bits, 10 mantissa bits) padded to 32 bits, offering higher precision than bf16 while maintaining similar performance characteristics. You will implement this extension in the SimX cycle-level simulator, focusing on the functional emulation of fused multiply-add (FMA) operations used in MMA.

Note: This assignment ignores any hardware (RTL) changes; focus solely on the simulator side.

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
  // ... (existing cases)
  case tf32::id:  return tf32::name;
  // ... (existing cases)
  default: return "unknown";
  }
}
```

This ensures the simulator can recognize and print the TF32 format correctly.

### Step 2: Extend FMA Specialization for TF32

In `sim/simx/tensor_unit.cpp`, add a template specialization for the FMA (Fused Multiply-Add) struct to handle TF32 inputs accumulating into fp32. This will convert TF32 values to standard IEEE fp32 for computation.

Use the `rv_xtof_s` function (a RISC-V vector extension helper) to convert the custom TF32 format (8 exponent bits, 10 mantissa bits) to fp32. Use `bit_cast` to reinterpret the bits as float.

```c++
template <>
struct FMA<vt::tf32, vt::fp32> {
  static float eval(uint32_t a, uint32_t b, float c) {
    auto fa = bit_cast<float>(rv_xtof_s(a, 8, 10, 0, nullptr));
    auto fb = bit_cast<float>(rv_xtof_s(b, 8, 10, 0, nullptr));
    return fa * fb + c;
  }
};
```

This specialization computes `a * b + c` where `a` and `b` are TF32 values.

### Step 3: Update FEDP Selection

FEDP (Fused Element-wise Dot Product) is the core operation in the Tensor Unit for MMA. Update the `select_FEDP` function in `sim/simx/tensor_unit.cpp` to select the appropriate FEDP evaluation function for TF32 inputs (with fp32 output accumulation).

```c++
static PFN_FEDP select_FEDP(uint32_t IT, uint32_t OT) {
  // ... (existing code)
  switch (IT) {
  // ... (existing cases)
  case vt::tf32::id:
    return FEDP<vt::tf32, vt::fp32>::eval;
  // ... (existing cases)
  default:
    std::cout << "Error: unsupported mma format: " << IT << " -> " << OT << "!" << std::endl;
    std::abort();
  }
}
```

This integrates TF32 into the Tensor Unit's execution path.

### Step 4: Testing

To verify your implementation, use an existing MMA test case and modify it to use the TF32 format.

- Clone the `tests/regression/mma` folder into a new folder `tests/regression/mma_tf32`.
- Update the `Makefile` in `tests/regression/mma_tf32` to set the PROJECT name to `mma_tf32`.
- In `main.cpp`, modify the input matrices to use `uint32_t` (since TF32 is stored in 32-bit words) and set the format to `3` (TF32's ID) when configuring the kernel arguments.
- Update `kernel.cpp` to pack inputs as TF32 if needed (use existing packing utilities, assuming TF32 follows similar padding as bf16).
- Ensure memory allocations and copies (`vx_mem_alloc`, `vx_copy_to_dev`, `vx_copy_from_dev`) use the correct byte sizes for TF32 (4 bytes per element).

Run the test on SimX with a small matrix size (e.g., 8x8) and compare the output against a software reference implementation of MMA with TF32 (you can implement a simple CPU version using the same `rv_xtof_s` conversions for verification).

Test with configurations: 1 core, 4 warps, 4 threads; and 4 cores, 4 warps, 8 threads. Use the simulator's tracing (DP macro level 3) to inspect FEDP operations and ensure TF32 values are correctly converted and accumulated. Measure execution cycles and compare against bf16 to observe similar latency (TF32 should have comparable performance). If results mismatch, debug the FMA conversion logic.
