# Assignment #2

In this assignment, you will study the memory system. 

Since GPUs execute on a wavefront/warp granularity, they will also generate multiple memory requests from the same wavefront/warp. However, often those memory addresses are the same across all threads within the wavefront/warp. 

You will be implementing a counter that will track the number of times there is a warp with all the active threads requesting access to the same memory address. The process for creating the counter in the CSR and printing out out the result in the driver is the same as in Assignment #1, but the file we are particularly interested in modifying, VX_lsu_unit.sv, does not include the performance counter interface. For this assignment, the most appropriate interface is located at /vortex/hw/rtl/interfaces/VX_perf_memsys_if.sv. Add access to this interface by adding the following lines in [the I/O list of "module VX_lsu_unit"](https://github.com/vortexgpgpu/vortex/blob/73d249fc56a003239fecc85783d0c49f3d3113b4/hw/rtl/VX_lsu_unit.sv#L15):

    `ifdef PERF_ENABLE
    VX_perf_memsys_if     perf_memsys_if,
    `endif

In VX_lsu_unit.sv, a signal called req_is_dup is set to high when all the active threads request the same memory address as thread 0. Study closely how this signal is implemented and use it to update the counter. 

You will need to print this counter in the results, for which you must assign the value of this counter to a wire in the perf_memsys_if interface linked to the CSR, then modify the driver code at /vortex/driver/common/vx_utils.cpp, similar to Assignment #1.

# Additional tasks: 

Explore how the hits and misses in the D-cache and I-cache are handled and how the counters for D-cache/I-cache reads and misses are programmed.
