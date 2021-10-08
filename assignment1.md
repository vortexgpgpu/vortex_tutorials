# Assignment #1

In this assignment, you will be adding a new machine performance monitoring counter to calculate the average number of active threads per cycle during a program kernel execution.
There are already a few performance counters supported in the hardware. You can see the list in /Vortex/hw/rtl/VX_config.vh.
Start by adding the following lines in VX_config.vh to reserve a couple of addresses in the CSR for a new active thread counter:

    `define CSR_MPM_ACTIVE_THREADS      12'hB1E	// active threads
    `define CSR_MPM_ACTIVE_THREADS_H    12'hB9E
To add this new counter to the CSR, you also need to add a couple of lines to /Vortex/hw/rtl/VX_csr_data.sv under the macro "`ifdef PERF_ENABLE":

	    `CSR_MPM_ACTIVE_THREADS     : read_data_r = perf_pipeline_if.active_threads[31:0];
	    `CSR_MPM_ACTIVE_THREADS_H   : read_data_r = 32'(perf_pipeline_if.active_threads[43:32]);
	    
Next, you will add the counter to the /Vortex/hw/rtl/interfaces/VX_perf_pipeline_if.sv interface so it can easily be used in other VX files:

    wire [43:0]     active_threads;
    
You will be using the “CSR_MPM_ACTIVE_THREADS” and “CSR_MPM_ACTIVE_THREADS_H” counter slots to store your computed data. An easy place to calculate the current number of active threads is to use the instruction active thread mask "ibuf_deq_if.tmask" in the issue stage located at /Vortex/hw/rtl/VX_issue.sv. An instruction is issued when both "ibuf_deq_if.valid" and "ibuf_deq_if.ready" are asserted. When an instruction is issued, you will have to count the total active bits in "ibuf_deq_if.tmask" to obtain the count for that cycle. In VX_issue.sv, start by defining a register for the new counter directly under the "`ifdef PERF_ENABLE" macro:

    reg [`PERF_CTR_BITS-1:0] perf_active_threads;

In this same macro, remember to assign this register to the counter we defined earlier in the interface:

        assign perf_pipeline_if.active_threads = perf_active_threads;

Next, the logic for counting the total number of active threads must be written in VX_issue.sv. Once this is done, the active number of threads should be divided by the total number of cycles in /Vortex/driver/common/vx_utils.cpp and printed out. You can start by adding this counter in the function "vx_dump_perf" under the first "#ifdef PERF_ENABLE" macro:

      uint64_t active_threads = 0;

Then, in the next "#ifdef PERF_ENABLE" macro in the same "vx_dump_perf" function, you should add the code to retrieve the counter from the CSR:

    uint64_t active_threads_per_core;
    ret |= vx_csr_get_l(device, core_id, CSR_MPM_ACTIVE_THREADS, CSR_MPM_ACTIVE_THREADS_H, &active_threads_per_core);
    if (num_cores > 1) fprintf(stream, "PERF: core%d: active threads=%ld\n", core_id, active_threads_per_core);
    active_threads += active_threads_per_core;
    
Finally, at the bottom of this same file, you can divide the total number of active threads by the cycle count and print out the active threads per cycle.

To test your change, you will be calling the software demo using the --perf command line argument from the Vortex directory: 

    ./ci/blackbox.sh --cores=4 --app=demo --perf 

The console output should show all the counters, including a line similar to the following line that reports your average active threads per cycle.

    PERF: average active threads=??? 

You can change the program workload to the following values 16, 32, 64, 128: 

    ./ci/blackbox.sh --cores=4 --app=demo --perf --args=”-n16” 
    ./ci/blackbox.sh --cores=4 --app=demo --perf --args=”-n32” 
    ./ci/blackbox.sh --cores=4 --app=demo --perf --args=”-n64” 
    ./ci/blackbox.sh --cores=4 --app=demo --perf --args=”-n128” 

Vortex Source Code Location: 
https://github.com/vortexgpgpu/vortex 
(Links to an external site.)
