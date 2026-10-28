# Assignment 6: Bug Hunt — SimX as the Oracle

> Targets Vortex release [v3.0](https://github.com/vortexgpgpu/vortex/releases/tag/v3.0).

## Background

Vortex has two models of the same GPU: **SimX**, a cycle-approximate C++
simulator, and the **RTL**, simulated cycle-accurately with Verilator
(`rtlsim`). Both execute the same kernel binary, and the CI holds them to the
same answer: a `model_parity` case runs one app on both drivers and requires
the retired-instruction count to match *exactly*
([`ci/testcases/core.yaml`](https://github.com/vortexgpgpu/vortex/blob/v3.0/ci/testcases/core.yaml#L11)).

That makes SimX a *functional oracle* for the RTL. When the RTL produces a wrong
result, you do not start by staring at waveforms. You run the same program on
both models with the same trace level, convert both traces to one format and
`diff` them. Every instruction carries a **uuid** that is identical in both
models, so the first line that differs is the first instruction the RTL got
wrong: its PC, opcode, lanes and values. Only then do you open the waveform,
at the exact time stamp of that instruction, in the one module that executed it.
The v3.0 debugging guide describes the method in
[SimX as Oracle for RTL Debug](https://github.com/vortexgpgpu/vortex/blob/v3.0/docs/debugging.md#L106).

In this assignment the RTL is the subject. You get a handout patch that plants
a one-line bug in the RTL. You find it with the oracle method and fix it.

**The tools.**

| Tool | What it does |
|---|---|
| `./ci/blackbox.sh --debug=3 --log=<file>` | runs an app with a level-3 trace written to `<file>` (all program output goes there too) |
| `./ci/blackbox.sh --vcd` (rtlsim only) | also writes a waveform `trace.vcd`; independent of `--debug` |
| [`ci/trace_csv.py`](https://github.com/vortexgpgpu/vortex/blob/v3.0/ci/trace_csv.py) | converts a SimX or rtlsim trace into one CSV row per instruction, sorted by uuid |
| GTKWave (or any VCD viewer) | waveform viewer for `trace.vcd` |

**Trace formats.** The two models print different trace lines. SimX lines start
with `TRACE <cycle>:`:

```
TRACE        110: cluster0-socket0-core0-pipeline commit: cid=0, wid=0, cta_id=0, tmask=1111, PC=0x80000000, wb=1, rd=x5, rs0=x0, ex=SFU (#0)
DEBUG Instr: CSRRS x5, x0, 0xfc1 [fu_lock,fu_unlock] (#0)
```

RTL lines start with a Verilator time stamp (a *tick*) and the module path:

```
 8615: cluster0-socket0-core0-issue0-dispatcher dispatch: wid=0, cta_id=0, sid=0, PC=0x8000010c, ex=ALU, op=SRAI, tmask=1111, wb=1, wr_xregs=00, rd=11, rs1_data={0x820090ff, 0xd5f2bcb7, 0x8d530606, 0xf2791e2a}, ... (#303)
 8619: cluster0-socket0-core0-commit commit: wid=0, cta_id=0, sid=0, PC=0x8000010c, ex=ALU, tmask=1111, wb=1, wr_xregs=00, rd=11, sop=1, eop=1, data={...} (#303)
```

Facts you will need:

- The number in `(#303)` is the uuid.
- RTL ticks are Verilator `$time`, **2 ticks per clock cycle**. `trace_csv.py`
  divides by 2. The VCD timescale is `1ps` with one tick per ps, so a tick from
  the log is directly the time to jump to in the waveform viewer.
- In the raw RTL log, per-lane vectors are printed **highest lane first**
  (`rs1_data={lane3, lane2, lane1, lane0}`). SimX and the CSV print lane 0
  first. The CSV normalizes this; when you read the raw RTL log, mind the order.
- The RTL log starts with a few lines of pre-reset X noise at ticks 1–2
  (random PCs and masks). Skip them.
- There are no `D$0 ...` lines any more (that was the v2.3 format). Memory
  lines look like `cluster0-socket0-core0-execute-lsu0 Rd Req: ...` and
  `cluster0-socket0-dcache0-bank0 core-rd-req: ...`.

## Setup

Clone the v3.0 release and build it out of tree. If you fetched the `v3.0`
tag before 2026-10-07, refresh it first with `git fetch --tags --force`.

```bash
git clone --branch v3.0 --recursive https://github.com/vortexgpgpu/vortex.git
cd vortex
mkdir build32 && cd build32
../configure --xlen=32 --tooldir=$HOME/tools
./ci/toolchain_install.sh --all     # prebuilt toolchain incl. Verilator, first time only
make -s
```

Install a VCD viewer if you do not have one (`sudo apt-get install gtkwave` on
Ubuntu, or any viewer that reads VCD).

Apply the handout patch from the Vortex root. `$TUTORIAL` is your checkout of
this tutorial repository (e.g. `~/vortex_tutorials`).

```bash
cd ..                                    # Vortex root
git apply $TUTORIAL/Exercises/patches/a6_bug.patch
cd build32
```

**Do not open `a6_bug.patch`.** It is a one-line change somewhere in the RTL,
and reading it is reading the answer. The point of the assignment is to find it
with the tools.

**Plan your time.** Every combination of `--debug`/`--vcd`/`--perf` on rtlsim is
a different Verilator build: 5–8 minutes on a fast machine, 10–20 minutes on a
4-core laptop or VM, about 3 GB of RAM. Build the *debug + VCD* variant once and
use it for every rtlsim run in this assignment; never alternate flags. Start the
build now and do Part A while it runs (in a second terminal, same directory):

```bash
make -C tests/regression/arith runtime-rtlsim DEBUG=3 VCD=1
```

Expected time for the whole assignment: 2.5–3 h, of which 30–40 min is waiting
for the two Verilator builds (this one and the one after your fix).

## Part A: SimX — build the oracle trace

The planted bug is in the RTL only, so SimX still computes the right answer.
In this part you produce the reference trace and learn to read it.

### Step A1: Run the failing test on SimX

The test is
[`tests/regression/arith`](https://github.com/vortexgpgpu/vortex/blob/v3.0/tests/regression/arith/kernel.cpp):
64 signed 64-bit integers, each shifted right by 47 bits on the device and
checked on the host.

```bash
./ci/blackbox.sh --driver=simx --app=arith --debug=3 --log=run_simx_arith.log
grep -E "PERF: instrs|PASSED|FAILED" run_simx_arith.log
```

`--debug=3` rebuilds the SimX runtime at `-O0` with tracing (about a minute,
once). With `--debug`, all program output goes into the log file, so look for
`PASSED!` there. Expected:

```
PERF: instrs=1437, cycles=6134, IPC=0.234
PASSED!
```

The log is about 3.4 MB and 29,500 lines for 6 k cycles. Keep traced runs small.

### Step A2: Read the trace

Open `run_simx_arith.log` and find:

1. the `CONFIGS:` header near the top (`trace_csv.py` needs it; a log without
   `--debug` does not parse);
2. the first `pipeline commit` line of warp 0 and its `DEBUG Instr:` line with
   the same uuid;
3. the first `lsu mem-req` line. What is `op`, which lanes are active, and why
   does the uuid look so large (`#4294967316`)?

### Step A3: Convert to CSV

```bash
./ci/trace_csv.py -tsimx run_simx_arith.log -otrace_simx.csv
head -3 trace_simx.csv
wc -l trace_simx.csv          # 1438 = header + 1437 instructions
```

Each row is `uuid,PC,opcode,core_id,warp_id,tmask,destination,operands`, with
per-lane register values, lane 0 first:

```
uuid,PC,opcode,core_id,warp_id,tmask,destination,operands
0,0x80000000,CSRRS,0,0,1111,"x5={0x4, 0x4, 0x4, 0x4}","x0={0x0, 0x0, 0x0, 0x0}"
1,0x80000004,AUIPC,0,0,1111,"x6={0x80000004, 0x80000004, 0x80000004, 0x80000004}",
```

This file is your oracle. The row count equals the `instrs=` of the run.

### Step A4: The smoke test

Run the standard smoke test on SimX too (no trace):

```bash
./ci/blackbox.sh --driver=simx --app=demo --args="-n100"
```

You will need its result in Part B.

## Part B: RTL — find and fix the bug

Wait for the Verilator build from Setup to finish. The trace and CSV steps are
those of Part A (Steps A1 and A3) with `--driver=rtlsim` and `-trtlsim`.

### Step B1: Reproduce

```bash
./ci/blackbox.sh --driver=rtlsim --app=demo --args="-n100" --debug=3 --vcd --log=run_rtlsim_demo.log
./ci/blackbox.sh --driver=rtlsim --app=arith --debug=3 --vcd --log=run_rtlsim_arith.log
```

Each run takes seconds once the driver is built (a debug build is `-O0 -g`, so
it is slow per cycle: do not trace anything beyond ~50 k cycles). Because
`--debug` sends program output to the log, `blackbox.sh` echoes the last 100
log lines when a run fails, so `FAILED!` is visible on the console. The second
run also leaves `trace.vcd` (about 65 MB) in the current directory; the first
one wrote a 234 MB one that the second overwrote.

Record:

- Does `demo` pass on the buggy RTL?
- How many errors does `arith` report, and what do the wrong values look like?
- Does `instrs=` match SimX? What does that tell you about where the bug can
  and cannot be?

### Step B2: Diff against the oracle

```bash
./ci/trace_csv.py -trtlsim run_rtlsim_arith.log -otrace_rtlsim.csv
diff trace_simx.csv trace_rtlsim.csv | head -12
diff trace_simx.csv trace_rtlsim.csv | wc -l
```

The first hunk is the first instruction the RTL got wrong. Everything after it
may only be propagating a wrong register. **Deliverable 1:** the first divergent
uuid, its PC and opcode, the lanes that differ, the input and output values on
those lanes from both models, and a one-sentence hypothesis about the bug
(e.g. "when bit … of the operand is …, the result is …").

Look at the inputs of the lanes that are wrong and of the lanes that are right
*in the same instruction*. What distinguishes them bitwise?

### Step B3: From uuid to waveform

Find the tick at which the RTL executed that instruction:

```bash
grep '(#<uuid>)' run_rtlsim_arith.log
```

The `issue0-dispatcher dispatch` line gives the tick at which the operands
entered the functional unit (`rs1_data`, highest lane first); the `commit` line
gives the result (`data`).

Open the waveform:

```bash
gtkwave trace.vcd &
```

1. In the SST (hierarchy) pane, navigate to the ALU that executed the
   instruction:
   `TOP.rtlsim_shim.vortex.g_clusters[0].cluster.g_sockets[0].socket.g_cores[0].core.execute.alu_unit.g_blocks[0].alu_int`.
   This module is fully traced (modules under `hw/rtl/libs/` are excluded from
   the VCD by default; this one is not).
2. Add `clk`, `alu_op`, `is_signed`, `alu_in1`, `alu_in2`, `alu_result` and the
   intermediate result vectors you find there (look at the module's
   [source](https://github.com/vortexgpgpu/vortex/blob/v3.0/hw/rtl/core/VX_alu_int.sv)
   to see which one feeds this opcode).
3. Zoom to the dispatch tick (type it into the *From*/*To* boxes of the toolbar,
   e.g. a 40-tick window around it). Expand the per-lane vectors.

**Deliverable 2:** a screenshot of the window showing the operands and the wrong
result of the failing lanes, and the RTL line in `VX_alu_int.sv` that is
responsible.

### Step B4: Fix and confirm

Fix the line in `hw/rtl/core/VX_alu_int.sv`. Because the RTL changed,
`blackbox.sh` rebuilds the Verilator model on the next run (another 5–20
minutes). Then:

```bash
./ci/blackbox.sh --driver=rtlsim --app=arith --debug=3 --vcd --log=run_rtlsim_arith.log
./ci/trace_csv.py -trtlsim run_rtlsim_arith.log -otrace_rtlsim.csv
diff trace_simx.csv trace_rtlsim.csv | wc -l       # 0
./ci/blackbox.sh --driver=rtlsim --app=demo --args="-n100" --debug=3 --vcd --log=run_rtlsim_demo.log
```

**Deliverable 3:** your one-line fix, `PASSED!` for both apps and an empty diff.

### Bonus

Write a kernel of about ten lines that would have caught this bug in a smoke
test, without 64-bit arithmetic. Add it as `tests/regression/<name>` (copy the
`arith` directory, re-run `../configure`), and show that it fails on the buggy
RTL and passes on SimX and on the fixed RTL.

## Expected results

Default configuration (1 core, 4 warps × 4 threads), `--debug=3`. The table is
also in [`expected/a6/results.csv`](expected/a6/results.csv).

| app | SimX | rtlsim, buggy RTL | rtlsim, fixed RTL |
|---|---|---|---|
| `arith` | PASSED, 1,437 instrs / 6,134 cycles | **FAILED, 41 errors**, 1,437 / 6,059 | PASSED, 1,437 / 6,059 |
| `demo -n100` | PASSED, 3,740 / 9,764 | PASSED, 3,740 / 9,624 | PASSED, 3,740 / 9,624 |
| `diff` of the CSVs vs SimX (`arith`) | — | 160 lines | 0 lines |

Typical failing output:

```
*** error: [1] expected=ffffffffffff1aa6, actual=100011aa6
*** error: [3] expected=ffffffffffff0401, actual=100010401
...
Found 41 errors!
FAILED!
```

The full CSV diff of the buggy run is in
[`expected/a6/trace_diff_arith.txt`](expected/a6/trace_diff_arith.txt): 16
hunks of four instructions each, one per group of four elements. Check your
Deliverable 1 against its first hunk only after you have written your own.

Sizes and times (measured on a loaded shared server; yours will differ; sizes
as `ls -lh` prints them): rtlsim debug+VCD build 5–8 min; `arith` run 7–10 s,
5.8 MB log, 65 MB VCD; `demo -n100` run 9–15 s, 19 MB log, 234 MB VCD.

Reproduce (from `build32/`):

```bash
./ci/blackbox.sh --driver=simx   --app=arith --debug=3 --log=run_simx_arith.log
./ci/blackbox.sh --driver=rtlsim --app=arith --debug=3 --vcd --log=run_rtlsim_arith.log
./ci/trace_csv.py -tsimx   run_simx_arith.log   -otrace_simx.csv
./ci/trace_csv.py -trtlsim run_rtlsim_arith.log -otrace_rtlsim.csv
diff trace_simx.csv trace_rtlsim.csv
```

## Questions

1. `demo -n100` passed on the buggy RTL. Explain why from what `demo` computes
   and from the condition under which the bug changes a result. What is the
   lesson for choosing smoke tests?
2. The failing lanes looked "random" (indices 1, 3, 4, 5, 6, 7, 9, …). Derive
   from the bug which inputs fail, and estimate the fraction of failures for
   uniformly random negative 64-bit inputs. Compare with 41 of 64.
3. `instrs=` was identical on both drivers although the results were wrong.
   Which classes of RTL bugs would change the instruction count, and which
   would not? Which of the two `model_parity` checks (exact instructions,
   cycles within a tolerance) would have caught this bug?
4. SimX and rtlsim report different cycle counts for `arith` (6,134 vs 6,059)
   although they execute the same instructions. Why is that not a bug, and why
   does the CSV diff ignore it?
5. You trusted SimX. When is that wrong? Describe a situation in which SimX is
   the model with the bug, and how you would tell the two cases apart.
6. Why does the CSV sort by uuid rather than by time stamp? What would a diff
   of two time-sorted traces look like?
7. Why is `--vcd` a separate flag from `--debug`, and why do both force a
   Verilator rebuild? Estimate the VCD size of a 1 M-cycle run from the two
   measured sizes.
