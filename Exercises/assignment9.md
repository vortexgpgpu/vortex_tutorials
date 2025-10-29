# Assignment #9: Tensor Core (TF32) Support in RTL

This assignment will introduce you to the Vortex Tensor Core architecture. 
The Tensor Core in Vortex accelerates matrix multiply-accumulate (MMA) operations for machine learning workloads, supporting various input formats like fp16, bf16, int8, uint8, int4, and uint4. 
Outputs are typically accumulated in fp32 or int32.

Vortex's Tensor Core hardware has multiple dot‑product backends: **DPI** (C++ for fast simulation), **DSP** (FPGA DSPs), and **BHF** (Berkeley HardFloat library). **This assignment focuses only on extending the BHF backend** to support TF32.

You will extend the framework to add support for a new input matrix format: TF32 (Tensor Float 32). 
TF32 is a 19-bit floating-point format (1 sign bit, 8 exponent bits, 10 mantissa bits) padded to 32 bits, offering higher precision than bf16 while maintaining similar performance characteristics. 
You will implement this extension in the RTL cycle-level simulator, focusing on the functional emulation of fused multiply-add (FMA) operations used in MMA.

### Step 1: Add TF32 Format Definition

Modify `hw/rtl/* (Tensor Core / TCU)` to define the TF32 format. Add a new struct for TF32, similar to the existing formats (e.g., bf16).

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

### Step 2: Update Tensor Core Package

Modify `hw/rtl/tcu/VX_tcu_pkg.sv` to add the TF32 format ID.
Add the constant for TF32:

```sv
localparam TCU_TF32_ID = 3;
```

Update `trace_fmt` to enable TF32 tracing:

```sv
TCU_TF32_ID: `TRACE(level, ("tf32"))
```

This defines the ID for TF32 and ensures it can be traced correctly in the hardware.

### Step 3: Extend BHF FEDP for TF32

In `hw/rtl/tcu/VX_tcu_fedp_bhf.sv`, extend the fused element-wise dot product (FEDP) module to support TF32 multiplication using the Berkeley HardFloat library.
Inside the generate loop for products, add a new TF32 multiplication instance.
Use the VX_tcu_bhf_fmul module with parameters for TF32 following fp16/bf16 instances.
Note that TF32 format is 19-bit, so it uses a full 32-bit register to store one element instead of 2 like for fp16.
Hint: To share the same accumulator with fp16/fp16, the TF32 multiplier should interleave its 4 outputs with zeros to generate 8 inputs for the next stage. 

```sv
wire [32:0] mult_result_tf32;

// TODO

always_comb begin
    case(fmt_s_delayed)
        3'd1: mult_result_mux = mult_result_fp16;
        3'd2: mult_result_mux = mult_result_bf16;
        3'd3: mult_result_mux = mult_result_tf32;
        default: mult_result_mux = 'x;
    endcase
end
```

This integrates TF32 into the BHF Tensor Unit backend.

### Step 4: Testing

Before running TF32 tests, compile the regression app for your target format and GPU thread configuration.
The example below cleans the previous build and rebuilds with an **8‑thread GPU**, using **TF32 inputs** and **FP32 outputs**.
Then it runs the test on **RTL** with the Tensor Core extension enabled.

```bash
# Clean and (re)build the sgemm_tcu regression as usual for your repo
make -C tests/regression/sgemm_tcu clean

# Rebuild for 8 threads, TF32 input type, FP32 output type
CONFIGS="-DNUM_THREADS=8 -DITYPE=tf32 -DOTYPE=fp32" make -C tests/regression/sgemm_tcu

# Run on RTL simulator with Tensor Core (BHF) enabled, 8 threads
CONFIGS="-DNUM_THREADS=8 -DEXT_TCU_ENABLE -DTCU_BHF" ./ci/blackbox.sh --driver=rtlsim --app=sgemm_tcu
```

### Step 5 — Benchmark TF32 vs. FP16/BF16
Using the same kernel and grid settings, measure **instruction counts** and **cycles** for `fp16`, `bf16`, and `tf32` (all accumulating to FP32). Use a 4‑core GPU and try configurations `(warps, threads) ∈ {(4,4), (4,8), (8,4), (8,8)}` with `N = 256`.
Plot the total instruction count and execution cycles to observe the performance difference.
