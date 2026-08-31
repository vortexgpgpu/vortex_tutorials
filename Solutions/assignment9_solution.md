# Assignment 9: Tensor Core (TF32) Support in RTL — Solution

This document walks through the complete solution for extending the Vortex Tensor Core RTL to support **TF32** inputs via the **BHF (Berkeley HardFloat) backend**.

---

## Overview

Assignment 8 added TF32 to the SimX software emulator. This assignment wires TF32 into the actual RTL pipeline, specifically the BHF FEDP (Fused Element-wise Dot Product) module that drives the hardware Tensor Core.

The BHF backend uses `VX_tcu_bhf_fmul` — a parameterized floating-point multiplier — to compute products before accumulation. Adding TF32 means instantiating a new multiplier configured for TF32's 8-exponent / 10-mantissa bit format, unpacking TF32 operands correctly, and routing the result through the existing mux.

Changes touch three files: `VX_tcu_pkg.sv`, and `VX_tcu_fedp_bhf.sv`. The `tensor_cfg.h` changes are identical to Assignment 8 and are not repeated here.

---

## Step 1: Format Definition — `tensor_cfg.h`

Identical to Assignment 8. Add the `tf32` struct and register it in `fmt_string()`. See that solution for details.

---

## Step 2: Update Tensor Core Package — `VX_tcu_pkg.sv`

Add the TF32 format ID constant alongside the other format IDs:

```sv
localparam TCU_FP16_ID = 1;
localparam TCU_BF16_ID = 2;
localparam TCU_TF32_ID = 3;  // <-- add this
localparam TCU_FP32_ID = 4;
// ... integer format IDs unchanged
```

Add TF32 to the `trace_fmt` task so pipeline traces print `"tf32"` instead of `"?"`:

```sv
task trace_fmt(input int level, input logic [3:0] fmt);
    case (fmt)
        TCU_FP16_ID: `TRACE(level, ("fp16"))
        TCU_BF16_ID: `TRACE(level, ("bf16"))
        TCU_TF32_ID: `TRACE(level, ("tf32"))  // <-- add this
        TCU_FP32_ID: `TRACE(level, ("fp32"))
        TCU_U8_ID:   `TRACE(level, ("u8"))
        TCU_I4_ID:   `TRACE(level, ("i4"))
        TCU_U4_ID:   `TRACE(level, ("u4"))
        default:     `TRACE(level, ("?"))
    endcase
endtask
```

---

## Step 3: Extend BHF FEDP — `VX_tcu_fedp_bhf.sv`

This is the main change. Three sub-steps are needed: unpacking TF32 operands, instantiating the TF32 multiplier, and routing its output through the result mux.

### 3a. Unpack TF32 Operands

The existing unpack block splits each 32-bit element into two 16-bit halves for fp16/bf16, giving `TCK = 2N` packed 16-bit lanes. TF32 elements are 19 bits wide and one element fills an entire 32-bit register, so there is no second element to unpack. The second slot is filled with zero to preserve the same `TCK`-wide pipeline width used by the accumulator:

```sv
wire [TCK-1:0][15:0] a_row16;
wire [TCK-1:0][15:0] b_col16;
wire [TCK-1:0][18:0] a_row19;  // <-- add
wire [TCK-1:0][18:0] b_col19;  // <-- add

for (genvar i = 0; i < N; i++) begin : g_unpack
    // Existing fp16/bf16 unpacking (unchanged)
    assign a_row16[2*i]   = a_row[i][15:0];
    assign a_row16[2*i+1] = a_row[i][31:16];
    assign b_col16[2*i]   = b_col[i][15:0];
    assign b_col16[2*i+1] = b_col[i][31:16];

    // TF32: one 19-bit element per register; interleave zeros to match TCK width
    assign a_row19[2*i]   = a_row[i][18:0];
    assign a_row19[2*i+1] = 19'd0;
    assign b_col19[2*i]   = b_col[i][18:0];
    assign b_col19[2*i+1] = 19'd0;
end
```

The zero-interleaving means the accumulator still sees `TCK` inputs, but every other product is zero — effectively halving throughput for TF32, which is correct since TF32 elements are twice as wide as fp16/bf16.

### 3b. Instantiate the TF32 Multiplier

Inside the per-lane generate loop `g_prod`, add a `VX_tcu_bhf_fmul` instance configured for TF32's format: 8 exponent bits and 11 significand bits (10 explicit mantissa bits + 1 implicit leading bit). Input is in IEEE format (`IN_REC=0`); output is in recoded format (`OUT_REC=1`) to feed directly into the BHF accumulator:

```sv
for (genvar i = 0; i < TCK; i++) begin : g_prod
    wire [32:0] mult_result_fp16;
    wire [32:0] mult_result_bf16;
    wire [32:0] mult_result_tf32;  // <-- add

    // FP16 multiplier (unchanged)
    VX_tcu_bhf_fmul #(
        .IN_EXPW (5), .IN_SIGW (11),
        .OUT_EXPW(8), .OUT_SIGW(24),
        .IN_REC(0), .OUT_REC(1),
        .MUL_LATENCY(FMUL_LATENCY), .RND_LATENCY(FRND_LATENCY)
    ) fp16_mul ( .clk(clk), .reset(reset), .enable(enable), .frm(frm),
                 .a(a_row16[i]), .b(b_col16[i]), .y(mult_result_fp16),
                 `UNUSED_PIN(fflags) );

    // BF16 multiplier (unchanged)
    VX_tcu_bhf_fmul #(
        .IN_EXPW (8), .IN_SIGW (8),
        .OUT_EXPW(8), .OUT_SIGW(24),
        .IN_REC(0), .OUT_REC(1),
        .MUL_LATENCY(FMUL_LATENCY), .RND_LATENCY(FRND_LATENCY)
    ) bf16_mul ( .clk(clk), .reset(reset), .enable(enable), .frm(frm),
                 .a(a_row16[i]), .b(b_col16[i]), .y(mult_result_bf16),
                 `UNUSED_PIN(fflags) );

    // TF32 multiplier: 8 exponent bits, 11 significand bits (10 mantissa + implicit 1)
    VX_tcu_bhf_fmul #(
        .IN_EXPW (8), .IN_SIGW (11),
        .OUT_EXPW(8), .OUT_SIGW(24),
        .IN_REC (0),
        .OUT_REC(1),
        .MUL_LATENCY(FMUL_LATENCY),
        .RND_LATENCY(FRND_LATENCY)
    ) tf32_mul (
        .clk    (clk),
        .reset  (reset),
        .enable (enable),
        .frm    (frm),
        .a      (a_row19[i]),
        .b      (b_col19[i]),
        .y      (mult_result_tf32),
        `UNUSED_PIN(fflags)
    );
```

**Why `IN_SIGW=11`?** TF32 has 10 explicit mantissa bits; the significand width passed to BHF includes the implicit leading 1, so the correct value is 11 — matching fp16 despite TF32's wider exponent field.

### 3c. Route Through the Result Mux

Add `3'd3` (matching `TCU_TF32_ID`) to the format select mux:

```sv
logic [32:0] mult_result_mux;
always_comb begin
    case (fmt_s_delayed)
        3'd1: mult_result_mux = mult_result_fp16;
        3'd2: mult_result_mux = mult_result_bf16;
        3'd3: mult_result_mux = mult_result_tf32;  // <-- add
        default: mult_result_mux = 'x;
    endcase
end
```

The selected result flows into the existing fp32 accumulator chain unchanged — no accumulator modifications are needed since all three formats produce a recoded fp32 output from the multiplier.

---

## Step 4: Testing

Clean and rebuild with the TF32 configuration before running, since input/output types are compiled into the kernel binary:

```bash
# Clean prior build
make -C tests/regression/sgemm_tcu clean

# Rebuild for 8 threads, TF32 input, FP32 output
CONFIGS="-DNUM_THREADS=8 -DITYPE=tf32 -DOTYPE=fp32" \
  make -C tests/regression/sgemm_tcu

# Run on RTL simulator with Tensor Core (BHF backend) enabled
CONFIGS="-DNUM_THREADS=8 -DEXT_TCU_ENABLE -DTCU_BHF" \
  ./ci/blackbox.sh --driver=rtlsim --app=sgemm_tcu
```

---
