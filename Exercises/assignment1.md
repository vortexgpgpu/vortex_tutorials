# Assignment #1: Warp Efficiency Performance Counter (SimX)

In this assignment, you will add two new machine performance monitoring (MPM) counters to the SimX cycle-level simulator to calculate the GPU **Warp Efficiency** after a kernel execution. These two counters, `total_issued_warps` and `total_active_threads`, will allow you to compute warp efficiency by dividing the number of active threads by the number of times a warp was issued for execution in the GPU pipeline.

The Warp Efficiency can be computed as:

```math
\text{Warp Efficiency} = \frac{\text{total\_active\_threads}}{\text{total\_issued\_warps} \times \text{warp\_size}} \times 100
```

Vortex already supports a few performance counters, and you can find the list in the file [/vortex/hw/rtl/VX_types.vh](https://github.com/vortexgpgpu/vortex/blob/master/hw/rtl/VX_types.vh).
This Verilog header file is also used to describe the CSR registers for SimX.
You will be adding two new counters for `total_issued_warps` and `total_active_threads`.

### Step 1: Reserve CSR Addresses for the New Counters

Start by reserving addresses in the CSR for the new counters. In `VX_types.vh`, under the "Machine Performance-monitoring memory counters (class 3)" section, add the following lines:

```verilog
`define VX_CSR_MPM_TOTAL_ISSUED_WARPS     12'hB03
`define VX_CSR_MPM_TOTAL_ISSUED_WARPS_H   12'hB83
`define VX_CSR_MPM_TOTAL_ACTIVE_THREADS   12'hB04
`define VX_CSR_MPM_TOTAL_ACTIVE_THREADS_H 12'hB84
```

You will also need to add the definition next to the other class definitions near the top:

```verilog
`define VX_DCR_MPM_CLASS_3              3
```

Note: Similar to VX_config.vh, VX_types.vh is converted to VX_config.h and VX_types.h C++ headers respectively during the build process of software components.
You can directly force the generation/update of VX_config.h and VX_types.h by running:
```bash
make -C hw
```

### Step 2: Register the Counters CSRs

Next, you need to add logic to expose these counters in the CSR. In [emulator.cpp](https://github.com/vortexgpgpu/vortex/blob/master/sim/simx/emulator.cpp), add the new case for the new class of performance counters, along with the logic to read and expose them:

```c++
case VX_DCR_MPM_CLASS_3: {
  // Add your custom counters here for Class 3:
  CSR_READ_64(VX_CSR_MPM_TOTAL_ISSUED_WARPS, core_perf.total_issued_warps);
  CSR_READ_64(VX_CSR_MPM_TOTAL_ACTIVE_THREADS, core_perf.total_active_threads);
} break;
```

### Step 3: Update the Performance Interface in core.h

Modify the performance structure `PerfStats` in [core.h](https://github.com/vortexgpgpu/vortex/blob/master/sim/simx/core.h) to include the new counters:

```c++
struct PerfStats {
  /***/
  uint64_t total_issued_warps;
  uint64_t total_active_threads;
  PerfStats()
    /***/
    , total_issued_warps(0)
    , total_active_threads(0)
  {}
};
```

### Step 4: Implement Logic for issue_warps and total_active_threads

You will now implement the logic for tracking `total_issued_warps` and `total_active_threads` in the `core.cpp` file.

In `Core::schedule()`, add the following lines

```c++
// track active threads
perf_stats_.total_issued_warps += 1;
perf_stats_.total_active_threads += trace->tmask.count();
```

### Step 5: Expose the Counters in the Runtime

In the `vx_dump_perf` function in [`vortex/runtime/stub/vx_utils.cpp`](https://github.com/vortexgpgpu/vortex/blob/master/runtime/stub/vx_utils.cpp#L216), retrieve the values for `total_issued_warps` and `total_active_threads` and use them to calculate warp efficiency.

In `vx_utils.cpp`, add the following code to fetch the values from the CSR and calculate warp efficiency:

At the end of the other counter declarations in `vx_dump_perf`, add:
```cpp
// PERF: CLASS_3
uint64_t total_issued_warps = 0;
uint64_t total_active_threads = 0;
```

Then, add a new case for VX_DCR_MPM_CLASS_3 to calculate and print per-core Warp Efficiency in [`vortex/runtime/stub/vx_utils.cpp`](https://github.com/vortexgpgpu/vortex/blob/master/runtime/stub/vx_utils.cpp#L550):
```cpp
    case VX_DCR_MPM_CLASS_3:
    {
      uint64_t threads_per_warp;
      CHECK_ERR(vx_dev_caps(hdevice, VX_CAPS_NUM_THREADS, &threads_per_warp), {
        return err;
      });
      // Retrieve total_issued_warps and total_active_threads for each core

      // Query total_issued_warps for the core
      uint64_t total_issued_warps_per_core;
      CHECK_ERR(vx_mpm_query(hdevice, VX_CSR_MPM_TOTAL_ISSUED_WARPS, core_id, &total_issued_warps_per_core), {
        return err;
      });

      // Query total_active_threads for the core
      uint64_t total_active_threads_per_core;
      CHECK_ERR(vx_mpm_query(hdevice, VX_CSR_MPM_TOTAL_ACTIVE_THREADS, core_id, &total_active_threads_per_core), {
        return err;
      });

      // Print total_issued_warps and total_active_threads
      if (num_cores > 1) {
        // Calculate and print warp efficiency
        int warp_efficiency = calcAvgPercent(total_active_threads_per_core, total_issued_warps_per_core * threads_per_warp);
        fprintf(stream, "PERF: core%d: Warp Efficiency=%d%%\n", core_id, warp_efficiency);
      }

      // Accumulate totals for all cores
      total_issued_warps += total_issued_warps_per_core;
      total_active_threads += total_active_threads_per_core;
    }
    break;
```

and add the new case to calculate and print the total average Warp Efficiency of the GPU in [`vortex/runtime/stub/vx_utils.cpp`](https://github.com/vortexgpgpu/vortex/blob/master/runtime/stub/vx_utils.cpp#L630):
```cpp
case VX_DCR_MPM_CLASS_3: {
    uint64_t threads_per_warp;
    CHECK_ERR(vx_dev_caps(hdevice, VX_CAPS_NUM_THREADS, &threads_per_warp), {
      return err;
    });
    // Calculate and print warp efficiency
    int warp_efficiency = calcAvgPercent(total_active_threads, total_issued_warps * threads_per_warp);
    fprintf(stream, "PERF: Warp Efficiency=%d%%\n", warp_efficiency);
  }
```

In this code, `vx_mpm_query` retrieves the counters from the hardware, and then warp efficiency is calculated by dividing `total_active_threads` by the product of `total_issued_warps` and `threads_per_warp`. The results are printed to the output stream for performance analysis.

### Step 6: Testing

To test your changes, you can run the software demo using the `--perf=3` command line argument. This will display your new `total_issued_warps` and `total_active_threads` counters. Be sure to run `../configure` after making changes to the vortex source in order for the changes to be reflected in the `build` directory.

```bash
./ci/blackbox.sh --cores=4 --app=demo --driver=rtlsim --perf=3
```

You can run the demo application with a different input size to observe how the Warp Efficiency changes under various workloads:

```bash
./ci/blackbox.sh --cores=4 --app=demo --perf=3 --driver=rtlsim --args="-n16"
./ci/blackbox.sh --cores=4 --app=demo --perf=3 --driver=rtlsim --args="-n32"
./ci/blackbox.sh --cores=4 --app=demo --perf=3 --driver=rtlsim --args="-n64"
./ci/blackbox.sh --cores=4 --app=demo --perf=3 --driver=rtlsim --args="-n128"
```