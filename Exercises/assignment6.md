# Assignment #6: Dot Product Acceleration (RTL)

This assignment will introduce you to the basics of extending GPU Microarchitecture to accelerate a kernel in hardware
You will add a new RISC-V custom instruction for computing the integer dot product: VX\_DOT8.
You will also implement this instruction in the hardware RTL.

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

You will need to modify `vx_instrinsics.h` to add your new VX_DOT8 instruction.

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

### Step 3: Hardware RTL implementation

Modify the RTL code to implement the custom ISA extension. We recommend checking out how MULT instructions are decoded and executed in RTL as reference.

- Update `hw/rtl/VX_define.vh` to define `INST_ALU_DOT8` as `4'b0001`
- Update `hw/rtl/VX_config.vh` to define `LATENCY_DOT8` as 2
- Update `dpi_trace()` in `hw/rtl/VX_gpu_pkg.sv` to print the new instruction
- Update `hw/rtl/core/VX_decode.sv` to decode the new instruction. Select the ALU functional unit for executing this new instruction.

``` verilog
7'h01: begin
    case (func3)
        3'h0: begin // DOT8
            ex_type = // TODO: destination functional unit
            op_type = // TODO: instruction type
            use_rd =  // TODO: writing back to rd
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

module VX_alu_dot8 #(
    parameter `STRING INSTANCE_ID = "",
    parameter NUM_LANES = 1
) (
    input wire          clk,
    input wire          reset,

    // Inputs
    VX_execute_if.slave execute_if,

    // Outputs
    VX_commit_if.master commit_if
);
    `UNUSED_SPARAM (INSTANCE_ID)
    localparam PID_BITS = `CLOG2(`NUM_THREADS / NUM_LANES);
    localparam PID_WIDTH = `UP(PID_BITS);
    localparam TAG_WIDTH = `UUID_WIDTH + `NW_WIDTH + NUM_LANES + `PC_BITS + `NR_BITS + 1 + PID_WIDTH + 1 + 1;
    localparam LATENCY_DOT8 = `LATENCY_DOT8;
    localparam PE_RATIO = 2;
    localparam NUM_PES = `UP(NUM_LANES / PE_RATIO);

    `UNUSED_VAR (execute_if.data.op_type)
    `UNUSED_VAR (execute_if.data.tid)
    `UNUSED_VAR (execute_if.data.rs3_data)

    wire [NUM_LANES-1:0][2*`XLEN-1:0] data_in;

    for (genvar i = 0; i < NUM_LANES; ++i) begin
        assign data_in[i][0 +: `XLEN] = execute_if.data.rs1_data[i];
        assign data_in[i][`XLEN +: `XLEN] = execute_if.data.rs2_data[i];
    end

    wire pe_enable;
    wire [NUM_PES-1:0][2*`XLEN-1:0] pe_data_in;
    wire [NUM_PES-1:0][`XLEN-1:0] pe_data_out;

    // PEs time-multiplexing
    VX_pe_serializer #(
        .NUM_LANES  (NUM_LANES),
        .NUM_PES    (NUM_PES),
        .LATENCY    (LATENCY_DOT8),
        .DATA_IN_WIDTH (2*`XLEN),
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
            execute_if.data.rd,
            execute_if.data.wb,
            execute_if.data.pid,
            execute_if.data.sop,
            execute_if.data.eop
        }),
        .ready_in   (execute_if.ready),
        .pe_enable  (pe_enable),
        .pe_data_in (pe_data_out),
        .pe_data_out(pe_data_in),
        .valid_out  (commit_if.valid),
        .data_out   (commit_if.data.data),
        .tag_out    ({
            commit_if.data.uuid,
            commit_if.data.wid,
            commit_if.data.tmask,
            commit_if.data.PC,
            commit_if.data.rd,
            commit_if.data.wb,
            commit_if.data.pid,
            commit_if.data.sop,
            commit_if.data.eop
        }),
        .ready_out  (commit_if.ready)
    );

    // PEs instancing
    for (genvar i = 0; i < NUM_PES; ++i) begin
        wire [31:0] a = pe_data_in[i][0 +: 32];
        wire [31:0] b = pe_data_in[i][32 +: 32];
        // TODO:
        wire [31:0] result;
        `BUFFER_EX(result, c, pe_enable, LATENCY_DOT8);
        assign pe_data_out[i] = result;
    end

endmodule
```

- Update `hw/rtl/core/VX_alu_unit.sv` to add your new VX_alu_dot8 instance as a 3rd sub-unit after `VX_alu_muldiv`.

### Step 4: Testing

You will compare your new accelerated dot8 program with the existing sgemmx kernel under the regression codebase.
You will use N=128 and (warps=4, threads=4) and (Warps=16, threads=16) for 1 and 4 cores.
Plot the IPC to observe the performance improvement.
