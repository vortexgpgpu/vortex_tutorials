# Assignment #6: Dot Product Acceleration (RTL)

This assignment will introduce you to the basics of extending GPU Microarchitecture to accelerate a kernel in hardware
You will add a new RISC-V custom instruction for computing the integer dot product: VX\_DOT8.
You will also implement this instruction in the hardware RTL.
Prerequisite: We recommend completing the prior assignment on the Dot8 simulation before this one.

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
Use custom extension opcode=0x0B with funct7=3 and funct3=0;

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
        uint32_t packedB = ((uint8_t)B[k+0][j] << 0)
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

- Clone sgemm test under `tests/regression/sgemm` into a new folder `tests/regressions/dot8`.
- Set PROJECT name to `dot8` in `tests/regressions/dot8/Makefile`
- Update `matmul_cpu` in `main.cpp` to operate on `int8_t` input matrices and `int32_t` output destination.
- Ensure `vx_mem_alloc`, `vx_copy_to_dev`, and `vx_copy_from_dev` in `main.cpp` are using the correct size of their buffer in bytes.
- Update `kernel_body` in `tests/regressions/dot8/kernel.cpp` to use `vx_dot8` intrinsic function.

### Step 3: Hardware RTL implementation

Modify the RTL code to implement the custom ISA extension. We recommend checking out how MULT instructions are decoded and executed in RTL as a reference.

- Update `hw/rtl/VX_gpu_pkg.vh` to replace `INST_ALU_UNUSED` with `INST_ALU_DOT8`
- Update `hw/rtl/VX_config.vh` to define `LATENCY_DOT8` as 2
- Update `hw/rtl/VX_trace_pkg.vh` to include "DOT8" trace
- Update `hw/rtl/core/VX_decode.sv` to decode the new instruction. Select the ALU functional unit for executing this new instruction.

``` verilog
7'h03: begin
    case (funct3)
        3'h0: begin // DOT8
            ex_type = // TODO: destination functional unit
            op_type = // TODO: DOT8 instruction type
            op_args.alu = '0;
            op_args.alu.xtype = // TODO: arithmetic ALU
            use_rd = // TODO: this instruction does writeback 
            // TODO: set using rd
            // TODO: set using rs1
            // TODO: set using rs2
        end
        default:;
    endcase
end
```
- Create a new VX\_alu\_dot8.sv module that implements DOT8

``` verilog
`include "VX_define.vh"

module VX_alu_dot8 import VX_gpu_pkg::*; #(
    parameter `STRING INSTANCE_ID = "",
    parameter NUM_LANES = 1
) (
    input wire          clk,
    input wire          reset,

    // Inputs
    VX_execute_if.slave execute_if,

    // Outputs
    VX_result_if.master result_if
);
    `UNUSED_SPARAM (INSTANCE_ID)
    localparam PID_BITS = `CLOG2(`NUM_THREADS / NUM_LANES);
    localparam PID_WIDTH = `UP(PID_BITS);
    localparam TAG_WIDTH = UUID_WIDTH + NW_WIDTH + NUM_LANES + PC_BITS + 1 + NUM_REGS_BITS + PID_WIDTH + 1 + 1;
    localparam LATENCY_DOT8 = `LATENCY_DOT8;
    localparam PE_RATIO = 1;
    localparam NUM_PES = `UP(NUM_LANES / PE_RATIO);

    `UNUSED_VAR (execute_if.data.op_type)
    `UNUSED_VAR (execute_if.data.op_args)
    `UNUSED_VAR (execute_if.data.rs3_data)

    wire pe_enable;
    wire [NUM_LANES-1:0][2*`XLEN-1:0] data_in;
    wire [NUM_PES-1:0][2*`XLEN-1:0] pe_data_in;
    wire [NUM_PES-1:0][`XLEN-1:0] pe_data_out;

    for (genvar i = 0; i < NUM_LANES; ++i) begin : g_data_in
        assign data_in[i][0 +: `XLEN] = execute_if.data.rs1_data[i];
        assign data_in[i][`XLEN +: `XLEN] = execute_if.data.rs2_data[i];
    end

    // PEs time-multiplexing
    VX_pe_serializer #(
        .NUM_LANES  (NUM_LANES),
        .NUM_PES    (NUM_PES),
        .LATENCY    (LATENCY_DOT8),
        .DATA_IN_WIDTH (2 * `XLEN),
        .DATA_OUT_WIDTH (`XLEN),
        .TAG_WIDTH  (TAG_WIDTH),
        .PE_REG     (1)
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

    // PEs instancing
    for (genvar i = 0; i < NUM_PES; ++i) begin : g_PEs
        wire [`XLEN-1:0] a = pe_data_in[i][0 +: `XLEN];
        wire [`XLEN-1:0] b = pe_data_in[i][`XLEN +: `XLEN];
        wire [31:0] c, result;

        // TODO: calculate c

        `BUFFER_EX(result, c, pe_enable, 1, LATENCY_DOT8);
        assign pe_data_out[i] = `XLEN'(result);

    `ifdef DBG_TRACE_PIPELINE
        always @(posedge clk) begin
            if (pe_enable) begin
                `TRACE(2, ("%t: %s dot8[%0d]: a=0%0h, b=0x%0h, c=0x%0h\n", $time, INSTANCE_ID, i, a, b, c))
            end
        end
    `endif
    end

endmodule
```

- Update `hw/rtl/core/VX_alu_unit.sv` to add your new VX_alu_dot8 instance as a 3rd sub-unit after `VX_alu_muldiv` along with the extra control logic in order to enable the new VX_alu_dot8 instance.

### Step 4: Testing

To test your changes, you can run the following to build and verify dot8 functionality

```bash
# Build the new dot8 regression test
make -C tests/regression/dot8

# Make the build
make -s

# Test with SimX
./ci/blackbox.sh --driver=rtlsim --cores=4 --warps=4 --threads=4 --app=dot8
```

You will compare your new accelerated dot8 program with a corresponding baseline int8_t kernel.
You will use N=256 and (warps=4, threads=4), (warps=4, threads=8), (warps=8, threads=4), and (warps=8, threads=8) on a 4-core GPU.
Plot the total instruction count and execution cycles to observe the performance improvement.
