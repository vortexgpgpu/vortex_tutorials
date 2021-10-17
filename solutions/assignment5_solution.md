# Solution for Assignment #5: Adding a new software prefetch instruction

**Source code**: [Pull Request #25](https://github.com/vortexgpgpu/vortex/pull/25/files) 

---
## Step 4: Test results

### SimX

``` bash
./ci/blackbox.sh --driver=simx --cores=4 --app=prefetch
```

### RTL

Obtaining the run.log file

``` bash
./ci/blackbox.sh --driver=rtlsim --cores=4 --app=prefetch   --debug
```

Isolating the prefetch requests from run.log

``` bash
grep 'D$0 Rd Req' run.log | grep 'PC=800000b0'
```

``` bash
5357: D$0 Rd Req: req_is_prefetch=1, wid=1, PC=800000b0, tmask=1111, addr={0x1c0, 0x180, 0x140, 0x100}, tag=0, byteen=ffff, type={0x0, 0x0, 0x0, 0x0}, rd=0, is_dup=0
```

Here we see that there is a prefetch request corresponding to the software prefetch instruction whose opcode is `800000b0`.

Isolating the prefetch responses from run.log

``` bash
grep 'D$0 Rsp' run.log | grep 'PC=800000b0'
```

``` bash
5433: D$0 Rsp: rsp_is_prefetch=1, wid=1, PC=800000b0, tmask=0001, tag=0, rd=0, data={0x81e7ae9d, 0x50769aef, 0xd4633919, 0x3f}, is_dup=0
```
---

