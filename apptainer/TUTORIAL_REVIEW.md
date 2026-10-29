# Vortex tutorial review: all 12 assignments worked in the container image

**Bottom line.** All 12 assignments run correctly in the Apptainer image. For each one I wrote the missing code
(SimX, RTL, kernels, host changes) and compared the output with the numbers printed in the assignment. They match,
apart from a few small differences listed at the end. The tutorial text needs 9 fixes (section 2); the first three
will stop a student if left as they are.

Setup: Vortex v3.0 (Assignment 11: `master` @ `50cb17454`), image `vortex_micro26.sif` plus the `--all` toolchain, on `crush`.

## 1. Result per assignment

| # | Topic | What I implemented | Result |
|---|---|---|---|
| 1 | Scoreboard stall attribution | SimX + RTL counters | Match (6 SimX + 6 rtlsim runs) |
| 2 | Software prefetch | `vx_prefetch` in SimX + RTL, cache counters | Match (full distance sweep, SimX + rtlsim) |
| 3 | VX_DOT8 | Instruction in SimX + RTL, ASIC synthesis | Match; synthesis runs end to end |
| 4 | FP6 tensor format | SimX + RTL multiplier | Match (16 SimX points, unit tests, rtlsim) |
| 5 | GTO vs round-robin | Config knob in SimX + RTL | Match (12 SimX + 4 rtlsim cycle counts) |
| 6 | Bug hunt | Trace diff, RTL fix | Finds the bug at the first differing instruction; fixed run passes |
| 7 | Perfetto / divergence | Thread remap | Match (6 table rows) |
| 8 | Softmax on 4 stacks | Native fixes, OpenCL, HIP, Vulkan | Match (instructions exact) |
| 9 | CUDA on Vortex (CuPBoP) | `normcdff` | Fails before, passes after, output as printed |
| 10 | DXA async copies | Single and double buffered `sgemm2` | Passes; DXA counters exact |
| 11 | Ray-tracing unit | none (analysis) | Match (8 width rows, 6 slot/warp rows) |
| 12 | Neural texture | Tensor-core MLP decoder | Match (5 variants, instructions and cycles exact) |

Not tested: GUI tools (GTKWave, Perfetto web UI), the JupyterHub terminal path, stretch goals (A8 L2 and CUDA part,
A3 two-stage PE) and the written Questions.

## 2. What to change in the tutorial text

**Will block a student**

1. **A9: CuPBoP setup breaks later builds.** `rg-ci-setup-v3.sh` leaves `RISCV_TOOLCHAIN_PATH` set to the 64-bit
   toolchain, so the next 32-bit build in the same shell fails (`'newlib.h' file not found`). Say: run the CuPBoP
   steps in a subshell or a new terminal, or `unset RISCV_TOOLCHAIN_PATH`.
2. **A8 Step 0.2: the fix has no effect.** Editing `common.h` does not rebuild the kernel, so the old numbers print
   again. Add `make -C tests/regression/softmax clean` after the edit.
3. **A11 Setup: `make -s` can fail once** in `third_party` (a build race, seen with `-j16` and `-j4`). Running it
   again works. Add one sentence.

**Missing prerequisites**

4. **A9:** also needs the cuRAND headers (`libcurand-dev-12-1`) and `libtinfo-dev`.
5. **A8 (Vulkan):** `install_dependencies.sh --vulkan` omits `libunwind8`; without it Vulkan fails with
   `VkResult -9`.

**Clarity**

6. **A5 Step 2:** say where the `constexpr` goes: right after `using namespace vortex;` (elsewhere it does not compile).
7. **Run directory:** A3 Part C and A8 `make -C ...` must run from `build32/`; from the Vortex root the error
   (`config.mk: No such file`) does not explain why. Add "run from `build32/`".
8. **Naming:** A2, A3, A4 use `~/vortex_tutorials`, the others `$TUTORIAL`; the toolchain is `$HOME/tools` in the text
   but `$TOOLDIR` on the Rogues Gallery. Use `$TUTORIAL` and `$TOOLDIR` everywhere.
9. **Remote option:** `sudo ./ci/install_dependencies.sh --vulkan` and `toolchain_install.sh --all` are already done
   in the image; the page should say so once.
