# Assignment #4: GPU Software Prefetching (RTL)

## Overview
This assignment focuses on implementing software prefetching mechanisms at the RTL (Register Transfer Level) in a GPU cache system. You will extend the cache architecture to support prefetch operations and add performance monitoring capabilities using SystemVerilog hardware description.

**⚠️ IMPORTANT**: This is the RTL (hardware) implementation. You must complete Assignment #3 (SimX simulation) first.

## Learning Objectives
- Learn how to add new instructions to SimX and implement them in RTL
- Implement software prefetch instruction in the simulator and RTL pipeline
- Design RTL performance counters for prefetch analysis
- Master SystemVerilog hardware description for cache systems
- Analyze prefetch effectiveness through RTL simulation

---

## Part 1: Prerequisites from Assignment 3

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

---

## Part 2: RTL Implementation of Prefetch Instruction

Now that you have the SimX implementation working from Assignment 3, let's implement the same functionality in RTL.

### Step 1: RTL Pipeline Implementation

#### 1a: Adding Opcode in `hw/rtl/VX_gpu_pkg.sv`
The custom instruction opcode `0x6b` (INST_EXT4) should already be defined:

```systemverilog
// These should already exist in VX_gpu_pkg.sv
localparam INST_EXT4 = 7'b1111011; // 0x7B (this is 0x6b)

// You may need to add this constant for prefetch instruction
localparam INST_LSU_PREFETCH = 3'd5;
```

**🔍 Key Points:**
- `INST_EXT4` corresponds to opcode `0x6b` (107 in decimal)
- The prefetch instruction uses identifier `5` in the funct3 field
- You may need to define `INST_LSU_PREFETCH` constant for the LSU operation type

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

**🔍 RTL Implementation Hints:**
- Software prefetch executes in the LSU (Load Store Unit)
- The immediate field contains the address and needs sign extension
- Prefetch mimics a load instruction but ignores the load response
- No writeback to destination register

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

---

## Part 3: RTL Performance Counter Implementation

Now that you have prefetch instructions working in RTL, implement the same three performance counters from Assignment 3, but using RTL SystemVerilog instead of SimX C++.

### Overview
Implement the same three performance counters from Assignment 3, but using RTL SystemVerilog in `VX_cache_bank.sv`:

1. **Unique Prefetch Requests**: RTL version of the SimX counter from Assignment 3
2. **Unused Prefetched Blocks**: RTL version of the SimX counter from Assignment 3  
3. **Late Prefetches**: RTL version of the SimX counter from Assignment 3

**🔍 RTL vs SimX Differences:**
- SimX uses C++ code for counters
- RTL uses SystemVerilog hardware description
- RTL counters are implemented as hardware registers
- RTL counters are synthesized into actual hardware logic

---

### 3a: RTL Unique Prefetch Requests Counter

#### Objective
Count the number of unique prefetch requests that actually reach main memory (not served by cache hits).

#### RTL Implementation Details
- **Signal to Monitor**: Use the `mreq_push` signal in `VX_cache_bank.sv`
- **RTL Logic**: Increment counter when a prefetch request is pushed to memory (indicating a cache miss)
- **Hardware Filtering**: Only count prefetch requests, not demand requests

### 🔍 **RTL HINTS FOR PART 2a**

#### Hint 2a.1: RTL Signal Monitoring Location
- Look for `mreq_push` signal in `VX_cache_bank.sv` - this indicates memory requests
- You need to filter this signal to only count prefetch requests
- **Location**: Find where `mreq_push` is used in the cache bank

#### Hint 2a.2: RTL Prefetch Bit Extraction
```systemverilog
// Extract prefetch bit from the extended tag (adjust based on your tag structure)
wire req_is_prefetch = core_req_tag[0]; // Adjust bit position as needed
```

**🔍 RTL Key Points:**
- The prefetch bit should be added to the tag in `VX_lsu_unit.sv` before reaching the cache bank
- The tag is extended to include the prefetch bit: `{uuid, wid, rd, is_prefetch}`
- You may need to adjust the bit position based on your tag structure
- Test with RTL debug output to verify the prefetch bit is correctly extracted

#### Hint 2a.3: RTL Counter Implementation Pattern
```systemverilog
// Counter declaration
reg [31:0] unique_prefetch_counter;

// Filter for prefetch requests only
wire prefetch_mreq_push = mreq_push && req_is_prefetch;

// Counter increment logic
always_ff @(posedge clk) begin
    if (reset) begin
        unique_prefetch_counter <= 32'b0;
    end else if (prefetch_mreq_push) begin
        unique_prefetch_counter <= unique_prefetch_counter + 1;
    end
end
```

**🔍 RTL Implementation Tips:**
- Use `always_ff` for sequential logic in SystemVerilog
- Add the counter near other performance counters in `VX_cache_bank.sv`
- Use proper reset logic with the `reset` signal
- Test with RTL debug output to verify counter increments

#### Key Points
- Multiple prefetch requests to the same address should only be counted once
- Cache hits for prefetch requests should not increment the counter
- Only memory requests (cache misses) should be counted

---

### 3b: RTL Unused Prefetched Blocks Counter

#### Objective
Track prefetched blocks that are evicted from the cache without ever being accessed by demand requests.

#### RTL Implementation Strategy

##### Step 1: RTL Tag Store Extension
- **Hardware Modification**: Add prefetch bit to the tag store in `VX_tag_access.sv`
- **RTL Purpose**: Hardware flag indicating whether a block was brought in by a prefetch request
- **SystemVerilog Implementation**: Update tag store operations to maintain this information

##### Step 2: RTL Usage Tracking Data Structure
- **Hardware Location**: Add new data structure in stage 1 of the cache pipeline (data access stage)
- **RTL Reference**: Look at `VX_Cache_tags.sv` for SystemVerilog implementation patterns
- **Hardware Purpose**: Track whether each cache block has been used since being prefetched
- **RTL Scope**: Universal tracking for every cache block using hardware registers

##### Step 3: RTL Counter Logic
- **Increment Condition**: When a prefetched block is evicted (fill operation) and was never used
- **RTL Detection Point**: During fill operations when blocks are evicted from cache
- **Hardware Logic**: Check if block was prefetched AND never accessed by demand request

### 🔍 **RTL HINTS FOR PART 2b**

#### Hint 2b.1: RTL Tag Store Extension
- In `hw/rtl/cache/VX_tag_access.sv`, extend the tag width to include prefetch bit
- Look for tag store read/write operations and add prefetch bit handling

**🔍 RTL Implementation Details:**
```systemverilog
// Extend tag width to include prefetch bit
localparam TAG_WIDTH_EXT = TAG_WIDTH + 1;

// Tag store with prefetch bit
VX_sp_ram #(
    .DATAW (TAG_WIDTH_EXT),
    .SIZE  (CACHE_SIZE),
    .ADDRW (CACHE_ADDR_WIDTH)
) tag_store (
    .clk   (clk),
    .reset (reset),
    .read  (tag_read),
    .write (tag_write),
    .wren  (tag_wren),
    .waddr (tag_waddr),
    .wdata ({tag_wdata, prefetch_bit}), // Include prefetch bit
    .raddr (tag_raddr),
    .rdata (tag_rdata_ext)
);

// Extract tag and prefetch bit
assign tag_rdata = tag_rdata_ext[TAG_WIDTH_EXT-1:1];
assign tag_prefetch_bit = tag_rdata_ext[0];
```

#### Hint 2b.2: RTL Usage Tracking Data Structure
```systemverilog
// Add this structure to track block metadata
typedef struct packed {
    logic prefetched;
    logic used;
} cache_block_metadata_t;

cache_block_metadata_t block_metadata [NUM_WAYS-1:0];
```

**🔍 RTL Key Points:**
- This structure tracks metadata for each cache way
- `prefetched` indicates if the block was brought in by a prefetch
- `used` indicates if the block has been accessed by a demand request
- Initialize all metadata to zero on reset

#### Hint 2b.3: RTL Usage Tracking Logic
```systemverilog
// Track when blocks are used (on cache hits)
always_ff @(posedge clk) begin
    if (reset) begin
        for (integer i = 0; i < NUM_WAYS; i++) begin
            block_metadata[i] <= '{prefetched: 1'b0, used: 1'b0};
        end
    end else if (core_req_fire && is_hit) begin
        block_metadata[hit_way].used <= 1'b1;
    end
end

// Track when blocks are prefetched (on fill operations)
always_ff @(posedge clk) begin
    if (fill_fire && req_is_prefetch) begin
        block_metadata[fill_way].prefetched <= 1'b1;
        block_metadata[fill_way].used <= 1'b0;
    end
end
```

#### Hint 2b.4: RTL Counter Logic
```systemverilog
// Counter for unused prefetched blocks
reg [31:0] unused_prefetch_counter;

// Increment when prefetched block is evicted unused
always_ff @(posedge clk) begin
    if (reset) begin
        unused_prefetch_counter <= 32'b0;
    end else if (evict_fire && block_metadata[evict_way].prefetched && 
                  !block_metadata[evict_way].used) begin
        unused_prefetch_counter <= unused_prefetch_counter + 1;
    end
end
```

#### RTL Implementation Steps
1. Extend tag store with prefetch bit in `VX_tag_access.sv`
2. Add usage tracking data structure in cache pipeline stage 1
3. Implement counter logic in fill operation path
4. Test with prefetch scenarios where blocks are evicted unused

---

### 3c: RTL Late Prefetches Counter

#### Objective
Count prefetch requests that arrive while a demand request for the same address is already pending in the MSHR (Miss Status Holding Register).

#### RTL Implementation Strategy

##### Step 1: RTL MSHR Prefetch Tracking
- **Hardware Data Structure**: Add a data structure in the MSHR to track prefetch bits for pending requests
- **RTL Reference**: Study `addr_table` implementation for SystemVerilog data structure patterns
- **Hardware Purpose**: Know whether pending MSHR entries are prefetch or demand requests

##### Step 2: RTL Late Prefetch Detection
- **RTL Reference**: Study `addr_matches` implementation for SystemVerilog matching logic
- **Hardware Logic**: Detect when a prefetch request matches a pending demand request address
- **RTL Counter**: Increment when prefetch arrives after demand request for same address

### 🔍 **RTL HINTS FOR PART 2c**

#### Hint 2c.1: RTL MSHR Data Structure
```systemverilog
// Extend MSHR entry structure to include prefetch bit
typedef struct packed {
    logic [`LINE_ADDR_WIDTH-1:0] addr;
    logic [`CORE_TAG_WIDTH-1:0]  tag;
    logic                        prefetch;
    logic                        valid;
} mshr_entry_t;

mshr_entry_t mshr_table [MSHR_SIZE-1:0];
```

**🔍 RTL Implementation Details:**
- Add this structure to `hw/rtl/cache/VX_cache_mshr.sv`
- `addr` stores the line address being requested
- `tag` stores the core request tag
- `prefetch` indicates if the request is a prefetch
- `valid` indicates if the MSHR entry is active
- Update MSHR allocation logic to include prefetch bit when allocating entries

#### Hint 2c.2: RTL Address Matching Logic
```systemverilog
// Address matching logic for MSHR entries
wire [MSHR_SIZE-1:0] addr_matches;
wire [MSHR_SIZE-1:0] prefetch_matches;

for (genvar i = 0; i < MSHR_SIZE; i++) begin : g_addr_matches
    assign addr_matches[i] = mshr_table[i].valid && 
                            (mshr_table[i].addr == core_req_addr[`LINE_ADDR_WIDTH-1:0]);
    assign prefetch_matches[i] = addr_matches[i] && mshr_table[i].prefetch;
end
```

#### Hint 2c.3: RTL Late Prefetch Detection
```systemverilog
// Detect late prefetch: new prefetch request matches existing demand request
wire has_addr_match = |addr_matches;
wire has_prefetch_match = |prefetch_matches;
wire late_prefetch_detected = req_is_prefetch && has_addr_match && !has_prefetch_match;

// Counter increment logic
always_ff @(posedge clk) begin
    if (reset) begin
        late_prefetch_counter <= 32'b0;
    end else if (late_prefetch_detected && core_req_fire) begin
        late_prefetch_counter <= late_prefetch_counter + 1;
    end
end
```

#### RTL Implementation Steps
1. Add prefetch bit tracking to MSHR data structures
2. Implement address matching logic for late prefetch detection
3. Add counter increment logic when late prefetch is detected
4. Test with scenarios where prefetch and demand requests overlap

---

## Verification and Testing

### Test Command
```bash
# Test with the prefetch regression test
./ci/blackbox.sh --driver=rtlsim --cores=1 --app=prefetch --perf=1

# Alternative: Test with SimX first
./ci/blackbox.sh --driver=simx --cores=1 --app=prefetch
```

### Expected Results
- **# of unused prefetched blocks = 2**
- **# of late prefetches = 1**

### 🔍 **RTL Debugging and Verification**

#### Enable RTL Prefetch Debug Output
```systemverilog
`ifdef DBG_PREFETCH
    always_ff @(posedge clk) begin
        if (core_req_fire && req_is_prefetch) begin
            $display("[%0t] RTL Prefetch Request: addr=%h, tag=%h", 
                     $time, core_req_addr, core_req_tag);
        end
    end
`endif
```

#### Monitor RTL Prefetch Counter Values
```systemverilog
`ifdef DBG_PREFETCH_COUNTERS
    always_ff @(posedge clk) begin
        if (unique_prefetch_counter != 0 || unused_prefetch_counter != 0 || 
            late_prefetch_counter != 0) begin
            $display("[%0t] RTL Prefetch Counters: unique=%d, unused=%d, late=%d", 
                     $time, unique_prefetch_counter, unused_prefetch_counter, 
                     late_prefetch_counter);
        end
    end
`endif
```

### 🔍 **RTL Common Issues and Solutions**

#### Issue 1: RTL Prefetch Bit Not Propagating
**Problem**: Prefetch bit not reaching the cache bank in RTL
**Solution**: 
- Check that prefetch bit is added to tag in `VX_lsu_unit.sv`
- Verify tag extension before truncation occurs
- Add RTL debug output to trace prefetch bit propagation

#### Issue 2: RTL Counters Not Incrementing
**Problem**: Performance counters remain at zero in RTL simulation
**Solution**:
- Verify signal filtering logic (prefetch vs demand requests)
- Check counter increment conditions and timing
- Add RTL debug output to monitor counter logic

#### Issue 3: RTL Synthesis Issues
**Problem**: SystemVerilog code doesn't synthesize properly
**Solution**:
- Use proper SystemVerilog constructs for synthesis
- Check for combinational loops in counter logic
- Ensure all signals are properly declared and connected

#### Issue 4: RTL Timing Violations
**Problem**: Counter logic creates timing violations
**Solution**:
- Use proper clocking domains for all counters
- Add pipeline stages if needed for timing closure
- Consider counter width and increment frequency

### Verification Strategy
1. **RTL Unit Testing**: Test each counter individually with controlled scenarios
2. **RTL Integration Testing**: Run full prefetch application with RTL performance monitoring
3. **RTL Result Validation**: Compare counter values with expected results
4. **RTL Edge Cases**: Test boundary conditions and error scenarios

---

## RTL Implementation Tips

### RTL Code Organization
- Keep counter logic centralized in `VX_cache_bank.sv`
- Use consistent SystemVerilog naming conventions for new signals and variables
- Add comprehensive RTL comments explaining counter logic
- Use proper SystemVerilog data types and structures

### RTL Debugging
- Use debug headers to verify prefetch bit propagation in RTL
- Add temporary RTL debug output for counter values during development
- Test with simple, predictable prefetch patterns first
- Use RTL simulation tools for debugging

### RTL Performance Considerations
- Ensure counter updates don't impact cache performance in RTL
- Use efficient SystemVerilog data structures for tracking
- Minimize additional logic in critical cache paths
- Consider RTL timing constraints and pipeline stages

### RTL Best Practices
- Use proper SystemVerilog always_ff blocks for sequential logic
- Implement proper reset logic for all counters
- Use appropriate data types (logic, wire, reg) for RTL signals
- Follow RTL coding standards for readability and maintainability

---

## Deliverables

1. **Modified RTL Files**:
   - `runtime/include/vx_intrinsics.h` (prefetch intrinsic)
   - `sim/simx/decode.cpp` (prefetch decoding)
   - `sim/simx/execute.cpp` (prefetch execution)
   - `hw/rtl/VX_decode.sv` (RTL prefetch decoding)
   - `hw/rtl/interfaces/VX_lsu_req_if.sv` (prefetch interface)
   - `hw/rtl/VX_instr_demux.sv` (prefetch tag setting)
   - `hw/rtl/VX_lsu_unit.sv` (prefetch handling)
   - `VX_cache_bank.sv` (RTL performance counters)
   - `VX_tag_access.sv` (tag store extension)
   - Any additional files with MSHR modifications

2. **RTL Verification**:
   - Successful RTL compilation
   - Correct counter values for test case
   - RTL debug output showing prefetch bit
   - RTL simulation results

3. **RTL Documentation**:
   - SystemVerilog comments explaining counter logic
   - Brief description of RTL implementation approach
   - Any RTL assumptions or design decisions made
   - RTL timing considerations and constraints

---

## 🎯 **RTL QUICK IMPLEMENTATION CHECKLIST**

### Part 1: SimX and RTL Implementation
- [ ] Add prefetch intrinsic to `vx_intrinsics.h`
- [ ] Add prefetch decoding in `decode.cpp`
- [ ] Add prefetch execution in `execute.cpp`
- [ ] Add RTL prefetch decoding in `VX_decode.sv`
- [ ] Add prefetch interface in `VX_lsu_req_if.sv`
- [ ] Set prefetch tag in `VX_instr_demux.sv`
- [ ] Handle prefetch in `VX_lsu_unit.sv`
- [ ] Create prefetch test application
- [ ] Test with SimX and RTL simulation

### Part 2a: RTL Unique Prefetch Counter
- [ ] Monitor `mreq_push` signal
- [ ] Filter for prefetch requests only
- [ ] Implement RTL counter increment logic

### Part 2b: RTL Unused Prefetched Blocks Counter
- [ ] Extend tag store in `VX_tag_access.sv`
- [ ] Add usage tracking data structure
- [ ] Track block usage on cache hits
- [ ] Track block prefetch status on fills
- [ ] Implement RTL counter logic on eviction

### Part 2c: RTL Late Prefetches Counter
- [ ] Add prefetch bit to MSHR entries
- [ ] Implement address matching logic
- [ ] Detect late prefetch conditions
- [ ] Implement RTL counter increment logic

### RTL Verification
- [ ] Run test command and verify expected results
- [ ] Add RTL debug output for troubleshooting
- [ ] Test RTL edge cases and boundary conditions
- [ ] Verify RTL synthesis and timing

---

## Key Files to Modify

### RTL Pipeline Files
1. **`hw/rtl/VX_gpu_pkg.sv`**: Define `INST_LSU_PREFETCH` constant
2. **`hw/rtl/core/VX_decode.sv`**: Add prefetch instruction decoding
3. **`hw/rtl/interfaces/VX_lsu_req_if.sv`**: Add prefetch bit to interface
4. **`hw/rtl/core/VX_lsu_unit.sv`**: Handle prefetch requests
5. **`hw/rtl/core/VX_instr_demux.sv`**: Set prefetch flag

### Cache Implementation Files
6. **`hw/rtl/cache/VX_cache_bank.sv`**: Implement performance counters
7. **`hw/rtl/cache/VX_tag_access.sv`**: Extend tag store with prefetch bit
8. **`hw/rtl/cache/VX_cache_mshr.sv`**: Add prefetch tracking to MSHR

### Performance Counter Interface
9. **`hw/rtl/cache/VX_cache.sv`**: Wire performance counters from cache banks
10. **Top-level cache module**: Sum counters across all banks

---

## RTL vs SimX Implementation Differences

| **Aspect** | **SimX (Assignment 3)** | **RTL (Assignment 4)** |
|------------|-------------------------|------------------------|
| **Implementation** | C++ software simulation | SystemVerilog hardware |
| **Counters** | Software variables | Hardware registers |
| **Timing** | Cycle-accurate simulation | Real hardware timing |
| **Debugging** | `printf` statements | `$display` statements |
| **Synthesis** | Not synthesizable | Synthesizable to hardware |
| **Performance** | Software execution | Hardware logic gates |

---

## RTL Implementation Tips

### SystemVerilog Best Practices
- Use `always_ff` for sequential logic (counters, registers)
- Use `always_comb` for combinational logic (address matching)
- Use proper reset logic with the `reset` signal
- Use appropriate data types (`logic`, `wire`, `reg`)

### RTL Debugging
- Use `$display` statements for debug output
- Add conditional compilation with `ifdef` for debug features
- Test with simple, predictable prefetch patterns first
- Use RTL simulation tools for debugging

### Performance Considerations
- Ensure counter updates don't impact cache performance
- Use efficient SystemVerilog data structures
- Minimize additional logic in critical cache paths
- Consider RTL timing constraints and pipeline stages

---

## Summary

This RTL assignment implements the same prefetch functionality from Assignment 3 using SystemVerilog hardware description language. The key differences are:

1. **Hardware Implementation**: All logic is implemented as synthesizable RTL
2. **Performance Counters**: Implemented as hardware registers with proper clocking
3. **Pipeline Integration**: Prefetch instruction integrated into RTL decode and execution pipeline
4. **Cache Integration**: Performance counters integrated into cache bank hardware
5. **Debugging**: RTL-specific debug output using SystemVerilog constructs

The RTL implementation maintains the same functionality as the SimX version while being implementable in actual hardware.

---

*This document was created with assistance from Claude, an AI assistant, to provide comprehensive guidance for implementing GPU software prefetching in RTL hardware using SystemVerilog.*
