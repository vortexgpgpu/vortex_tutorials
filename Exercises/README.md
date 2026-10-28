# Vortex Tutorial Exercises

> Targets Vortex release [v3.0](https://github.com/vortexgpgpu/vortex/releases/tag/v3.0).
> Assignment 11 needs the RTU performance counters, which are on `master` from commit
> [`50cb17454`](https://github.com/vortexgpgpu/vortex/commit/50cb17454); its Setup says how to check it out.

Twelve hands-on assignments, grouped by topic. Each one is self-contained. Pick a category
that matches your interests, or follow the numbers.

Most assignments run on **SimX**, Vortex's cycle-level simulator, and work on a laptop or VM.
Assignments with an **RTL extension** first build the feature in SimX (Part A), then implement
it in the SystemVerilog RTL (Part B), checked against Part A with Verilator (`rtlsim`). Part B
needs more time: each new hardware configuration is a Verilator build of 5–15 minutes.

## Setup (all assignments)

```bash
git clone --branch v3.0 https://github.com/vortexgpgpu/vortex.git
cd vortex
mkdir build32 && cd build32
../configure --xlen=32 --tooldir=$HOME/tools
./ci/toolchain_install.sh --all
make -s
```

After editing a `.toml` file or a Makefile, or applying a handout patch that adds a test, re-run
`../configure` from `build32` and then `make -s`. Hardware parameters that are not
`blackbox.sh` flags go through `CONFIGS="-DVX_CFG_…"`; build the test app with the same `CONFIGS`
as the driver. Tests can exit 0 while failing: always look for `PASSED!` / `FAILED!` in the output.

Handout patches are in [`patches/`](patches/). Apply them from the root of your Vortex checkout:

```bash
git apply <path-to-this-repo>/Exercises/patches/<patch>
```

## Microarchitecture

| # | Assignment | You build | Models | Time |
|---|---|---|---|---|
| 1 | [Scoreboard stall attribution](assignment1.md) | per-unit scoreboard stall counters | SimX + RTL extension | 1.25 h + 2.5 h |
| 2 | [Software prefetching](assignment2.md) | `vx_prefetch` instruction and cache prefetch counters | SimX + RTL extension | 1.5 h + 2 h |
| 3 | [VX_DOT8](assignment3.md) | an int8 dot-product instruction; optional ASIC synthesis | SimX + RTL extension | 1.5 h + 2 h (+1 h) |
| 4 | [FP6 tensor format](assignment4.md) | a new tensor-core input format (OCP-MX e2m3) | SimX + RTL extension | 2 h + 2 h |
| 5 | [Warp issue policy: GTO vs round-robin](assignment5.md) | a configurable issue arbiter | SimX + RTL extension | 2 h |

## Debug and performance tools

| # | Assignment | You build | Models | Time |
|---|---|---|---|---|
| 6 | [Bug hunt: SimX as the oracle](assignment6.md) | find and fix an RTL bug with trace diffs and waveforms | RTL | 2.5–3 h |
| 7 | [Performance analysis with Perfetto](assignment7.md) | find and fix a SIMT divergence problem from a timeline | SimX | 2 h |

## Programming models

| # | Assignment | You build | Models | Time |
|---|---|---|---|---|
| 8 | [One kernel, four stacks: row softmax](assignment8.md) | the same kernel in native C++, OpenCL, HIP and Vulkan, compared | SimX | 2–2.5 h (+1 h) |
| 9 | [CUDA on Vortex with CuPBoP](assignment9.md) | a missing CUDA math function (`normcdff`) | SimX | 1.5 h |

## Accelerators and graphics

| # | Assignment | You build | Models | Time |
|---|---|---|---|---|
| 10 | [Async tile staging with DXA](assignment10.md) | an sgemm that stages tiles with async copies and barriers | SimX | 2 h |
| 11 | [Ray-tracing unit performance analysis](assignment11.md) | a BVH-width and RTU-sizing study | SimX | 2 h |
| 12 | [Neural texture on the tensor core](assignment12.md) | an MLP texture decoder on the tensor core | SimX | 2 h |

## Tools

- [`tools/plot_perf.py`](tools/plot_perf.py) — plots the `PERF:` lines of several runs as a bar
  chart (`python3 tools/plot_perf.py base=base.log new=new.log -o out.png`).
- [`expected/`](expected/) — the figures and tables each assignment's *Expected results* section
  refers to.
