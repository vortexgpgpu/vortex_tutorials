# Assignment #1

In this assignment, you will be adding a new machine performance monitoring counter to calculate the average number of active threads per cycle during a program kernel execution.
There are already a few performance counters supported in the hardware. You can see the list in [/vortex/hw/rtl/VX_Types.vh](https://github.com/vortexgpgpu/vortex/blob/master/hw/rtl/VX_types.vh#L65).
Start by adding the following lines in VX_Types.vh under the comment "Machine Performance-monitoring counters" to reserve a couple of addresses in the CSR for a new active thread counter:

    `define CSR_MPM_ACTIVE_THREADS      12'hB1E	// active threads
    `define CSR_MPM_ACTIVE_THREADS_H    12'hB9E
To add this new counter to the CSR, you also need to add a couple of lines to [vortex/hw/rtl/core/VX_csr_data.sv](https://github.com/vortexgpgpu/vortex/blob/master/hw/rtl/core/VX_csr_data.sv#L185) under the macro "`ifdef PERF_ENABLE":

	`CSR_MPM_ACTIVE_THREADS     : read_data_r = perf_pipeline_if.active_threads[31:0];
	`CSR_MPM_ACTIVE_THREADS_H   : read_data_r = 32'(perf_pipeline_if.active_threads[`PERF_CTR_BITS-1:32]);
	    
Next, you will add the counter to the [/vortex/hw/rtl/interfaces/VX_pipeline_perf_if.sv](https://github.com/vortexgpgpu/vortex/blob/master/hw/rtl/interfaces/VX_pipeline_perf_if.sv#L20) interface so it can easily be used in other VX files:

    wire [`PERF_CTR_BITS-1:0]     active_threads;

You should also add this new "active_threads" counter as an output and input in the [issue](https://github.com/vortexgpgpu/vortex/blob/master/hw/rtl/interfaces/VX_pipeline_perf_if.sv#L27) and [slave](https://github.com/vortexgpgpu/vortex/blob/master/hw/rtl/interfaces/VX_pipeline_perf_if.sv#L34) modports respectively in this same interface.

You will be using the “CSR_MPM_ACTIVE_THREADS” and “CSR_MPM_ACTIVE_THREADS_H” counter slots to store your computed data. An easy place to calculate the current number of active threads is to use the instruction active thread mask "ibuffer_if.tmask" in the issue stage located at /vortex/hw/rtl/core/VX_issue.sv. An instruction is issued when both "ibuffer_if.valid" and "ibuffer_if.ready" are asserted. When an instruction is issued, you will count the total active bits in "ibuffer_if.tmask" to obtain the count for that cycle. In VX_issue.sv, start by defining a register for the new counter directly under the ["`ifdef PERF_ENABLE" macro](https://github.com/vortexgpgpu/vortex/blob/master/hw/rtl/core/VX_issue.sv#L153):

    reg [`PERF_CTR_BITS-1:0] perf_active_threads;

In this same macro, remember to assign this register to the counter we defined earlier in the interface:

	assign perf_pipeline_if.active_threads = perf_active_threads;

Next, the logic for counting the total number of active threads must be written in VX_issue.sv.

Once this is done, the number of active threads should be divided by the total number of cycles in /vortex/runtime/common/vx_utils.cpp and printed out. You can start by adding this counter in the function "vx_dump_perf" under [the first "#ifdef PERF_ENABLE" macro](https://github.com/vortexgpgpu/vortex/blob/master/runtime/common/utils.cpp#L181):

    uint64_t active_threads = 0;

Then, in [the next "#ifdef PERF_ENABLE" macro](https://github.com/vortexgpgpu/vortex/blob/master/driver/common/vx_utils.cpp#L254) in the same "vx_dump_perf" function, you should add the code to retrieve the counter from the CSR:

    uint64_t active_threads_per_core = get_csr_64(staging_buff.data(), CSR_MPM_ACTIVE_THREADS);
    if (num_cores > 1) fprintf(stream, "PERF: core%d: active threads=%ld\n", core_id, active_threads_per_core);
    active_threads += active_threads_per_core;

    
Finally, at the bottom of this same file, you can divide the total number of active threads by the cycle count and print out the active threads per cycle.

To test your change, you will be calling the software demo using the --perf command line argument from the Vortex directory: 

    ./ci/blackbox.sh --cores=4 --app=demo --perf=1

The console output should show all the counters, including a line similar to the following line that reports your average active threads per cycle.

    PERF: average active threads per cycle=??? 

You can change the program workload to the following values 16, 32, 64, 128: 

    ./ci/blackbox.sh --cores=4 --app=demo --perf=1 --args=”-n16"
    ./ci/blackbox.sh --cores=4 --app=demo --perf=1 --args=”-n32"
    ./ci/blackbox.sh --cores=4 --app=demo --perf=1 --args=”-n64”
    ./ci/blackbox.sh --cores=4 --app=demo --perf=1 --args=”-n128”


Vortex Source Code Location: 
https://github.com/vortexgpgpu/vortex

# What to submit
[1] PERF: average number of active threads per cycle for 16, 32, 64, 128 cases.

[2] Screenshots that show your code changes. Alternatively, you can put your github link. 
