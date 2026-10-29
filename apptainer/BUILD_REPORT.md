# Vortex v3.0 Apptainer Image (MICRO 2026): Build Report

Author: Yeri Park. Target: x86_64, CRNCH Rogues Gallery (built on `crush`, Apptainer 1.5.3).
Based on Vortex **v3.0** (tag `v3.0`, commit `7fe19369587c087f902c3e2bc2add612aa910a95`, toolchain revision `v3.0.1`), Ubuntu 22.04.

## 1. Image, definition file, toolchain

| | Path |
|---|---|
| Image | `/localscratch/ypark449/vortex_micro26.sif` (585 MB) |
| Definition file | `apptainer/vortex_micro26.def` (this repository) |
| Toolchain directory (mounted at `/home/tools`) | `/localscratch/ypark449/vortex-tools-v3.0/` (3.7 GB) |

All three are on `crush`'s node-local `/localscratch` (no backup). Proposed final placement, to be created by the RG admins:

```
/projects/tools/x86_64/containers/vortex_micro26.sif
/projects/tools/x86_64/common-tools/vortex-tools-v3.0
```

The image contains only OS packages: Vortex's `ci/install_dependencies.sh --vulkan` set (Vulkan loader, `glslc`, OpenCL headers, cmake, ...), the CUDA 12.1 headers (`cuda-cudart-dev`, `cuda-nvcc`, `cuda-driver-dev`, `libcurand-dev`; no GPU needed), `libtinfo-dev`, `libunwind8`, vim, nano, gtkwave and matplotlib. The Vortex source tree and the toolchain are bind-mounted from the host. `TOOLDIR` is set at run time to whichever of `/opt/vortex-tools` or `/home/tools` is mounted (Vortex's `config.mk` uses `TOOLDIR ?=`, so an exported `TOOLDIR` must match the mount).

## 2. Build the image

Needs only `vortex_micro26.def`, outbound HTTPS (Docker Hub for `ubuntu:22.04`, GitHub, the Ubuntu, LunarG and NVIDIA apt repositories), no root (`--fakeroot`), a few GB of free space. About 12 minutes.

```bash
# on rg-login
srun -p rg-dev -w crush -c 8 -t 02:00:00 bash -c '
  mkdir -p /localscratch/$USER/tmp /localscratch/$USER/cache
  export APPTAINER_TMPDIR=/localscratch/$USER/tmp APPTAINER_CACHEDIR=/localscratch/$USER/cache
  cd <directory containing vortex_micro26.def> &&
  apptainer build --fakeroot --force /localscratch/$USER/vortex_micro26.sif vortex_micro26.def'
```

## 3. Build the toolchain directory (admin, once)

Vortex's own script is run inside the image; about 4 minutes, 3.7 GB. `--tooldir=/home/tools` must be given explicitly because `TOOLDIR` is not set while the directory is still empty.

```bash
D=/localscratch/$USER; mkdir -p $D/vortex-tools-v3.0 /tmp/$USER/vx && cd /tmp/$USER/vx
git clone --branch v3.0 --recursive https://github.com/vortexgpgpu/vortex.git
apptainer exec --fakeroot --cleanenv --writable-tmpfs \
  --bind $PWD/vortex:/home/vortex --bind $D/vortex-tools-v3.0:/home/tools $D/vortex_micro26.sif bash -c '
    cd /home/vortex && mkdir build32 && cd build32 &&
    ../configure --xlen=32 --tooldir=/home/tools && ./ci/toolchain_install.sh --all'
chmod -R a+rX $D/vortex-tools-v3.0
```

Result: `chipstar gem5 libc32 libc64 libcrt32 libcrt64 llvm-vortex mesa-vortex pocl riscv32-gnu-toolchain riscv64-gnu-toolchain sta sv2v verilator yosys`.

## 4. Run (what an attendee does)

```bash
git clone --branch v3.0 --recursive https://github.com/vortexgpgpu/vortex.git /tmp/vortex
apptainer shell --fakeroot --cleanenv --writable-tmpfs \
  --bind /tmp/vortex:/home/vortex \
  --bind /localscratch/ypark449/vortex-tools-v3.0:/home/tools \
  /localscratch/ypark449/vortex_micro26.sif
Apptainer> cd /home/vortex && mkdir build32 && cd build32
Apptainer> ../configure --xlen=32 --tooldir=$TOOLDIR       # TOOLDIR=/home/tools
Apptainer> make -s -j4
Apptainer> ./ci/blackbox.sh --driver=simx --cores=1 --app=sgemm --perf=1
```

`--writable-tmpfs` is only 64 MB on RG, but build output goes to the bound host clone, so it is never filled. Anything larger that a user creates (for example the CuPBoP clone in Assignment 9) must also live in a bound host directory.

On `crush` (16 cores) the first `make -s -j16` takes about 8 minutes.

## 5. Known behaviors

**Assignment 9 (CuPBoP) and a later 32-bit build in the same shell.** CuPBoP's `ci/rg-ci-setup-v3.sh` exports `RISCV_TOOLCHAIN_PATH=$TOOLDIR/riscv64-gnu-toolchain` (the 64-bit build it needs). Vortex's `config.mk` sets `RISCV_TOOLCHAIN_PATH ?= $(TOOLDIR)/riscv$(XLEN)-gnu-toolchain`, so the environment value wins over the XLEN-dependent default. If the same shell then builds a 32-bit test (`build32`), `sw/kernel/Makefile` passes `--gcc-toolchain=` and the sysroot of the riscv64 toolchain to the 32-bit compile, which fails with `fatal error: 'newlib.h' file not found` (or `'string.h' file not found`). Checked by unsetting each exported variable in turn: only `RISCV_TOOLCHAIN_PATH` fixes it. Workaround: run the CuPBoP steps in their own shell or subshell (`( source ci/rg-ci-setup-v3.sh; ... )`), or `unset RISCV_TOOLCHAIN_PATH` afterwards. It is not an image problem.

**`make -j16` on Vortex `master` (Assignment 11).** At commit `50cb17454` a parallel `make -s -j16` once failed in `third_party` (`libramulator-vortex.so` missing, a race between the Ramulator targets); re-running, or a plain `make -s` after cleaning `third_party` (about 9.5 minutes, rc 0), succeeds. `-j4` was used for the successful runs. `v3.0` itself built with `-j16` without problems.

**Packages found missing while testing, now in the `.def`:** `libunwind8` (Mesa's `libvulkan_lvp.so`, Assignment 8), `libtinfo-dev` and `libcurand-dev-12-1` (CuPBoP translators and `curand_mtgp32_kernel.h`, Assignment 9).

## 6. Checks performed

Run as a student would (fresh clone, `configure`, `make`, handout patch with `git apply`, `configure` again, baseline command) in this image with the toolchain above; each assignment 1 to 12 behaved as its text describes (stubs fail where the text says they fail). Assignment 5's baseline prints exactly the numbers in its text (`instrs=24224, cycles=40983`), Assignment 6 prints `41 errors` for the buggy RTL (SimX `1437` instrs / `6134` cycles, rtlsim `1437` / `6059`), and Assignment 11 prints the counters of its text (`rays=3072, hits=428, instrs=143965, cycles=540097`). Mesa in the toolchain is `25.1.0 (git-fc5b07ad81)`, the build Assignment 8 was validated with. Solutions were not implemented.
