# Assignment #1: Warp Efficiency Performance Counter

In this assignment, you will add two new machine performance monitoring counters to track **warp efficiency** during program kernel execution. These two counters, `fire_count` and `active_thread_count`, will allow you to compute warp efficiency by dividing the number of active threads by the number of times a warp is issued.

Warp efficiency can be computed as:

$$
\text{Warp Efficiency} = \frac{\text{active\_thread\_count}}{\text{fire\_count} \times \text{warp\_size}}
$$

Vortex already supports a few performance counters, and you can find the list in the file [/vortex/hw/rtl/VX_types.vh](https://github.com/vortexgpgpu/vortex/blob/master/hw/rtl/VX_types.vh). You will be adding two new counters for `fire_count` and `active_thread_count`.

### Step 1: Reserve CSR Addresses for the New Counters

Start by reserving addresses in the CSR for the new counters. In `VX_types.vh`, under the "Machine Performance-monitoring memory counters (class 3)" section, add the following lines:

```verilog
`define VX_CSR_MPM_FIRE_COUNT            12'hB03    // fire count
`define VX_CSR_MPM_FIRE_COUNT_H          12'hB83
`define VX_CSR_MPM_ACTIVE_THREAD_COUNT   12'hB04    // active thread count
`define VX_CSR_MPM_ACTIVE_THREAD_COUNT_H 12'hB84
```

You will also need to add the definition next to the other class definitions near the top:

```verilog
`define VX_DCR_MPM_CLASS_3              3
```

### Step 2: Add the Counters to the CSR

Next, you need to add logic to expose these counters in the CSR. In [VX_csr_data.sv](https://github.com/vortexgpgpu/vortex/blob/master/hw/rtl/core/VX_csr_data.sv#L276), add the new case for the new class of performance counters, along with the logic to read and expose them:

```verilog
`VX_DCR_MPM_CLASS_3: begin
    case (read_addr)
    // Add your custom counters here for Class 3:
    `CSR_READ_64(`VX_CSR_MPM_FIRE_COUNT, read_data_ro_w, pipeline_perf_if.sched.fire_count);
    `CSR_READ_64(`VX_CSR_MPM_ACTIVE_THREAD_COUNT, read_data_ro_w, pipeline_perf_if.sched.active_thread_count);
    default:;
    endcase
end
```

### Step 3: Update the Performance Interface in VX_gpu_pkg.sv

Modify the performance structure `sched_perf_t` in [VX_gpu_pkg.sv](https://github.com/vortexgpgpu/vortex/blob/master/hw/rtl/VX_gpu_pkg.sv) to include the new counters:

```verilog
typedef struct packed {
    logic [`PERF_CTR_BITS-1:0] idles;
    logic [`PERF_CTR_BITS-1:0] stalls;
    logic [`PERF_CTR_BITS-1:0] fire_count;
    logic [`PERF_CTR_BITS-1:0] active_thread_count;
} sched_perf_t;
```

### Step 4: Implement Logic for Fire Count and Active Thread Count

You will now implement the logic for tracking `fire_count` and `active_thread_count` in the `VX_schedule.sv` file.

#### In `VX_schedule.sv`, add the following registers under the bottom `ifdef PERF_ENABLE`:

```verilog
reg [`PERF_CTR_BITS-1:0] perf_fire_count;
reg [`PERF_CTR_BITS-1:0] perf_active_thread_count;
```

#### In the `always @(posedge clk)` block (inside the same `ifdef PERF_ENABLE`), first add the logic to reset our counter when reset signal is asserted:

```verilog
perf_fire_count <= 0;
perf_active_thread_count <= 0;
```

#### Also add the logic to increment these counters when a warp is fired in the else block (`schedule_if_fire`):

```verilog
if (schedule_if_fire) begin
    perf_fire_count <= perf_fire_count + 1;
    perf_active_thread_count <= perf_active_thread_count + $countones(schedule_if.data.tmask);
end
```

#### Assign these values to the performance interface after the `always @(posedge clk)` block:

```verilog
assign sched_perf.fire_count = perf_fire_count;
assign sched_perf.active_thread_count = perf_active_thread_count;
```

### Step 5: Expose the Counters in the Runtime

In the `vx_dump_perf` function in [`vortex/runtime/stub/vx_utils.cpp`](https://github.com/vortexgpgpu/vortex/blob/master/runtime/stub/vx_utils.cpp#L216), retrieve the values for `fire_count` and `active_thread_count` and use them to calculate warp efficiency.

#### In `vx_utils.cpp`, add the following code to fetch the values from the CSR and calculate warp efficiency:

#### At the end of the other counter declarations in `vx_dump_perf`, add:
```cpp
// PERF: CLASS_3
uint64_t fire_count = 0;
uint64_t active_thread_count = 0;
```

#### Then, add a new case for VX_DCR_MPM_CLASS_3 in [`vortex/runtime/stub/vx_utils.cpp`](https://github.com/vortexgpgpu/vortex/blob/master/runtime/stub/vx_utils.cpp#L550):
```cpp
    case VX_DCR_MPM_CLASS_3:
    {
      uint64_t threads_per_warp;
      CHECK_ERR(vx_dev_caps(hdevice, VX_CAPS_NUM_THREADS, &threads_per_warp), {
        return err;
      });
      // Retrieve fire_count and active_thread_count for each core

      // Query fire_count for the core
      uint64_t fire_count_per_core;
      CHECK_ERR(vx_mpm_query(hdevice, VX_CSR_MPM_FIRE_COUNT, core_id, &fire_count_per_core), {
        return err;
      });

      // Query active_thread_count for the core
      uint64_t active_thread_count_per_core;
      CHECK_ERR(vx_mpm_query(hdevice, VX_CSR_MPM_ACTIVE_THREAD_COUNT, core_id, &active_thread_count_per_core), {
        return err;
      });

      // Print the fire count and active thread count
      if (num_cores > 1)
      {
        fprintf(stream, "PERF: core%d: fire_count=%ld, active_thread_count=%ld\n", core_id, fire_count_per_core, active_thread_count_per_core);
      }

      // Accumulate totals for all cores
      fire_count += fire_count_per_core;
      active_thread_count += active_thread_count_per_core;
    }
    break;
```

and add the new case in the printing section also in [`vortex/runtime/stub/vx_utils.cpp`](https://github.com/vortexgpgpu/vortex/blob/master/runtime/stub/vx_utils.cpp#L630):
```cpp
case VX_DCR_MPM_CLASS_3: {
    uint64_t threads_per_warp;
    CHECK_ERR(vx_dev_caps(hdevice, VX_CAPS_NUM_THREADS, &threads_per_warp), {
      return err;
    });
    // Calculate and print warp efficiency
    double warp_efficiency = 0.0;
    if (fire_count > 0)
    {
      warp_efficiency = (double)active_thread_count / (fire_count * threads_per_warp);
    }
    fprintf(stream, "PERF: fire_count=%ld, active_thread_count=%ld, Warp Efficiency=%f\n", fire_count, active_thread_count, warp_efficiency);
  }
```

In this code, `vx_mpm_query` retrieves the counters from the hardware, and then warp efficiency is calculated by dividing `active_thread_count` by the product of `fire_count` and `threads_per_warp`. The results are printed to the output stream for performance analysis.



### Step 6: Testing

To test your changes, you can run the software demo using the `--perf=3` command line argument. This will display your new `fire_count` and `active_thread_count` counters. Be sure to run `../configure` after making changes to the vortex source in order for the changes to be reflected in the `build` directory.

```bash
./ci/blackbox.sh --cores=4 --app=demo --driver=rtlsim --perf=3
```

You can run the demo with different program workloads to observe how fire count and active thread count behave under various conditions:

```bash
./ci/blackbox.sh --cores=4 --app=demo --perf=3 --driver=rtlsim --args="-n16"
./ci/blackbox.sh --cores=4 --app=demo --perf=3 --driver=rtlsim --args="-n32"
./ci/blackbox.sh --cores=4 --app=demo --perf=3 --driver=rtlsim --args="-n64"
./ci/blackbox.sh --cores=4 --app=demo --perf=3 --driver=rtlsim --args="-n128"
```

### Submission

[1] Console output showing fire count, active thread count, and warp efficiency for 16, 32, 64, and 128 cases.  
[2] Screenshots that show your code changes, or alternatively, a GitHub link.
