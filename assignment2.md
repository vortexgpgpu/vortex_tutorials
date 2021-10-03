#assignment #2

In this assignment, you will study the memory system. 

Since GPUs execute on a wavefront/warp granularity, they will also generate multiple memory requests from the same wavefront/warp. However, often those memory addresses are the same across all threads within the wavefront/warp. 

You will be implementing a counter that will track the number of times there is a warp with all the active threads requesting access to the same memory address. In VX_lsu_unit.v, a signal called req_is_dup is set to high when all the active threads request the same memory address as thread 0. Study closely how this signal is implemented and use it to program the counter. 

You will need to print this counter in the results, for which you must assign the value of this counter to the req_dups wire of the perf_memsys_if interface. You will use the same repo used for assignment 1. 

Additional tasks: 

Explore how the hits and misses in the DCache and ICache are handled and how the counters for dcache/icache reads and misses are programmed. 

Please use the provide template (assignment1-assignment2) for the assignment 2. 
