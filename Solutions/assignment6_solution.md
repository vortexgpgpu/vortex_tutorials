# Assignment 6: Dot Product Acceleration (RTL) — Solution

This document walks through the complete solution for implementing `VX_DOT8` in the Vortex RTL hardware. Steps 1 and 2 (ISA extension and kernel) are identical to Assignment 5 — refer to that solution for details. This document focuses on the RTL-specific changes in Step 3.

---

## Overview

Rather than emulating `VX_DOT8` in the SimX software simulator, this assignment implements it as a real hardware module (`VX_alu_dot8`) wired into the ALU pipeline as a third sub-unit alongside the integer ALU and MulDiv unit.

---

## Step 1 & 2: ISA Extension and Kernel

Unchanged from Assignment 5. See that solution for:
- `vx_dot8` intrinsic in `vx_intrinsics.h`
- `kernel.cpp` packing and accumulation logic
- `main.cpp` buffer sizing and CPU reference implementation

---

## Step 3: Hardware RTL Implementation

### `VX_config.vh` — Define `LATENCY_DOT8`

Add the DOT8 latency macro alongside the other functional unit latencies:

```verilog
// DOT8 Latency
`ifndef LATENCY_DOT8
`define LATENCY_DOT8 2
`endif
```

### `VX_gpu_pkg.sv` — Add `INST_ALU_DOT8` Opcode

Replace the unused ALU opcode slot `4'b0001` with the DOT8 type:

```verilog
localparam INST_ALU_ADD  = 4'b0000;
localparam INST_ALU_DOT8 = 4'b0001;  // was INST_ALU_UNUSED
localparam INST_ALU_LUI  = 4'b0010;
// ... rest unchanged
```

### `VX_trace_pkg.sv` — Add Trace String

Add a `DOT8` case to the ALU trace decoder so pipeline traces print the instruction name correctly:

```verilog
INST_ALU_AND:   `TRACE(level, ("AND"))
INST_ALU_CZEQ:  `TRACE(level, ("CZERO.EQZ"))
INST_ALU_CZNE:  `TRACE(level, ("CZERO.NEZ"))
INST_ALU_DOT8:  `TRACE(level, ("DOT8"))   // <-- add this
default:        `TRACE(level, ("?"))
```

### `VX_decode.sv` — Decode the Instruction

Add a `7'd3` case inside the custom-opcode block to decode `VX_DOT8`. The instruction targets the ALU functional unit and uses `ALU_TYPE_OTHER` to route it to the new dot8 sub-unit (rather than the integer ALU or MulDiv):

```verilog
7'd3: begin
    case (funct3)
        3'h0: begin // DOT8
            ex_type          = EX_ALU;
            op_type          = INST_ALU_DOT8;
            op_args.alu      = '0;
            op_args.alu.xtype = ALU_TYPE_OTHER;
            `USED_IREG (rd);
            `USED_IREG (rs1);
            `USED_IREG (rs2);
        end
        default:;
    endcase
end
```

**Key decisions:**
- `EX_ALU` routes this instruction through the ALU unit's dispatch logic
- `INST_ALU_DOT8` is the op_type tag used for tracing
- `ALU_TYPE_OTHER` is the xtype field checked in `VX_alu_unit.sv` to select the dot8 PE
- `USED_IREG` macros register rd, rs1, and rs2 as active, enabling writeback and scoreboard tracking

### `VX_alu_dot8.sv` — New Hardware Module

Create `hw/rtl/core/VX_alu_dot8.sv`. The module uses `VX_pe_serializer` to time-multiplex lanes across PEs, then instantiates one PE per `NUM_PES` that computes the dot product combinatorially before latching through `BUFFER_EX`.

The key computation — sign-extending each byte and computing the four partial products — is:

```verilog
assign c = (signed'(a[31:24]) * signed'(b[31:24])) +
           (signed'(a[23:16]) * signed'(b[23:16])) +
           (signed'(a[15:8])  * signed'(b[15:8]))  +
           (signed'(a[7:0])   * signed'(b[7:0]));
```

`signed'(...)` performs an in-place cast to signed before multiplication, so each 8-bit slice is treated as a two's-complement `int8`. The four products are summed into a 32-bit result.

The result is pipelined through the `BUFFER_EX` macro at the configured `LATENCY_DOT8` (2 cycles):

```verilog
`BUFFER_EX(result, c, pe_enable, 1, LATENCY_DOT8);
assign pe_data_out[i] = `XLEN'(result);
```

Full module:

```verilog
`include "VX_define.vh"

module VX_alu_dot8 import VX_gpu_pkg::*; #(
    parameter `STRING INSTANCE_ID = "",
    parameter NUM_LANES = 1
) (
    input wire clk,
    input wire reset,
    VX_execute_if.slave  execute_if,
    VX_result_if.master  result_if
);
    `UNUSED_SPARAM (INSTANCE_ID)
    localparam PID_BITS  = `CLOG2(`NUM_THREADS / NUM_LANES);
    localparam PID_WIDTH = `UP(PID_BITS);
    localparam TAG_WIDTH = UUID_WIDTH + NW_WIDTH + NUM_LANES + PC_BITS + 1
                         + NUM_REGS_BITS + PID_WIDTH + 1 + 1;
    localparam LATENCY_DOT8 = `LATENCY_DOT8;
    localparam PE_RATIO = 1;
    localparam NUM_PES  = `UP(NUM_LANES / PE_RATIO);

    `UNUSED_VAR (execute_if.data.op_type)
    `UNUSED_VAR (execute_if.data.op_args)
    `UNUSED_VAR (execute_if.data.rs3_data)

    wire pe_enable;
    wire [NUM_LANES-1:0][2*`XLEN-1:0] data_in;
    wire [NUM_PES-1:0][2*`XLEN-1:0]  pe_data_in;
    wire [NUM_PES-1:0][`XLEN-1:0]    pe_data_out;

    for (genvar i = 0; i < NUM_LANES; ++i) begin : g_data_in
        assign data_in[i][0      +: `XLEN] = execute_if.data.rs1_data[i];
        assign data_in[i][`XLEN  +: `XLEN] = execute_if.data.rs2_data[i];
    end

    VX_pe_serializer #(
        .NUM_LANES      (NUM_LANES),
        .NUM_PES        (NUM_PES),
        .LATENCY        (LATENCY_DOT8),
        .DATA_IN_WIDTH  (2 * `XLEN),
        .DATA_OUT_WIDTH (`XLEN),
        .TAG_WIDTH      (TAG_WIDTH),
        .PE_REG         (1)
    ) pe_serializer (
        .clk        (clk),
        .reset      (reset),
        .valid_in   (execute_if.valid),
        .data_in    (data_in),
        .tag_in     ({
            execute_if.data.uuid,
            execute_if.data.wid,
            execute_if.data.tmask,
            execute_if.data.PC,
            execute_if.data.wb,
            execute_if.data.rd,
            execute_if.data.pid,
            execute_if.data.sop,
            execute_if.data.eop
        }),
        .ready_in   (execute_if.ready),
        .pe_enable  (pe_enable),
        .pe_data_in (pe_data_out),
        .pe_data_out(pe_data_in),
        .valid_out  (result_if.valid),
        .data_out   (result_if.data.data),
        .tag_out    ({
            result_if.data.uuid,
            result_if.data.wid,
            result_if.data.tmask,
            result_if.data.PC,
            result_if.data.wb,
            result_if.data.rd,
            result_if.data.pid,
            result_if.data.sop,
            result_if.data.eop
        }),
        .ready_out  (result_if.ready)
    );

    for (genvar i = 0; i < NUM_PES; ++i) begin : g_PEs
        /* verilator lint_off UNUSEDSIGNAL */
        wire [`XLEN-1:0] a = pe_data_in[i][0     +: `XLEN];
        wire [`XLEN-1:0] b = pe_data_in[i][`XLEN +: `XLEN];
        /* verilator lint_on UNUSEDSIGNAL */
        wire [31:0] c, result;

        assign c = (signed'(a[31:24]) * signed'(b[31:24])) +
                   (signed'(a[23:16]) * signed'(b[23:16])) +
                   (signed'(a[15:8])  * signed'(b[15:8]))  +
                   (signed'(a[7:0])   * signed'(b[7:0]));

        `BUFFER_EX(result, c, pe_enable, 1, LATENCY_DOT8);
        assign pe_data_out[i] = `XLEN'(result);

    `ifdef DBG_TRACE_PIPELINE
        always @(posedge clk) begin
            if (pe_enable) begin
                `TRACE(2, ("%t: %s dot8[%0d]: a=0x%0h, b=0x%0h, c=0x%0h\n",
                           $time, INSTANCE_ID, i, a, b, c))
            end
        end
    `endif
    end

endmodule
```

### `VX_alu_unit.sv` — Wire in the New Sub-Unit

Three changes are needed: updating the PE count, adding the routing condition, and instantiating the module.

**1. Update PE count and index constants:**

```verilog
localparam PE_COUNT    = 1 + `EXT_M_ENABLED + 1;  // +1 for DOT8
localparam PE_SEL_BITS = `CLOG2(PE_COUNT);
localparam PE_IDX_INT  = 0;
localparam PE_IDX_MDV  = PE_IDX_INT + `EXT_M_ENABLED;
localparam PE_IDX_DOT8 = PE_IDX_MDV + 1;
```

**2. Add routing condition in the PE select logic:**

```verilog
pe_select = PE_IDX_INT;  // default: integer ALU
if (`EXT_M_ENABLED && (... xtype == ALU_TYPE_MULDIV))
    pe_select = PE_IDX_MDV;
else if (... xtype == ALU_TYPE_OTHER)
    pe_select = PE_IDX_DOT8;
```

`ALU_TYPE_OTHER` is the xtype value set during decode, distinguishing DOT8 from both the integer ALU and MulDiv.

**3. Instantiate `VX_alu_dot8` after `VX_alu_muldiv`:**

```verilog
VX_alu_dot8 #(
    .INSTANCE_ID (`SFORMATF(("%s-dot8%0d", INSTANCE_ID, block_idx))),
    .NUM_LANES   (NUM_LANES)
) dot8_unit (
    .clk        (clk),
    .reset      (reset),
    .execute_if (pe_execute_if[PE_IDX_DOT8]),
    .result_if  (pe_result_if[PE_IDX_DOT8])
);
```

---

## Step 4: Testing

### Build and Run

```bash
# Build the dot8 regression test
make -C tests/regression/dot8

# Build the RTL simulator
make -s

# Run with RTL simulation (4 cores, 4 warps, 4 threads)
./ci/blackbox.sh --driver=rtlsim --cores=4 --warps=4 --threads=4 --app=dot8
```

### Performance Sweep

Run the following configurations with `N=256` on a 4-core GPU and record **total instruction count** and **execution cycles**:

| Warps | Threads |
|-------|---------|
| 4     | 4       |
| 4     | 8       |
| 8     | 4       |
| 8     | 8       |

Compare against the scalar `int8_t` baseline. The RTL implementation should show the same instruction count reduction as the SimX version (fusing 4 multiplies + 3 adds into one instruction), with the added benefit of real pipeline timing at the configured 2-cycle latency.
