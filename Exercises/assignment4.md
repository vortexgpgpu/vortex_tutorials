# Assignment #4: How to Debug

In this assignment, we will learn how to debug for a hardware prefetching implementation. 

Tasks: compile Vortex using the debug flag and check (1) the prefetch requests are generated correctly (2) the prefetch requests are indeed used or not by comparing them with demand requests. 
 
// Running demo program using rtlsim in debug mode
```
$ ./ci/blackbox.sh --driver=rtlsim --app=demo --debug=1
```
A debug trace run.log is generated in the current directory during the program execution. The trace includes important states of the simulated processor (memory, caches, pipeline, stalls, etc..). A waveform trace trace.vcd is also generated in the current directory during the program execution. You can visualize the waveform trace using any tool that can open VCD files (Modelsim, Quartus, Vivado, etc..). [GTKwave](http://gtkwave.sourceforge.net) is a great open-source scope analyzer that also works with VCD files.
Additional debugging information can be found [here](https://github.com/vortexgpgpu/vortex/blob/master/docs/debugging.md).
 

Example of what information run.log provides/what we should look for:

## Step 1: Run demo
```bash
./ci/blackbox.sh --driver=rtlsim --app=demo --cores=1  --args="-n100" --debug=1
```
## Step 2: 
Open the file `run.log`, and search for load requests.
We can find a following prefetch load request with each original load request. 

For example:
```
        2757: D$0 Rd Req: wid=0, PC=80000544, tmask=0001, addr={0xfffffb30, 0xfffffb30, 0xfffffb30, 0x80001b30}, tag=100000a880, byteen=ffff, rd=14, is_dup=1
        ...
        2759: D$0 Rd Req: wid=0, PC=80000544, tmask=0001, addr={0xfffffb34, 0xfffffb34, 0xfffffb34, 0x80001b34}, tag=100000a881, byteen=ffff, rd=14, is_dup=1


        3789: D$0 Rd Req: wid=0, PC=80000454, tmask=0001, addr={0xfefff404, 0xfefff804, 0xfefffc04, 0xfefffff4}, tag=1000008a83, byteen=ffff, rd=9, is_dup=1
        ...
        3791: D$0 Rd Req: wid=0, PC=80000454, tmask=0001, addr={0xfefff408, 0xfefff808, 0xfefffc08, 0xfefffff8}, tag=1000008a81, byteen=ffff, rd=9, is_dup=1
```
From the `addr`, we can see the prefetch request load exactly original addr+4.


 
Modify the $write print statements to include aditional information.

Modify debug statements to indicate “is_pref” in $write statement in VX_lsu_unit.sv. 

Add a tag in the response to indicate the cache hit or miss and print out the information.
 
