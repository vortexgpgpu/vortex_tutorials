## Assignment #6: Adding Performance Counters to Test Vortex's Software Prefetcher

This assignment is an extension of Assignments #1 and #5. It is divided into two parts. The first part involves extending the tag in the cache to include a prefetch bit. The second involves adding three performance counters to measure the following metrics: 
1. Number of unique prefetch requests to main memory.
2. Number of unused prefetched blocks.
3. Number of late prefetches.

All of these counters should be implemented in `VX_bank.sv`.

---

## Part 1: Extending the cache tag:

You will need to extend the metadata tag in the bank to incorporate an additional prefetch bit. Keep in mind that the metadata tag is not the same as the line tag. 

### Hints

- The last two bits of `core_req_tag` are truncated before reaching `VX_bank.sv`. Keep this in mind while adding the prefetch bit to the tag in the `VX_lsu_unit.sv`.
- To verify that your implementation is correct, add the prefetch bit to the debug header in `VX_bank.sv`.

---

## Part 2: 

### 2a: Counter for the number of unique prefetch requests to memory:

The prefetch kernel that you used for Assignment 5 generates multiple prefetch requests to the same address. A unique prefetch request is the first request generated for that address that misses in the cache and goes to main memory. Any subsequent requests to the same address result in a cache hit.

### Hints
- Use the `mreq_push` signal in `VX_bank.sv`.

---

### 2b: Counter for the number of unused prefetched blocks:

- In part 1 of this assignment, you added a prefetch bit to the `core_req_tag` to indictae whether an ***instruction was a software prefetch***. Now, you need to add this bit to the tag store in VX_tag_access.sv to indicate whether a ***block was brought in by a prefetch request***.
- You need to add a new data structure in stage 1 of the cache pipeline (the same stage as the data access) to store information about whether a cache block has been used or not. Look at `VX_tag_access.sv` for an idea of how this can be done. This information is universal and is applicable for every cache block. 
- The first point comes into picture since you want to know whether a ***prefetched block*** has been used or not.
- An important point to note is that we know whether a block has been used/unused only during a ***fill operation*** since that is when the block is evicted from the cache.

---

### 2c: Counter for the number of late prefetches:

- A late prefetch is when there is a prefetch request for a particular address pending in the MSHR, and a there is a demand request for the same address.
- You want to know whether an instruction in the MSHR is a prefetch instruction. For this, you will need to add a data structure in the MSHR to hold the prefetch bit.

### Hints
- Look at how `addr_table` is implemented to get an idea of how to add a prefetch table.
- Look at how `addr_matches` is implemented to get an idea of how to implement the late prefetch counter.

---

## Verifying Your Results:

You can verify your results by running:

``` bash
./ci/blackbox.sh --driver=rtlsim --cores=1 --app=unused_late_prefetch --perf
```
\# of unused prefetched blocks = 2 \
\# of late prefetches = 1