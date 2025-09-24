# Assignment #3: GPU Software Prefetching (SimX)

## Overview
This assignment focuses on implementing software prefetching mechanisms in a GPU cache system. You will first add a new prefetch instruction to SimX, then implement performance counters to measure prefetch effectiveness.

## Learning Objectives
- Learn how to add new instructions to SimX
- Implement software prefetch instruction in the simulator
- Design performance counters for prefetch analysis
- Analyze prefetch effectiveness through simulation

---

## Part 1: Adding Prefetch Instruction to SimX

### Step 1: Adding Prefetch Intrinsic

First, add the prefetch intrinsic to `runtime/include/vx_intrinsics.h`:

```c
// Add this to vx_intrinsics.h
#define vx_prefetch(addr) \
    __asm__ volatile (".word 0x7506b" : : "r"(addr) : "memory")
```

**Key Details:**
- `0x6b` is the opcode for instructions not defined by RISC-V
- `5` is the identifier for the prefetch instruction (identifiers 0-4 are already used)
- The instruction takes only one argument: the load address

### Step 2: Implementing in SimX

#### 2a: Decoding in `sim/simx/decode.cpp`
Add prefetch decoding:

```cpp
// In decode.cpp, add case for identifier 5
case 5: // Software prefetch
    instr_type = INSTR_PREFETCH;
    break;
```

**🔍 Hints for Decoding:**
- Look for the switch statement handling custom instructions (opcode 0x6b)
- Find where other custom instructions (tmc, wspawn, split, join, bar) are handled
- Add the case for identifier 5 in the same switch statement

#### 2b: Executing in `sim/simx/execute.cpp`
Add prefetch execution:

```cpp
// In execute.cpp, add case for INSTR_PREFETCH
case INSTR_PREFETCH:
    // Print prefetch address for debugging
    printf("Prefetch address: 0x%x\n", rsdata[0]);
    break;
```

**🔍 Hints for Execution:**
- Look for the switch statement handling instruction types
- Find where other instruction types are executed
- `rsdata[0]` contains the prefetch address from the source register
- Add debug output to verify prefetch instructions are being executed

### Step 3: Adding Prefetch Tag in SimX

#### 3a: Adding Prefetch Tag in `sim/simx/VX_lsu_unit.sv`
Add prefetch bit to the tag before it reaches the cache bank:

```systemverilog
// In VX_lsu_unit.sv, add prefetch bit to tag
wire [TAG_WIDTH+1:0] extended_tag;
assign extended_tag = {core_req_tag, 1'b0, req_is_prefetch};

// Use extended tag for cache requests
assign cache_req_tag = extended_tag[TAG_WIDTH-1:0];
```

#### 3b: Adding Prefetch Tag in `sim/simx/VX_cache_bank.sv`
Add prefetch bit to the debug header:

```systemverilog
// In VX_cache_bank.sv, add prefetch bit to debug header
wire req_is_prefetch = core_req_tag[0]; // Adjust bit position as needed

// Add to debug header
$write(" [PREFETCH:%d]", req_is_prefetch);
```

### Step 4: Creating Test Application

#### 4a: Create Prefetch Test
```bash
# Create prefetch test from fence test
cp -r tests/regression/fence tests/regression/prefetch
cd tests/regression/prefetch

# Modify the Makefile
sed -i 's/PROJECT=fence/PROJECT=prefetch/g' Makefile
```

#### 4b: Modify kernel.c
Edit `kernel.c` to add prefetch instructions:

```c
// In the main loop of kernel.c, add:
for (uint32_t i = 0; i < count; ++i) {
    // ... existing code ...
    vx_prefetch(src0_ptr + offset + i);  // Add prefetch instruction
    // ... rest of the loop ...
}
```

#### 4c: Build and Test
```bash
# Build the test
make

# Test with SimX
./ci/blackbox.sh --driver=simx --cores=1 --app=prefetch
```

### Step 5: Verifying Prefetch Instructions

#### 5a: Check Kernel Dump
```bash
# Look for prefetch opcode in kernel dump
cat kernel.dump | grep "0x7506b"

# You should see:
# 800000b0:	0007506b          	0x7506b
```

#### 5b: Debug Output
You should see prefetch addresses printed during execution:
```
Prefetch address: 0x80001000
Prefetch address: 0x80001004
Prefetch address: 0x80001008
```

---

## Part 2: Implementing Performance Counters

Now that you have prefetch instructions working in SimX, implement the three performance counters to measure prefetch effectiveness.

### Overview
Implement three performance counters in `VX_cache_bank.sv` to measure prefetch effectiveness:

1. **Unique Prefetch Requests**: Counts first-time prefetch requests to memory
2. **Unused Prefetched Blocks**: Counts prefetched blocks that were evicted without being used
3. **Late Prefetches**: Counts prefetch requests that arrive after a demand request for the same address

---

### 2a: Unique Prefetch Requests Counter

#### Objective
Count the number of unique prefetch requests that actually reach main memory (not served by cache hits).

#### SimX Implementation Details
- **Signal to Monitor**: Use the `mreq_push` signal in `sim/simx/VX_cache_bank.sv`
- **Logic**: Increment counter when a prefetch request is pushed to memory (indicating a cache miss)
- **Filtering**: Only count prefetch requests, not demand requests
- **Implementation**: SystemVerilog simulation code in SimX

### 🔍 **HINTS FOR PART 2a**

#### Hint 2a.1: Signal Monitoring Location
- Look for `mreq_push` signal in `sim/simx/VX_cache_bank.sv` - this indicates memory requests
- You need to filter this signal to only count prefetch requests
- **Location**: Find where `mreq_push` is used in the cache bank

#### Hint 2a.2: Prefetch Bit Extraction
```systemverilog
// Extract prefetch bit from the tag (adjust based on your tag structure)
wire req_is_prefetch = core_req_tag[0]; // or appropriate bit position
```

**🔍 Key Points:**
- The prefetch bit should be added to the tag in `sim/simx/VX_lsu_unit.sv` before reaching the cache bank
- You may need to adjust the bit position based on your tag structure
- Test with debug output to verify the prefetch bit is correctly extracted

#### Hint 2a.3: Counter Implementation Pattern
```systemverilog
// Counter declaration
reg [31:0] unique_prefetch_counter;

// Filter for prefetch requests only
wire prefetch_mreq_push = mreq_push && req_is_prefetch;

// Counter increment logic
always @(posedge clk) begin
    if (reset) begin
        unique_prefetch_counter <= 32'b0;
    end else if (prefetch_mreq_push) begin
        unique_prefetch_counter <= unique_prefetch_counter + 1;
    end
end
```

**🔍 Implementation Tips:**
- Add the counter near other performance counters in `sim/simx/VX_cache_bank.sv`
- Use proper reset logic with the `reset` signal
- Test with debug output to verify counter increments

#### Key Points
- Multiple prefetch requests to the same address should only be counted once
- Cache hits for prefetch requests should not increment the counter
- Only memory requests (cache misses) should be counted

---

### 2b: Unused Prefetched Blocks Counter

#### Objective
Track prefetched blocks that are evicted from the cache without ever being accessed by demand requests.

#### Implementation Strategy

##### Step 1: Extend Tag Store
- Add prefetch bit to the tag store in `VX_tag_access.sv`
- This bit indicates whether a block was brought in by a prefetch request
- Update tag store operations to maintain this information

##### Step 2: Usage Tracking Data Structure
- Add a new data structure in stage 1 of the cache pipeline (data access stage)
- **Reference**: Look at `VX_Cache_tags.sv` for implementation patterns
- **Purpose**: Track whether each cache block has been used since being prefetched
- **Scope**: Universal tracking for every cache block

##### Step 3: Counter Logic
- **Increment Condition**: When a prefetched block is evicted (fill operation) and was never used
- **Detection Point**: During fill operations when blocks are evicted from cache
- **Logic**: Check if block was prefetched AND never accessed by demand request

### 🔍 **HINTS FOR PART 2b**

#### Hint 2b.1: Tag Store Extension
- In `sim/simx/VX_tag_access.sv`, extend the tag width to include prefetch bit
- Look for tag store read/write operations and add prefetch bit handling

**🔍 Implementation Details:**
```systemverilog
// Extend tag width to include prefetch bit
localparam TAG_WIDTH_EXT = TAG_WIDTH + 1;

// Modify tag store operations to include prefetch bit
wire [TAG_WIDTH_EXT-1:0] extended_tag_data;
assign extended_tag_data = {tag_data, prefetch_bit};
```

#### Hint 2b.2: Usage Tracking Data Structure
```systemverilog
// Add this structure to track block metadata
typedef struct packed {
    logic prefetched;
    logic used;
} cache_block_metadata_t;

cache_block_metadata_t block_metadata [NUM_WAYS-1:0];
```

**🔍 Key Points:**
- This structure tracks metadata for each cache way
- `prefetched` indicates if the block was brought in by a prefetch
- `used` indicates if the block has been accessed by a demand request
- Initialize all metadata to zero on reset

#### Hint 2b.3: Usage Tracking Logic
```systemverilog
// Track when blocks are used (on cache hits)
always @(posedge clk) begin
    if (core_req_fire && is_hit) begin
        block_metadata[hit_way].used <= 1'b1;
    end
end

// Track when blocks are prefetched (on fill operations)
always @(posedge clk) begin
    if (fill_fire && req_is_prefetch) begin
        block_metadata[fill_way].prefetched <= 1'b1;
        block_metadata[fill_way].used <= 1'b0;
    end
end
```

#### Hint 2b.4: Counter Logic
```systemverilog
// Counter for unused prefetched blocks
reg [31:0] unused_prefetch_counter;

// Increment when prefetched block is evicted unused
always @(posedge clk) begin
    if (reset) begin
        unused_prefetch_counter <= 32'b0;
    end else if (evict_fire && block_metadata[evict_way].prefetched && 
                  !block_metadata[evict_way].used) begin
        unused_prefetch_counter <= unused_prefetch_counter + 1;
    end
end
```

#### Implementation Steps
1. Extend tag store with prefetch bit in `VX_tag_access.sv`
2. Add usage tracking data structure in cache pipeline stage 1
3. Implement counter logic in fill operation path
4. Test with prefetch scenarios where blocks are evicted unused

---

### 2c: Late Prefetches Counter

#### Objective
Count prefetch requests that arrive while a demand request for the same address is already pending in the MSHR (Miss Status Holding Register).

#### Implementation Strategy

##### Step 1: MSHR Prefetch Tracking
- Add a data structure in the MSHR to track prefetch bits for pending requests
- **Reference**: Study `addr_table` implementation for data structure patterns
- **Purpose**: Know whether pending MSHR entries are prefetch or demand requests

##### Step 2: Late Prefetch Detection
- **Reference**: Study `addr_matches` implementation for matching logic
- **Logic**: Detect when a prefetch request matches a pending demand request address
- **Counter**: Increment when prefetch arrives after demand request for same address

### 🔍 **HINTS FOR PART 2c**

#### Hint 2c.1: MSHR Data Structure
```systemverilog
// Add prefetch bit to MSHR entries
typedef struct packed {
    logic [ADDR_WIDTH-1:0] address;
    logic prefetch;
    logic valid;
} mshr_entry_t;

mshr_entry_t mshr_table [MSHR_SIZE-1:0];
```

**🔍 Implementation Details:**
- Add this structure to `sim/simx/VX_cache_mshr.sv`
- `address` stores the memory address being requested
- `prefetch` indicates if the request is a prefetch
- `valid` indicates if the MSHR entry is active
- Update MSHR operations to include prefetch bit when allocating entries

#### Hint 2c.2: Address Matching Logic
```systemverilog
// Check for address matches with existing MSHR entries
wire [MSHR_SIZE-1:0] addr_matches;
wire [MSHR_SIZE-1:0] prefetch_matches;

for (genvar i = 0; i < MSHR_SIZE; i++) begin : g_addr_matches
    assign addr_matches[i] = mshr_table[i].valid && 
                            (mshr_table[i].address == core_req_addr);
    assign prefetch_matches[i] = addr_matches[i] && mshr_table[i].prefetch;
end
```

#### Hint 2c.3: Late Prefetch Detection
```systemverilog
// Detect late prefetch: new prefetch request matches existing demand request
wire late_prefetch_detected = req_is_prefetch && (|addr_matches) && 
                              !(|prefetch_matches);

// Counter increment logic
always @(posedge clk) begin
    if (reset) begin
        late_prefetch_counter <= 32'b0;
    end else if (late_prefetch_detected) begin
        late_prefetch_counter <= late_prefetch_counter + 1;
    end
end
```

#### Implementation Steps
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

### 🔍 **Using Prefetch Instructions**

The assignment assumes that prefetch instructions are already available in the system. You can use them in your test applications by:

#### Method 1: Using Existing Prefetch Test
```bash
# If a prefetch test exists, use it directly
cd tests/regression/prefetch/
./ci/blackbox.sh --driver=rtlsim --cores=1 --app=prefetch --perf=1
```

#### Method 2: Using Prefetch in Your Own Code
If you need to create a test that uses prefetch instructions, you can use the prefetch intrinsics in your kernel code:

```c
// Example usage of prefetch instructions in kernel code
for (uint32_t i = 0; i < count; ++i) {
    // Use prefetch to hint cache about upcoming data
    vx_prefetch(src0_ptr + offset + i);
    
    // Actual computation
    result[i] = src0_ptr[offset + i] * 2;
}
```

### 🔍 **Debugging Prefetch Instructions**

#### Enable Prefetch Debug Output
```systemverilog
`ifdef DBG_PREFETCH
    always @(posedge clk) begin
        if (core_req_fire && req_is_prefetch) begin
            $display("[%0t] Prefetch Request: addr=%h, tag=%h", 
                     $time, core_req_addr, core_req_tag);
        end
    end
`endif
```

#### Monitor Prefetch Counter Values
```systemverilog
`ifdef DBG_PREFETCH_COUNTERS
    always @(posedge clk) begin
        if (unique_prefetch_counter != 0 || unused_prefetch_counter != 0 || 
            late_prefetch_counter != 0) begin
            $display("[%0t] Prefetch Counters: unique=%d, unused=%d, late=%d", 
                     $time, unique_prefetch_counter, unused_prefetch_counter, 
                     late_prefetch_counter);
        end
    end
`endif
```

### 🔍 **Common Issues and Solutions**

#### Issue 1: Prefetch Bit Not Propagating
**Problem**: Prefetch bit not reaching the cache bank
**Solution**: 
- Check that prefetch bit is added to tag in `VX_lsu_unit.sv`
- Verify tag extension before truncation occurs
- Add debug output to trace prefetch bit propagation

#### Issue 2: Counters Not Incrementing
**Problem**: Performance counters remain at zero
**Solution**:
- Verify signal filtering logic (prefetch vs demand requests)
- Check counter increment conditions
- Add debug output to monitor counter logic

#### Issue 3: Wrong Counter Values
**Problem**: Counter values don't match expected results
**Solution**:
- Verify each counter's specific logic
- Check timing of counter increments
- Test with simple, predictable prefetch patterns

#### Issue 4: Compilation Errors
**Problem**: SystemVerilog compilation fails
**Solution**:
- Check syntax for typedef declarations
- Verify signal names and bit widths
- Ensure proper reset logic for all counters

### Verification Strategy
1. **Unit Testing**: Test each counter individually with controlled scenarios
2. **Integration Testing**: Run full prefetch application with performance monitoring
3. **Result Validation**: Compare counter values with expected results
4. **Edge Cases**: Test boundary conditions and error scenarios

---

## Implementation Tips

### Code Organization
- Keep counter logic centralized in `VX_cache_bank.sv`
- Use consistent naming conventions for new signals and variables
- Add comprehensive comments explaining counter logic

### Debugging
- Use debug headers to verify prefetch bit propagation
- Add temporary debug output for counter values during development
- Test with simple, predictable prefetch patterns first

### Performance Considerations
- Ensure counter updates don't impact cache performance
- Use efficient data structures for tracking
- Minimize additional logic in critical cache paths

---

## Deliverables

1. **Modified Files**:
   - `runtime/include/vx_intrinsics.h` (prefetch intrinsic)
   - `sim/simx/decode.cpp` (prefetch decoding)
   - `sim/simx/execute.cpp` (prefetch execution)
   - `VX_cache_bank.sv` (performance counters)
   - `VX_tag_access.sv` (tag store extension)
   - Any additional files with MSHR modifications

2. **Verification**:
   - Successful compilation
   - Correct counter values for test case
   - Debug output showing prefetch bit

3. **Documentation**:
   - Comments explaining counter logic
   - Brief description of implementation approach
   - Any assumptions or design decisions made

---

## 🎯 **QUICK IMPLEMENTATION CHECKLIST**

### Part 1: SimX Implementation
- [ ] Add prefetch intrinsic to `vx_intrinsics.h`
- [ ] Add prefetch decoding in `decode.cpp`
- [ ] Add prefetch execution in `execute.cpp`
- [ ] Create prefetch test application
- [ ] Test with SimX and verify debug output

### Part 2a: Unique Prefetch Counter
- [ ] Monitor `mreq_push` signal
- [ ] Filter for prefetch requests only
- [ ] Implement counter increment logic

### Part 2b: Unused Prefetched Blocks Counter
- [ ] Extend tag store in `VX_tag_access.sv`
- [ ] Add usage tracking data structure
- [ ] Track block usage on cache hits
- [ ] Track block prefetch status on fills
- [ ] Implement counter logic on eviction

### Part 2c: Late Prefetches Counter
- [ ] Add prefetch bit to MSHR entries
- [ ] Implement address matching logic
- [ ] Detect late prefetch conditions
- [ ] Implement counter increment logic

### Verification
- [ ] Run test command and verify expected results
- [ ] Add debug output for troubleshooting
- [ ] Test edge cases and boundary conditions

---

## Assignment 3 vs Assignment 4 Summary

| **Aspect** | **Assignment 3 (SimX)** | **Assignment 4 (RTL)** |
|------------|-------------------------|------------------------|
| **Implementation** | C++ software simulation | SystemVerilog hardware |
| **File Paths** | `sim/simx/` | `hw/rtl/` |
| **Counters** | Software variables | Hardware registers |
| **Timing** | Cycle-accurate simulation | Real hardware timing |
| **Debugging** | `printf` statements | `$display` statements |
| **Synthesis** | Not synthesizable | Synthesizable to hardware |
| **Purpose** | Simulation and testing | Hardware implementation |

**Prerequisites**: Assignment 3 must be completed before Assignment 4.

---

*This document was created with assistance from Claude, an AI assistant, to provide comprehensive guidance for implementing GPU software prefetching in SimX simulation.*
