# Assignment #3: GPU Software Prefetching (SimX)

This assignment will be divided into two parts. The first part involves adding a new prefetch instruction as well as a corresponding flag bit to identify if it has been prefetched. The second involves adding three performance counters to measure the following:

1. Number of unique prefetch requests to main memory
2. Number of unused prefetched blocks
3. Number of late prefetches

All of these counters should be implemented in `cache_sim.h`

## Part 1: Adding Prefetch Instruction to SimX

To begin, we will add the prefetch instruction in a new group of instructions. Then we want to develop a testing directory and script to ensure correctness and functionality

### Step 1: Adding Prefetch Intrinsic

First, add the prefetch intrinsic to `/kernel/include/vx_intrinsics.h` (right after `vx_barrier()`)

```c
// Software Prefetch
inline void vx_prefetch(const void* addr) {
    __asm__ volatile (".insn r %0, 0, 5, x0, %1, x0" :: "i"(RISCV_CUSTOM0), "r"(addr) : "memory");
}
```

This will create a new group for the prefetch instruction, where this instruction is an R-type instruction format

### Step 2: Implement into SimX

#### 2a: Editing `types.h`

Before we can decode the instruction, we need to add a new `PREFETCH` value into `LsuType` in the file `/sim/simx/types.h` 

```cpp
enum class LsuType {
  LOAD,
  STORE,
  FENCE,
  PREFETCH  // ADD
};
```

We also need a prefetch case for `std::ostream` 

```cpp
inline std::ostream &operator<<(std::ostream &os, const LsuType& type) {
  switch (type) {
  case LsuType::LOAD:     os << "LOAD"; break;
  case LsuType::STORE:    os << "STORE"; break;
  case LsuType::FENCE:    os << "FENCE"; break;
  case LsuType::PREFETCH: os << "PREFETCH"; break;  // ADD
  default:
    assert(false);
  }
  return os;
}
```

#### 2b: Editing `decode.cpp`

We want to update `case Opcode::EXT1:` (in the `/sim/simx/decode.cpp` file) where we add the new prefetch instruction group (right after the `case 2` instruction group)

```cpp
case 5: { // SOFTWARE PREFETCH
	auto instr = std::allocate_shared<Instr>(instr_pool_, uuid, FUType::LSU);
  switch (funct3) {
	  case 0: // PREFETCH
	    instr->setOpType(LsuType::PREFETCH);  // Make sure it is set to PREFETCH
	    instr->setArgs(IntrLsuArgs{0, 0, 0});
	    instr->setSrcReg(0, rs1, RegType::Integer);
	    break;
    default:
      std::abort();
  }
  ibuffer.push_back(instr);
} break;
```

In the `op_string()` function, we need to add a `PREFETCH` case (under the `FENCE` case)

```cpp
case LsuType::PREFETCH: return {"PREFETCH", ""};  // ADD
```

#### 2c: Editing `execute.cpp`

In order for the instruction to perform a prefetch, we need to add a case for `PREFETCH` in the `execute()` function (in the `/sim/simx/execute.cpp` file)

```cpp
case LsuType::PREFETCH: {
    auto trace_data = std::make_shared<LsuTraceData>(num_threads);
    trace->data = trace_data;
    
    for (uint32_t t = thread_start; t < num_threads; ++t) {
        if (!warp.tmask.test(t))
            continue;
        uint64_t prefetch_addr = rs1_data[t].u;
        
        // Record the prefetch address in trace
        trace_data->mem_addrs.at(t) = {prefetch_addr, 4}; // 4 bytes or cache line size
        
        // Issue dummy read to populate cache
        uint32_t dummy;
        this->dcache_read(&dummy, prefetch_addr, sizeof(uint32_t));
        
        DP(2, "PREFETCH: addr=0x" << std::hex << prefetch_addr << std::dec << " (thread " << t << ")");
    }
} break;
```

In this implementation, we issue a dummy read in order to populate a cache. This will trigger SimX to place data (from an address) into cache, essentially prefetching the data. The instruction will not modify or perform anything outside of that.

### Step 3: Creating Test Application

#### 3a: Creating Test Directory

In `/tests/regression/`, we want to duplicate the `fence` folder and rename it to `prefetch` 

```bash
# Create prefetch test from fence test
cp -r tests/regression/fence tests/regression/prefetch
cd tests/regression/prefetch

# Modify the Makefile
sed -i 's/PROJECT=fence/PROJECT=prefetch/g' Makefile
```

You should now have the `/tests/regression/prefetch` directory, this will be our testing directory for our new instruction

**Note:** When cloning, make sure you go into `Makefile` and adjust the project name to `prefetch`

#### 3b: Modify Test Script

We will need to modify `kernel.cpp` (in the testing directory) and add a call to `vx_prefetch()` 

```cpp
#include <vx_spawn.h>
#include <vx_intrinsics.h>  // ADD
#include "common.h"

void kernel_body(kernel_arg_t* __UNIFORM__ arg) {
	uint32_t count    = arg->task_size;
	int32_t* src0_ptr = (int32_t*)arg->src0_addr;
	int32_t* src1_ptr = (int32_t*)arg->src1_addr;
	int32_t* dst_ptr  = (int32_t*)arg->dst_addr;

	uint32_t offset = blockIdx.x * count;

	const uint32_t elements_per_line = 16; // ADD: 64 bytes cache size / 4 bytes per int_32
    
  for (uint32_t i = 0; i < count; ++i) {
	  // ADD: Only prefetch at cache line boundaries
    if (i % elements_per_line == 0) {
		vx_prefetch(&src0_ptr[offset + i]);
      	vx_prefetch(&src1_ptr[offset + i]);
    }
        
    dst_ptr[offset+i] = src0_ptr[offset+i] + src1_ptr[offset+i];
  }

	vx_fence();

}

int main() {
	kernel_arg_t* arg = (kernel_arg_t*)csr_read(VX_CSR_MSCRATCH);
	return vx_spawn_threads(1, &arg->num_tasks, nullptr, (vx_kernel_func_cb)kernel_body, arg);
}
```

#### 3c: Building and Testing

To check and see that the new instruction is working, run the following commands in your `/build/` directory

**Note:** Check to see if you ran `source ./ci/toolchain_env.sh` before building!

```bash
# Make the build
make -s

# Run debug to check to see if prefetch output is printed
./ci/blackbox.sh --driver=simx --cores=1 --app=prefetch --debug=2
```

All output will be in `run.log` in the `/build/` directory, check to see if `DEBUG PREFETCH: …` is present

## Part 2: Implementing Performance Counters

Now that you have prefetch instructions working in SimX, we want to implement the three performance counters to measure prefetch effectiveness

### Step 1: Adding Prefetch Flags

#### 1a: Editing `types.h`

We want to add the `is_prefetch` flag to `LsuReq` (in the `/sim/simx/types.h` directory)

```cpp
struct LsuReq {
  BitVector<> mask;
  std::vector<uint64_t> addrs;
  bool     write;
  uint32_t tag;
  uint32_t cid;
  uint64_t uuid;
  bool     is_prefetch;  // ADD

  LsuReq(uint32_t size)
    : mask(size)
    , addrs(size, 0)
    , write(false)
    , tag(0)
    , cid(0)
    , uuid(0)
    , is_prefetch(false)  // ADD
  {}

  friend std::ostream &operator<<(std::ostream &os, const LsuReq& req) {
    os << "rw=" << req.write << ", mask=" << req.mask << ", addr={";
    bool first_addr = true;
    for (size_t i = 0; i < req.mask.size(); ++i) {
      if (!first_addr) os << ", ";
      first_addr = false;
      if (req.mask.test(i)) {
        os << "0x" << std::hex << req.addrs.at(i) << std::dec;
      } else {
        os << "-";
      }
    }
    os << "}, tag=0x" << std::hex << req.tag << std::dec << ", cid=" << req.cid;
    if (req.is_prefetch) os << ", prefetch=1";  // ADD
    os << " (#" << req.uuid << ")";
    return os;
  }
};
```

Similarly, we will add the same flag to `MemReq` 

```cpp
struct MemReq {
  uint64_t addr;
  bool     write;
  AddrType type;
  uint32_t tag;
  uint32_t cid;
  uint64_t uuid;
  bool     is_prefetch;  // ADD

  MemReq(uint64_t _addr = 0,
          bool _write = false,
          AddrType _type = AddrType::Global,
          uint64_t _tag = 0,
          uint32_t _cid = 0,
          uint64_t _uuid = 0,
          bool _is_prefetch = false  // ADD
  ) : addr(_addr)
    , write(_write)
    , type(_type)
    , tag(_tag)
    , cid(_cid)
    , uuid(_uuid)
    , is_prefetch(_is_prefetch)  // ADD
  {}

  friend std::ostream &operator<<(std::ostream &os, const MemReq& req) {
    os << "rw=" << req.write << ", ";
    os << "addr=0x" << std::hex << req.addr << std::dec << ", type=" << req.type;
    os << ", tag=0x" << std::hex << req.tag << std::dec << ", cid=" << req.cid;
    if (req.is_prefetch) os << ", prefetch=1";  // ADD
    os << " (#" << req.uuid << ")";
    return os;
  }
};
```

#### 1b: Editing `func_unit.cpp`

We need a way to mark prefetch requests in `LsuUnit::tick()` (in the `/sim/simx/func_unit.cpp` file), so we need to add functionality to our newly added `is_prefetch` flag

```cpp
void LsuUnit::tick() {
    // ...
    
    for (uint32_t iw = 0; iw < ISSUE_WIDTH; ++iw) {
        // ...
        
        bool is_fence = false;
        bool is_write = false;
        bool is_prefetch = false;  // ADD

        auto trace = input.front();
        if (std::get_if<LsuType>(&trace->op_type)) {
            auto lsu_type = std::get<LsuType>(trace->op_type);
            is_fence = (lsu_type == LsuType::FENCE);
            is_write = (lsu_type == LsuType::STORE);
            is_prefetch = (lsu_type == LsuType::PREFETCH);  // ADD
        }
        // ...
        
        if (remain_addrs_ != 0) {
            // setup memory request
            LsuReq lsu_req(NUM_LSU_LANES);
            lsu_req.write = is_write;
            lsu_req.is_prefetch = is_prefetch;  // ADD
            
            // ...
        }
    }
}
```

#### 1c: Editing `cache_sim.cpp`

To mimic an additional bit on the tag, we also add flag bits to the `line_t` structure (in the `/sim/simx/cache_sim.cpp`), specifically one to check if the data was prefetched and the other if it was used. These two flags will assist the counter with tracking

```cpp
struct line_t {
    uint64_t tag;
    uint32_t lru_ctr;
    bool     valid;
    bool     dirty;
    bool     was_prefetched;  // ADD
    bool     was_used;        // ADD

    void reset() {
        valid = false;
        dirty = false;
        was_prefetched = false;  // ADD
        was_used = false;        // ADD
    }
};
```

Afterwards, we also need to update `bank_req_t` with the prefetch flag

```cpp
struct bank_req_t {
    
    // ...
    
    bool     is_prefetch;  // ADD

    bank_req_t() {
        this->reset();
    }

    void reset() {
        type = ReqType::None;
        is_prefetch = false;  // ADD
    }

    friend std::ostream &operator<<(std::ostream &os, const bank_req_t& req) {
        os << "set=" << req.set_id << ", rw=" << req.write;
        os << ", type=" << req.type;
        os << ", addr_tag=0x" << std::hex << req.addr_tag;
        os << ", req_tag=" << req.req_tag;
        os << ", cid=" << std::dec << req.cid;
        if (req.is_prefetch) os << ", prefetch=1";  // ADD
        os << " (#" << req.uuid << ")";
        return os;
    }
};
```

Now that we have the flags set in `cache_sim.cpp`, we want to implement logic into the `processInputs()` function

```cpp
void processInputs() {
	// proces inputs in prioroty order
	do {
			
		// ...

		// second: schedule memory fill
		if (!this->mem_rsp_port.empty()) {
			auto& mem_rsp = mem_rsp_port.front();
			DT(3, this->name() << "-fill-rsp: " << mem_rsp);
			// update MSHR
			auto& entry = mshr_.replay(mem_rsp.tag);
			auto& set   = sets_.at(entry.bank_req.set_id);
			auto& line  = set.lines.at(entry.line_id);
			line.valid  = true;
			line.tag    = entry.bank_req.addr_tag;
			line.was_prefetched = entry.bank_req.is_prefetch;  // ADD
    		line.was_used = false;  // ADD
			mshr_.dequeue(&bank_req);
			--pending_mshr_size_;
			pipe_req_->push(bank_req);
			mem_rsp_port.pop();
			--pending_fill_reqs_;
			break;
		}

		// third: schedule core request
		if (!this->core_req_port.empty()) {
			auto& core_req = core_req_port.front();
			// check MSHR capacity
			if ((!core_req.write || config_.write_back)
			 && (pending_mshr_size_ >= mshr_.capacity())) {
				++perf_stats_.mshr_stalls;
				break;
			}
			++pending_mshr_size_;
			DT(3, this->name() << "-core-req: " << core_req);
			bank_req.type = bank_req_t::Core;
			bank_req.cid = core_req.cid;
			bank_req.uuid = core_req.uuid;
			bank_req.set_id = params_.addr_set_id(core_req.addr);
			bank_req.addr_tag = params_.addr_tag(core_req.addr);
			bank_req.req_tag = core_req.tag;
			bank_req.write = core_req.write;
			bank_req.is_prefetch = core_req.is_prefetch;  // ADD
			pipe_req_->push(bank_req);
			if (core_req.write)
				++perf_stats_.writes;
			else
				++perf_stats_.reads;
			core_req_port.pop();
			break;
		}
	} while (false);
}
```

#### 1d: Editing `types.cpp`

Now we want to propagate `is_prefetch` through `LsuMemAdapter` (in the `/sim/simx/types.cpp` file) so that the counter can see the flag

```cpp
// ...

// process incoming requests
if (!ReqIn.empty()) {
  auto& in_req = ReqIn.front();
  assert(in_req.mask.size() == input_size);
  for (uint32_t i = 0; i < input_size; ++i) {
    if (in_req.mask.test(i)) {
      // build memory request
      MemReq out_req;
      out_req.write = in_req.write;
      out_req.addr  = in_req.addrs.at(i);
      out_req.is_prefetch = in_req.is_prefetch; // ADD
      out_req.type  = get_addr_type(in_req.addrs.at(i));
      out_req.tag   = in_req.tag;
      out_req.cid   = in_req.cid;
      out_req.uuid  = in_req.uuid;
      // send memory request
      ReqOut.at(i).push(out_req, delay_);
      DT(4, this->name() << "-req" << i << ": " << out_req);
    }
  }
  ReqIn.pop();
}

// ...
```

Similarly, we also want to do the same for the `LocalMemSwitch::tick()` function

```cpp
// ...

// process incoming requests
if (!ReqIn.empty()) {
  auto& in_req = ReqIn.front();

  LsuReq out_dc_req(in_req.mask.size());
  out_dc_req.write = in_req.write;
  out_dc_req.tag   = in_req.tag;
  out_dc_req.cid   = in_req.cid;
  out_dc_req.uuid  = in_req.uuid;

  out_dc_req.is_prefetch = in_req.is_prefetch; // ADD

  LsuReq out_lmem_req(out_dc_req);
    
// ...
```

#### 1d: Editing `mem_coalescer.cpp`

In the `MemCoalescer::tick()` function, we also need to propagate through the memory coalescer to ensure the flag is set throughout our structures

```cpp
// ...

// build memory request
LsuReq out_req{output_size_};
out_req.mask = out_mask;
out_req.tag = tag;
out_req.write = in_req.write;
out_req.addrs = out_addrs;
out_req.cid = in_req.cid;
out_req.uuid = in_req.uuid;
  
out_req.is_prefetch = in_req.is_prefetch; // ADD

// ...
```

### Step 2: Adding Counters

We want to add all three prefetch counters into the `PerfStats` structure (in the `/sim/simx/cache_sim.h` file)

```cpp
struct PerfStats {
    uint64_t reads;
    uint64_t writes;
    uint64_t read_misses;
    uint64_t write_misses;
    uint64_t evictions;
    uint64_t bank_stalls;
    uint64_t mshr_stalls;
    uint64_t mem_latency;
    
    uint64_t prefetch_requests;  // ADD
    uint64_t prefetch_unused;    // ADD
    uint64_t prefetch_late;      // ADD

    PerfStats()
        : reads(0)
        , writes(0)
        , read_misses(0)
        , write_misses(0)
        , evictions(0)
        , bank_stalls(0)
        , mshr_stalls(0)
        , mem_latency(0)
        , prefetch_requests(0)   // ADD
        , prefetch_unused(0)     // ADD
        , prefetch_late(0)       // ADD
    {}

    PerfStats& operator+=(const PerfStats& rhs) {
        this->reads += rhs.reads;
        this->writes += rhs.writes;
        this->read_misses += rhs.read_misses;
        this->write_misses += rhs.write_misses;
        this->evictions += rhs.evictions;
        this->bank_stalls += rhs.bank_stalls;
        this->mshr_stalls += rhs.mshr_stalls;
        this->mem_latency += rhs.mem_latency;
        this->prefetch_requests += rhs.prefetch_requests;  // ADD
        this->prefetch_unused += rhs.prefetch_unused;      // ADD
        this->prefetch_late += rhs.prefetch_late;          // ADD
        return *this;
    }
};
```

To implement functionality, we add counter logic in the `processRequests()` function (in the `/sim/simx/cache_sim.cpp` file)

```cpp
void processRequests() {
	    
    //...

    case bank_req_t::Core: {
        int32_t free_line_id = -1;
        int32_t repl_line_id = 0;
        auto& set = sets_.at(bank_req.set_id);
		
        // tag lookup
        int hit_line_id = set.tag_lookup(bank_req.addr_tag, &free_line_id, &repl_line_id);
		
        if (hit_line_id != -1) {
            // Hit handling
            auto& hit_line = set.lines.at(hit_line_id);
		
            // ADD: Mark as used if it was prefetched
            if (hit_line.was_prefetched && bank_req.is_prefetch) {
                hit_line.was_used = true;
            }
			
            if (bank_req.write) {
                // handle write hit
                if (!config_.write_back) {
                    MemReq mem_req;
                    mem_req.addr  = params_.mem_addr(bank_id_, bank_req.set_id, bank_req.addr_tag);
                    mem_req.write = true;
                    mem_req.cid   = bank_req.cid;
                    mem_req.uuid  = bank_req.uuid;
                    this->mem_req_port.push(mem_req);
                    DT(3, this->name() << "-writethrough: " << mem_req);
                } else {
                    hit_line.dirty = true;
                }
            }
			
            // CHANGE: send core response (not for prefetch)
            if (!bank_req.is_prefetch && (!bank_req.write || config_.write_reponse)) {
                MemRsp core_rsp{bank_req.req_tag, bank_req.cid, bank_req.uuid};
                this->core_rsp_port.push(core_rsp);
                DT(3, this->name() << "-core-rsp: " << core_rsp);
            }
            --pending_mshr_size_;
        } else {
            // Miss handling
            if (bank_req.write && !bank_req.is_prefetch) {
                ++perf_stats_.write_misses;
            } else if (!bank_req.is_prefetch) {
                ++perf_stats_.read_misses;
            }
		
            // ADD: Counter 1 - Count unique prefetch requests that miss
            if (bank_req.is_prefetch) {
                ++perf_stats_.prefetch_requests;
            }

            // ADD: Check if there's already a pending MSHR for this address
            auto mshr_pending = mshr_.lookup(bank_req);
		
            // ADD: Counter 3 - Late prefetch (demand arrives while prefetch in MSHR)
            if (!bank_req.is_prefetch && mshr_pending) {
                ++perf_stats_.prefetch_late;
            }

            if (free_line_id == -1 && config_.write_back) {
                // write back dirty line
                auto& repl_line = set.lines.at(repl_line_id);
			
                // ADD: Counter 2 - Unused prefetch (evicting prefetched but unused line)
                if (repl_line.was_prefetched && !repl_line.was_used) {
                    ++perf_stats_.prefetch_unused;
                }
			
                if (repl_line.dirty) {
                    MemReq mem_req;
                    mem_req.addr  = params_.mem_addr(bank_id_, bank_req.set_id, repl_line.tag);
                    mem_req.write = true;
                    mem_req.cid   = bank_req.cid;
                    this->mem_req_port.push(mem_req);
                    DT(3, this->name() << "-writeback: " << mem_req);
                    ++perf_stats_.evictions;
                }
            }

            if (bank_req.write && !config_.write_back) {
                // forward write request to memory

                {
                    MemReq mem_req;
                    mem_req.addr  = params_.mem_addr(bank_id_, bank_req.set_id, bank_req.addr_tag);
                    mem_req.write = true;
                    mem_req.cid   = bank_req.cid;
                    mem_req.uuid  = bank_req.uuid;
                    this->mem_req_port.push(mem_req);
                    DT(3, this->name() << "-writethrough: " << mem_req);
                }
                // CHANGE: send core response
                if (config_.write_reponse && !bank_req.is_prefetch) {
                    MemRsp core_rsp{bank_req.req_tag, bank_req.cid, bank_req.uuid};
                    this->core_rsp_port.push(core_rsp);
                    DT(3, this->name() << "-core-rsp: " << core_rsp);
                }
                --pending_mshr_size_;
            } else {
	            // MSHR lookup
				auto mshr_pending = mshr_.lookup(bank_req);
	            
                // allocate MSHR
                auto mshr_id = mshr_.enqueue(bank_req, (free_line_id != -1) ? free_line_id : repl_line_id);
                DT(3, this->name() << "-mshr-enqueue: " << bank_req);

                // send fill request
                if (!mshr_pending) {
                    MemReq mem_req;
                    mem_req.addr  = params_.mem_addr(bank_id_, bank_req.set_id, bank_req.addr_tag);
                    mem_req.write = false;
                    mem_req.tag   = mshr_id;
                    mem_req.cid   = bank_req.cid;
                    mem_req.uuid  = bank_req.uuid;
                    mem_req.is_prefetch = bank_req.is_prefetch;  // ADD
                    this->mem_req_port.push(mem_req);
                    DT(3, this->name() << "-fill-req: " << mem_req);
                    ++pending_fill_reqs_;
                }
            }
        }
    } break;
    
    // ...
}
```

### Step 3: Printing Results

#### 3a: Editing `VX_types.vh`

In order to print the results, we first need to add three new CSR definitions into `VX_types.vh` (in the `/hw/rtl/` directory)

**Note:** Despite this assignment focusing on SimX (C++), we are editing a `*.vh` file. This file creates a `VX_types.h` file that's in the `/build/hw/` directory (after making the build)

```verilog
`define VX_CSR_MPM_PREFETCH_REQ     12'hB15     // unique prefetch requests
`define VX_CSR_MPM_PREFETCH_REQ_H   12'hB95
`define VX_CSR_MPM_PREFETCH_UNUSED  12'hB16     // unused prefetches
`define VX_CSR_MPM_PREFETCH_UNUSED_H 12'hB96
`define VX_CSR_MPM_PREFETCH_LATE    12'hB17     // late prefetches
`define VX_CSR_MPM_PREFETCH_LATE_H  12'hB97
```

**IMPORTANT:** Because class 2 counters are full, we cannot add these counters within that class, adding these counters into that class will result in errors!. Thus we are adding the counters in class 3.

#### 3b: Editing `utils.cpp`

To have `PERF: …` line at the end of the test, we need to add output logic within the `dcache_enable` if statement (in the `/runtime/stub/utils.cpp` file) with our newly added counters in the 

```cpp
// ...

// PERF: Prefetch counters in class 3
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
fprintf(stream, "PERF: core%d: dcache prefetch requests=%lu\n", core_id, prefetch_requests);
fprintf(stream, "PERF: core%d: dcache prefetch unused=%lu\n", core_id, prefetch_unused);
fprintf(stream, "PERF: core%d: dcache prefetch late=%lu\n", core_id, prefetch_late);

// ...
```

#### 3c: Editing `emulator.cpp`

Because our addresses are extended outside of the CSR address range, we need to expand it from 32 to 64 bits in the `user-defined MPM CSRs` section (in the `/sim/simx/emulator.cpp` directory)

```cpp
// ...

if ((addr >= VX_CSR_MPM_BASE && addr < (VX_CSR_MPM_BASE + 64)) // CHANGE
 || (addr >= VX_CSR_MPM_BASE_H && addr < (VX_CSR_MPM_BASE_H + 64)))
 
// ...
```

Also, we need to add the logic to expose these counters in the CSR in the class 3 case of the performance counters along with the logic to read and expose them:

```cpp
// ...
case VX_DCR_MPM_CLASS_3: {
  // Add your custom counters here for Class 3:
  auto socket_perf = core_->socket()->perf_stats();
          // Add your custom counters here for Class 3:
          switch (addr) {
          CSR_READ_64(VX_CSR_MPM_PREFETCH_REQ, socket_perf.dcache.prefetch_requests);
          CSR_READ_64(VX_CSR_MPM_PREFETCH_UNUSED, socket_perf.dcache.prefetch_unused);
          CSR_READ_64(VX_CSR_MPM_PREFETCH_LATE, socket_perf.dcache.prefetch_late);
          }
}
// ...
```



#### 3d: Editing `vortex.cpp`

Similarly, we need to edit the `mpm_query()` function to support an extended address range (in the `/runtime/simx/vortex.cpp` file)

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

# Test with SimX
./ci/blackbox.sh --driver=simx --cores=1 --app=prefetch --perf=3
```

The expected result is a test passed message and an output of all 3 metric counters, feel free to change `kernel.cpp` with different instruction/data sizes to observe prefetch efficiency
