# Assignment #4: GPU Software Prefetching (RTL)

This assignment will be divided into two parts. The first part involves adding a new prefetch instruction as well as a corresponding flag bit to identify if it has been prefetched. The second involves adding three performance counters to measure the following:

1. Number of unique prefetch requests to main memory
2. Number of unused prefetched blocks  
3. Number of late prefetches

All of these counters should be implemented in `VX_cache_bank.sv`

**⚠️ IMPORTANT**: This is the RTL (hardware) implementation. You must complete Assignment #3 (SimX simulation) first.

## Prerequisites from Assignment 3

**⚠️ IMPORTANT**: This assignment assumes you have already completed Assignment 3. If you haven't done Assignment 3 yet, please complete it first.

### Prerequisites from Assignment 3
Before starting this RTL assignment, you should have already implemented:

1. **SimX Prefetch Instruction** (from Assignment 3, Part 1):
   - Added prefetch intrinsic to `runtime/include/vx_intrinsics.h`
   - Implemented prefetch decoding in `sim/simx/decode.cpp`
   - Implemented prefetch execution in `sim/simx/execute.cpp`
   - Added prefetch tag in `sim/simx/VX_lsu_unit.sv`
   - Added prefetch debug output in `sim/simx/VX_cache_bank.sv`
   - Created prefetch test application

2. **SimX Performance Counters** (from Assignment 3, Part 2):
   - Unique prefetch requests counter
   - Unused prefetched blocks counter  
   - Late prefetches counter

### Reference Assignment 3
For detailed implementation of the SimX components, refer to:
- **Assignment 3, Part 1**: SimX prefetch instruction implementation
- **Assignment 3, Part 2**: SimX performance counter implementation

This RTL assignment (Assignment 4) focuses on implementing the same functionality at the RTL level using SystemVerilog hardware description.

## Part 1: RTL Implementation of Prefetch Instruction

To begin, we will add the prefetch instruction in a new group of instructions. Then we want to develop a testing directory and script to ensure correctness and functionality

### Step 1: RTL Pipeline Implementation

#### 1a: Adding Opcode in `hw/rtl/VX_gpu_pkg.sv`
The custom instruction opcode `0x6b` (INST_EXT4) should already be defined:

```systemverilog
// These should already exist in VX_gpu_pkg.sv
localparam INST_EXT4 = 7'b1111011; // 0x7B (this is 0x6b)

// You may need to add this constant for prefetch instruction
localparam INST_LSU_PREFETCH = 3'd5;
```

This will create a new group for the prefetch instruction, where this instruction is an R-type instruction format

#### 1b: Decoding in `hw/rtl/core/VX_decode.sv`
Add prefetch case in the main opcode switch statement:

```systemverilog
// In VX_decode.sv, add this case in the main opcode switch (around line 158)
INST_EXT4: begin // Custom instruction 0x6b
    case (funct3) // Use funct3 field as instruction identifier
        3'd5: begin // Software prefetch (identifier 5)
            ex_type = EX_LSU;
            op_type = INST_OP_BITS'(INST_LSU_PREFETCH);
            op_args.lsu.is_store = 0;
            op_args.lsu.is_float = 0;
            op_args.lsu.offset = u_12;
            op_args.lsu.is_prefetch = 1; // Mark as prefetch
            `USED_IREG (rs1); // Use rs1 for address
            // No destination register for prefetch
        end
        default: begin
            // Handle other custom instructions (tmc, wspawn, etc.)
            ex_type = 'x;
            op_type = 'x;
        end
    endcase
end
```

In this implementation, we issue a dummy read in order to populate a cache. This will trigger RTL to place data (from an address) into cache, essentially prefetching the data. The instruction will not modify or perform anything outside of that.

#### 1c: Adding Prefetch Tag in `hw/rtl/interfaces/VX_lsu_req_if.sv`
Add prefetch bit to the LSU request interface:

```systemverilog
// Add prefetch field to the lsu_req_t structure
typedef struct packed {
    logic                    valid;
    logic [`UUID_WIDTH-1:0]  uuid;
    logic [NUM_THREADS-1:0]  tmask;
    logic [`XLEN-1:0]        PC;
    logic [`NW_WIDTH-1:0]    wid;
    logic [`NUM_REGS_BITS-1:0] rd;
    logic [`INST_LSU_BITS-1:0] op_type;
    logic                    is_store;
    logic                    is_float;
    logic                    is_prefetch; // Add this field
    logic [`XLEN-1:0]        base_addr [`NUM_THREADS];
    logic [`XLEN-1:0]        offset;
    logic [`XLEN-1:0]        store_data [`NUM_THREADS];
} lsu_req_t;
```

#### 1d: Setting Prefetch Tag in `hw/rtl/core/VX_instr_demux.sv`
Set the prefetch tag based on instruction type:

```systemverilog
// In VX_instr_demux.sv, set prefetch flag
assign lsu_req_if.data.is_prefetch = (decode_if.data.ex_type == EX_LSU) && 
                                    (decode_if.data.op_args.lsu.is_prefetch);
```

#### 1e: Handling Prefetch in `hw/rtl/core/VX_lsu_unit.sv`
Handle prefetch requests in the LSU unit:

```systemverilog
// In VX_lsu_unit.sv, add prefetch handling logic
wire is_prefetch_req = lsu_req_if.valid && lsu_req_if.data.is_prefetch;

// Modify cache response handling - prefetch doesn't need response
assign cache_rsp_ready = lsu_rsp_if.ready && !is_prefetch_req;

// Add prefetch bit to cache request tag
wire [`CACHE_TAG_WIDTH-1:0] cache_req_tag_extended;
assign cache_req_tag_extended = {lsu_req_if.data.uuid, 
                                lsu_req_if.data.wid, 
                                lsu_req_if.data.rd,
                                lsu_req_if.data.is_prefetch}; // Add prefetch bit
```

### Step 2: RTL Testing

#### 2a: Test with Existing Prefetch Application
Since you already created the prefetch test application in Assignment 3, you can use it directly:

```bash
# Test with RTL simulation
./ci/blackbox.sh --driver=rtlsim --cores=1 --app=prefetch --debug

# Compare with SimX results
./ci/blackbox.sh --driver=simx --cores=1 --app=prefetch
```

#### 2b: RTL Verification
You should see the same prefetch behavior in RTL as you did in SimX:
- Prefetch instructions being decoded and executed
- Cache requests with prefetch tags
- Debug output showing prefetch operations

## Part 2: RTL Performance Counter Implementation

Now that you have prefetch instructions working in RTL, we want to implement the three performance counters to measure prefetch effectiveness

### Step 1: Adding Prefetch Flags

#### 1a: Adding Prefetch Tag in `hw/rtl/core/VX_lsu_unit.sv`
Add prefetch bit to the tag before it reaches the cache bank:

```systemverilog
// In VX_lsu_unit.sv, add prefetch bit to tag
wire [TAG_WIDTH+1:0] extended_tag;
assign extended_tag = {core_req_tag, 1'b0, req_is_prefetch};

// Use extended tag for cache requests
assign cache_req_tag = extended_tag[TAG_WIDTH-1:0];
```

#### 1b: Adding Prefetch Tag in `hw/rtl/cache/VX_cache_bank.sv`
Add prefetch bit to the debug header:

```systemverilog
// In VX_cache_bank.sv, add prefetch bit to debug header
wire req_is_prefetch = core_req_tag[0]; // Adjust bit position as needed

// Add to debug header
$write(" [PREFETCH:%d]", req_is_prefetch);
```

### Step 2: Adding Counters

We want to add all three prefetch counters into the `VX_cache_bank.sv` file

```systemverilog
// Counter declarations
reg [31:0] unique_prefetch_counter;
reg [31:0] unused_prefetch_counter;
reg [31:0] late_prefetch_counter;

// Initialize counters
always_ff @(posedge clk) begin
    if (reset) begin
        unique_prefetch_counter <= 32'b0;
        unused_prefetch_counter <= 32'b0;
        late_prefetch_counter <= 32'b0;
    end
end
```

To implement functionality, we add counter logic in the cache bank:

```systemverilog
// Counter 1: Unique prefetch requests
wire prefetch_mreq_push = mreq_push && req_is_prefetch;
always_ff @(posedge clk) begin
    if (reset) begin
        unique_prefetch_counter <= 32'b0;
    end else if (prefetch_mreq_push) begin
        unique_prefetch_counter <= unique_prefetch_counter + 1;
    end
end

// Counter 2: Unused prefetched blocks
always_ff @(posedge clk) begin
    if (reset) begin
        unused_prefetch_counter <= 32'b0;
    end else if (evict_fire && block_metadata[evict_way].prefetched && 
                  !block_metadata[evict_way].used) begin
        unused_prefetch_counter <= unused_prefetch_counter + 1;
    end
end

// Counter 3: Late prefetches
wire late_prefetch_detected = req_is_prefetch && has_addr_match && !has_prefetch_match;
always_ff @(posedge clk) begin
    if (reset) begin
        late_prefetch_counter <= 32'b0;
    end else if (late_prefetch_detected && core_req_fire) begin
        late_prefetch_counter <= late_prefetch_counter + 1;
    end
end
```

### Step 3: Printing Results

#### 3a: Editing `hw/rtl/VX_types.vh`
In order to print the results, we first need to add three new CSR definitions into `VX_types.vh` (in the `/hw/rtl/` directory)

**Note:** This file creates a `VX_types.h` file that's in the `/build/hw/` directory (after making the build)

```verilog
`define VX_CSR_MPM_PREFETCH_REQ     12'hB20     // unique prefetch requests
`define VX_CSR_MPM_PREFETCH_REQ_H   12'hBA0
`define VX_CSR_MPM_PREFETCH_UNUSED  12'hB21     // unused prefetches
`define VX_CSR_MPM_PREFETCH_UNUSED_H 12'hBA1
`define VX_CSR_MPM_PREFETCH_LATE    12'hB22     // late prefetches
`define VX_CSR_MPM_PREFETCH_LATE_H  12'hBA2
```

#### 3b: Editing `runtime/stub/utils.cpp`
To have `PERF: …` line at the end of the test, we need to add output logic within the `dcache_enable` if statement (in the `/runtime/stub/utils.cpp` file) with our newly added counters

```cpp
// ...

// PERF: Prefetch counters
uint64_t prefetch_requests;
CHECK_ERR(vx_mpm_query(hdevice, VX_CSR_MPM_PREFETCH_REQ, core_id, &prefetch_requests), {
return err;
});
uint64_t prefetch_unused;
CHECK_ERR(vx_mpm_query(hdevice, VX_CSR_MPM_PREFETCH_UNUSED, core_id, &prefetch_unused), {
return err;
});
uint64_t prefetch_late;
CHECK_ERR(vx_mpm_query(hdevice, VX_CSR_MPM_PREFETCH_LATE, core_id, &prefetch_late), {
return err;
});
fprintf(stream, "PERF: core%d: dcache prefetch requests=%ld\n", core_id, prefetch_requests);
fprintf(stream, "PERF: core%d: dcache prefetch unused=%ld\n", core_id, prefetch_unused);
fprintf(stream, "PERF: core%d: dcache prefetch late=%ld\n", core_id, prefetch_late);

// ...
```

#### 3c: Editing `sim/rtlsim/emulator.cpp`
Because our addresses are extended outside of the CSR address range, we need to expand it from 32 to 64 bits in the `user-defined MPM CSRs` section (in the `/sim/rtlsim/emulator.cpp` directory)

```cpp
// ...

if ((addr >= VX_CSR_MPM_BASE && addr < (VX_CSR_MPM_BASE + 64)) // CHANGE
 || (addr >= VX_CSR_MPM_BASE_H && addr < (VX_CSR_MPM_BASE_H + 64)))
 
// ...
```

#### 3d: Editing `runtime/rtlsim/vortex.cpp`
Similarly, we need to edit the `mpm_query()` function to support an extended address range (in the `/runtime/rtlsim/vortex.cpp` file)

```cpp
// ...

int mpm_query(uint32_t addr, uint32_t core_id, uint64_t *value) {
  uint32_t offset = addr - VX_CSR_MPM_BASE;
  if (offset > 63)  // CHANGE 1
    return -1;
  if (mpm_cache_.count(core_id) == 0) {
    uint64_t mpm_mem_addr = IO_MPM_ADDR + core_id * 64 * sizeof(uint64_t);  // CHANGE 2
    CHECK_ERR(this->download(mpm_cache_[core_id].data(), mpm_mem_addr, 64 * sizeof(uint64_t)), {  // CHANGE 3
      return err;
    });
  }
  *value = mpm_cache_.at(core_id).at(offset);
  return 0;
}

// ...
```

## Verification and Testing:

To test your changes, you can run the following to build and verify prefetch functionality

```bash
# Make the build
make -s

# Test with RTL simulation
./ci/blackbox.sh --driver=rtlsim --cores=1 --app=prefetch --perf=2
```

The expected result is a test passed message and an output of all 3 metric counters, feel free to change `kernel.cpp` with different instruction/data sizes to observe prefetch efficiency
