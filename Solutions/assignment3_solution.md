# Solution for Assignment #3:How to add a HW prefetcher

## Download and execute the solution:

**Source code of the solution: [Pull Request #22](https://github.com/vortexgpgpu/vortex/pull/22)**

```bash
git clone  --recursive https://github.com/vortexgpgpu/vortex.git
# Assignment3 solution is the #22 Pull Request in Vortex repo
git fetch origin pull/22/head:A3_solution
git checkout A3_solution
make
# execute the demo
./ci/blackbox.sh --cores=4 --app=demo --perf --debug
```

## Overview of the solution:

### Step 1: Insert addr+4 into `req_pipe_reg` for pre_fetch load.

For background knowledge of `handshake`, please see this [link](http://fpgacpu.ca/fpga/handshake.html).
Without prefetch, a whole process of a normal load request is as following:

1. VX_issue provides `full_addr` and set `valid bit` to 1. VX_issue will keep holding `full_addr` until handshake has done.
2. VX_lsu_unit will set `ready bit` to 1 as long as it's ready to execute new instruction.
3. At the cycle when both `valid bit` and `ready bit` are 1, handshake is done, VX_issue will move to next instructions, and VX_lsu_unit accepts the `full_addr`, store this address into `req_pipe_reg`, and executes load/store accordingly.

When there is a prefetch, after the handshake has done, we have to provide a new request to VX_lsu_unit for the prefetch and insert it into `req_pipe_reg`. For detailed information, please see [source code](https://github.com/vortexgpgpu/vortex/pull/22/files#diff-e7c7dffbfe7b26e92b9b1675965b8920f4acaf6c337f1a53d837738231898465R57).

### Step 2: Add prefetch information into metadata.

This step is necessary: we have to record whether a load request is prefetch. If it is, when the corresponding respond comes back, `LRU` do not need to do anything but just ignore it. On the other hand, if a respond of a normal load returns, `LRU` has to hold it until it has been fetched by consumers We insert extra information for each load request, to record whether this is a prefetch load. For detailed information, please see [source code](https://github.com/vortexgpgpu/vortex/pull/22/files#diff-e7c7dffbfe7b26e92b9b1675965b8920f4acaf6c337f1a53d837738231898465R132).

## NOTE

Although the overview is clear, there are some details needed to be concerned:

- How to solve the conflict between prefetch and the next load instruction?
  As descirbed before, normal load instruction and prefetch all want to insert a new address into `req_pipe_reg`. What if they want to insert at the same time?
- How to drop the return value of prefetch load? For the normal load, after the `LSU` got the data from cache/memory, it stalls until the data been taken. However, for prefetch, there will never be a consumer taking the data. In this situation, there will be deadblock.

## Experiments

1. Execute Vortex and get `run.log` file

```bash
./ci/blackbox.sh --cores=4 --app=demo --perf --debug
```

2. Collect only Load Requests information

```bash
grep 'D$0 Rd Req: ' run.log
```

As you may find in debug file, for each normal load request ('is_prefetch=0'), there is always a prefetch load request following behind, with addr+4.

```
71429: D$0 Rd Req: ... addr={0x433c, 0x423c, 0x413c, 0x403c}, is_prefetch=0
71453: D$0 Rd Req: ... addr={0x4340, 0x4240, 0x4140, 0x4040}, is_prefetch=1
```
