# Assignment 9: CUDA on Vortex with CuPBoP — Add `normcdff()`

> Targets Vortex release [v3.0](https://github.com/vortexgpgpu/vortex/releases/tag/v3.0).

## Background

[CuPBoP](https://github.com/cupbop/CuPBoP_Vortex) runs **unmodified CUDA source code** on
Vortex. Clang compiles the CUDA kernel to LLVM IR (`--cuda-device-only -nocudalib`), CuPBoP's
*kernel translator* rewrites the IR so that it runs on Vortex, and its *host translator* and
runtime replace the CUDA runtime API (`cudaMalloc`, `cudaMemcpy`, kernel launches) with calls to
the Vortex runtime.

CUDA device math functions such as `expf`, `erfcf` or `fmaf` reach the IR as calls to NVIDIA's
`libdevice` functions (`__nv_expf`, `__nv_erfcf`, `__nv_fmaf`, …). `libdevice` is NVIDIA bitcode
and is never linked for Vortex, so CuPBoP provides its own implementation of every `__nv_*`
function a kernel can call. A missing one shows up as an undefined symbol when the kernel is
linked.

In this assignment you add one missing function, **`normcdff(x)`**, the standard normal
cumulative distribution function:

```math
\Phi(x) = P(X \le x),\ X \sim \mathcal{N}(0,1) = \tfrac{1}{2}\,\mathrm{erfc}\!\left(-\tfrac{x}{\sqrt{2}}\right)
```

It is used in option pricing (Black–Scholes), GELU activations and statistics kernels.

You will touch the three places every CuPBoP math function lives:

| Layer | File | Role |
|---|---|---|
| Kernel translator | `compilation/KernelTranslation/src/tool.cpp` | list of `__nv_*` calls whose bodies are removed from the IR |
| Device runtime header | `runtime/include/cudaKernelImpl.h` | declaration seen by the translated kernel |
| Device runtime | `runtime/src/vortex/kernel/cudaKernelImpl.cpp` | the implementation compiled for Vortex |

## Setup

You need the Vortex checkout and toolchain from the main setup (`toolchain_install.sh --all`),
CMake ≥ 3.10, and the **CUDA headers** (any CUDA toolkit ≥ 11.7; no NVIDIA GPU and no
NVPTX-enabled LLVM are needed — CuPBoP uses the Vortex LLVM from your `$TOOLDIR`).

CuPBoP for Vortex 3.0 is developed and tested on a **64-bit** Vortex (XLEN 64), so this
assignment uses its own 64-bit build directory next to your `build32`. `toolchain_install.sh --all`
already installed the 64-bit toolchain pieces (`riscv64-gnu-toolchain`, `libc64`, `libcrt64`).

### 1. CuPBoP

```bash
git clone -b vortex3.0 https://github.com/cupbop/CuPBoP_Vortex.git $HOME/CuPBoP_Vortex
cd $HOME/CuPBoP_Vortex
git checkout d289d36      # the commit this assignment was validated on
git apply $TUTORIAL/Exercises/patches/a9_test_fmaf.patch
git apply $TUTORIAL/Exercises/patches/a9_test_normcdff.patch
```

`$TUTORIAL` is your checkout of this tutorial repository. The two patches only add the test
programs used below; CuPBoP itself is used as is.

### 2. Environment and a SimX build for CUDA

CuPBoP ships the environment its own CI uses. Point it at your Vortex checkout and toolchain and
source it from the CuPBoP root:

```bash
export VORTEX_HOME=<your Vortex v3.0 checkout> TOOLDIR=<your toolchain dir>
export CUDA_PATH=/usr/local/cuda     # your CUDA toolkit root (this is the script's default)
cd $HOME/CuPBoP_Vortex && source ci/rg-ci-setup-v3.sh
cupbop_v3_ensure_simx $VORTEX_PATH "$VORTEX_CONFIGS"
```

This configures `$VORTEX_HOME/build64_cupbop` (`--xlen=64`) and builds SimX with CuPBoP's
configuration: 4 cores × 16 warps × 32 threads, L2 cache, and the A and Zacas extensions. Each
setting is required, not tuning:

- Vortex runs a CUDA block on one core, so `blockDim ≤ warps × threads`: the default 4 × 4 core
  rejects the 256- and 512-thread blocks CUDA programs use.
- CUDA atomics need the A extension (off by default in v3.0), and `atomicCAS` needs Zacas: with
  it, `atomicCAS` is one `amocas.w`/`amocas.d` instruction; without it, it becomes an `lr`/`sc`
  retry loop, and lanes of one warp retrying on the same cache line livelock in SimX v3.0 (one
  lane's `sc` always clears the other lanes' reservations).
- Atomics from different cores only meet at a shared cache level, hence the L2.

### 3. Build the translators and the runtime

```bash
XCFG=$(python3 $VORTEX_HOME/ci/gen_config.py --config=$VORTEX_HOME/VX_config.toml \
       --cflags="$VORTEX_CONFIGS -DVX_CFG_XLEN=64")
mkdir -p build && cd build
cmake .. -DLLVM_CONFIG_PATH=$LLVM_CONFIG_PATH -DCMAKE_BUILD_TYPE=Release -DCMAKE_CXX_FLAGS="$XCFG"
make -j4 kernelTranslator hostTranslator vortexRuntime ThreadPool
```

### 4. Smoke test

```bash
cd $CuPBoP_PATH/examples/vecadd
make ci CUDA_GPU_ARCH=sm_80
```

The run ends with `Test PASSED` and writes the Vortex performance counters to
`Perf_counter_4C_16W_32T_SCHE_2_LOCAL_MEM_1.txt`.

Two host-specific options you may need on every `make` of an example:

- `CUDA_GPU_ARCH=sm_80` — CUDA < 11.8 does not know the default `sm_90`.
- `EXTRA_CLANG_FLAGS=--gcc-install-dir=/usr/lib/gcc/x86_64-linux-gnu/<N>` — if Clang picks a GCC
  version whose `libstdc++` headers are not installed (error: `'cmath' file not found` or similar),
  point it at the GCC version that has them.

After changing `SCHEDULE`/`LOCALMEM` or the device runtime, run `make clean` in the example first.

## Part A: Add `normcdff()`

### Step 0: See how an existing function is wired — `fmaf`

`fmaf(a, b, c)` computes `a*b + c` with a **single** rounding. CuPBoP already supports it:

```bash
grep -n "__nv_fmaf(" $CuPBoP_PATH/runtime/src/vortex/kernel/nv_libdevice_compat.cpp
cd $CuPBoP_PATH/examples/test_fmaf && make ci CUDA_GPU_ARCH=sm_80
```

The test checks 1024 results bit-exactly against the host and runs a probe that only a true fused
multiply-add gets right:

```
probe: fmaf((1+2^-12)^2, -(1+2^-11)) = 0x1p-24 (expected 0x1p-24)
PASSED!
```

With separate multiply and add, `(1+2^-12)^2` would be rounded to float first and the probe would
return 0. Vortex's FPU implements `fmadd.s`, so the device result is exact.

### Step 1: Reproduce the failure

`examples/test_normcdff/test_normcdff.cu` computes `normcdff(x)` for 1024 points on `[-8, 8]` and
checks them against `0.5 * erfc(-x / sqrt(2))` evaluated in double on the host.

```bash
cd $CuPBoP_PATH/examples/test_normcdff
make build CUDA_GPU_ARCH=sm_80
```

The kernel link fails:

```
undefined reference to `__nv_normcdff'
```

Look at the IR the kernel translator produced:

```bash
grep normcdff kernel.ll
```

You will find only a declaration, `declare … @__nv_normcdff(float)`: the call is there, the
implementation is not.

### Step 2: Kernel translator — `tool.cpp`

Open `compilation/KernelTranslation/src/tool.cpp` and find `replace_built_in_function()`
(line 635). Around line 1150 a long `if (func_name == "__nv_…" || …)` chain lists the `__nv_*`
functions whose IR body is deleted (`deleteBody()`) so that the call binds to CuPBoP's runtime
implementation instead. Add `"__nv_normcdff"` to that list, then rebuild the translator:

```bash
cd $CuPBoP_PATH/build && make -j4 kernelTranslator
```

> In the v3.0 flow (`-nocudalib`) libdevice is never linked, so the IR already contains only a
> declaration and this step changes nothing for this test. It matters for the CuPBoP flows that
> link libdevice bitcode, and keeps `normcdff` consistent with every other function in the list.
> Question 1 asks you to verify this.

### Step 3: Device runtime — declaration and implementation

In `runtime/include/cudaKernelImpl.h`, add the declaration inside the `extern "C" {` block that
starts at line 12, next to the other float functions (e.g. after `__nv_powf`, line 22):

```cpp
float __nv_normcdff(float);
```

In `runtime/src/vortex/kernel/cudaKernelImpl.cpp`, implement it after `__nv_erfcf` (line 29),
using the identity from the Background section. Follow the style of the neighbouring functions
(`__attribute__((always_inline))`). Use `erfcf` rather than `1 + erff`; Question 2 explains why.

### Step 4: Verify

```bash
cd $CuPBoP_PATH/build && make -j4 vortexRuntime
cd $CuPBoP_PATH/examples/test_normcdff
make clean && make ci CUDA_GPU_ARCH=sm_80
```

## Expected results

Before Step 3, `make build` stops with `undefined reference to '__nv_normcdff'`. After it:

```
normcdff(-8.0000) = 0.0000000
normcdff(-4.0117) = 0.0000301
normcdff(-0.0235) = 0.4906415
normcdff(+3.9648) = 0.9999633
normcdff(+7.9531) = 1.0000000
PASSED!
```

All 1024 points are within `1e-6 + 1e-5·|ref|` of the double-precision reference.

Reference build: Vortex v3.0, XLEN 64, SimX, 4 cores × 16 warps × 32 threads, L2, A + Zacas;
CuPBoP `vortex3.0` @ `d289d36` (unmodified); Vortex LLVM 20.1.8 from the v3.0.1 toolchain; CUDA
11.7 headers. `test_normcdff`: 23,211 instructions, 158,834 cycles.

## Going further

- Other `__nv_*` functions still missing from CuPBoP, each a self-contained exercise of the same
  shape: `rnormf`, `norm3df`, `rnorm3df`, `rhypotf`, `erfinvf`, `erfcinvf`, `erfcxf`,
  `normcdfinvf`, `j0f`, `y0f`, `cyl_bessel_i0f`, `__float2half_rn`, `__half2float`, and the SIMD
  video intrinsics (`__vadd4`, …). Write a test like `test_normcdff`, watch it fail, add the
  function.
- Assignment 8 compares the same softmax kernel across Vortex's programming models; its optional
  part runs the CUDA version through CuPBoP.

## Questions

1. Remove your `tool.cpp` change, rebuild `kernelTranslator`, `make clean && make ci`. Does the
   test still pass? Explain from the compile flags in `examples/common.mk` why, and describe a
   flow in which the `deleteBody()` list is required.
2. An alternative implementation is `0.5f * (1.0f + erff(x * 0.70710678f))`. Work out its
   relative error at `x = -6` (true value ≈ 1e-9) in single precision. Would `test_normcdff`
   catch it with its tolerance of `1e-6 + 1e-5·|ref|`? What would a better test check?
3. Why does a CUDA block of 512 threads fail on the default 4 warps × 4 threads build, and where
   does CuPBoP's runtime map CUDA `threadIdx.x` onto Vortex warps and threads?
4. `ci/rg-ci-setup-v3.sh` explains why CuPBoP's SimX needs an L2 cache for atomics across
   cores. Where does SimX commit an atomic operation, and what goes wrong when each core's private
   L1 is the last-level cache?
