#!/usr/bin/env bash
# Run the row-softmax kernel of Assignment 8 on every stack at one size (SimX),
# print one summary row per stack and plot instrs/cycles with plot_perf.py.
#
# Run from your Vortex build directory (e.g. build32/) after applying
# patches/a8_softmax_tests.patch and re-running ../configure.
#
#   run_softmax_table.sh [-n size] [-s scale] [-o outdir] [-t tag] [stack ...]
#
#   stack     native opencl hip vulkan (default: all four, Vulkan last because
#             its CONFIGS rebuild the shared SimX runtime)
#   -n size   matrix is size x size (default 64)
#   -s scale  input range [0, scale) for the OpenCL/HIP/Vulkan hosts (default 1)
#   -o dir    where logs and the plot go (default softmax_n<size>[_<tag>])
#   -t tag    suffix for the output directory and plot labels (e.g. l2)
#
# Environment:
#   KERNEL_OPENCL, KERNEL_HIP, KERNEL_VULKAN  another kernel file of the test's
#                     source directory (e.g. KERNEL_OPENCL=kernel_l2.cl)
#   MESA_PATH         Mesa Vortex install for the Vulkan run (default: the
#                     Makefile's $(TOOLDIR)/mesa-vortex)
#   TIMEOUT           per-run limit in seconds (default 300)
#   PLOT_ARGS         extra arguments for plot_perf.py (e.g. "--normalize opencl")

set -u

size=64
scale=
outdir=
tag=
while getopts "n:s:o:t:h" opt; do
  case $opt in
    n) size=$OPTARG ;;
    s) scale=$OPTARG ;;
    o) outdir=$OPTARG ;;
    t) tag=$OPTARG ;;
    h) sed -n '2,24p' "$0"; exit 0 ;;
    *) exit 1 ;;
  esac
done
shift $((OPTIND - 1))
stacks=("$@")
[ ${#stacks[@]} -eq 0 ] && stacks=(native opencl hip vulkan)

if [ ! -f config.mk ] || [ ! -d tests/regression/softmax ]; then
  echo "error: run this from your Vortex build directory (config.mk not found)" >&2
  exit 1
fi

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
outdir=${outdir:-softmax_n${size}${tag:+_$tag}}
mkdir -p "$outdir"
timeout_s=${TIMEOUT:-300}

opts="-n$size"
plots=()
printf "%-8s %-8s %12s %12s %7s %10s %8s\n" stack result instrs cycles IPC max_relerr wall_s
for stack in "${stacks[@]}"; do
  case $stack in
    native) dir=tests/regression/softmax; kvar= ;;
    opencl) dir=tests/opencl/softmax; kvar=${KERNEL_OPENCL:+KERNEL=$KERNEL_OPENCL} ;;
    hip)    dir=tests/hip/softmax;    kvar=${KERNEL_HIP:+KERNEL=$KERNEL_HIP} ;;
    vulkan) dir=tests/vulkan/softmax; kvar=${KERNEL_VULKAN:+KERNEL=$KERNEL_VULKAN} ;;
    *) echo "unknown stack '$stack' (native|opencl|hip|vulkan)" >&2; continue ;;
  esac
  if [ ! -f "$dir/Makefile" ]; then
    echo "$stack: $dir/Makefile missing (apply the handout patch, re-run ../configure)" >&2
    continue
  fi
  run_opts=$opts
  [ -n "$scale" ] && [ "$stack" != native ] && run_opts="$run_opts -s$scale"
  args=(run-simx "OPTS=$run_opts")
  [ -n "$kvar" ] && args+=("$kvar")
  [ "$stack" = vulkan ] && [ -n "${MESA_PATH:-}" ] && args+=("MESA_PATH=$MESA_PATH")

  log=$outdir/$stack.log
  t0=$(date +%s)
  timeout "$timeout_s" make -C "$dir" "${args[@]}" > "$log" 2>&1
  rc=$?
  wall=$(( $(date +%s) - t0 ))

  # Tests may exit 0 while failing: trust PASSED!/FAILED!, not the exit code.
  result=$(grep -o -m1 -E "PASSED!|FAILED!" "$log" | tr -d '!')
  [ $rc -eq 124 ] && result=TIMEOUT
  perf=$(grep -E "PERF: instrs=" "$log" | tail -1)
  instrs=$(sed -n 's/.*instrs=\([0-9]*\).*/\1/p' <<< "$perf")
  cycles=$(sed -n 's/.*cycles=\([0-9]*\).*/\1/p' <<< "$perf")
  ipc=$(sed -n 's/.*IPC=\([0-9.]*\).*/\1/p' <<< "$perf")
  relerr=$(sed -n 's/^Max relative error: //p' "$log" | tail -1)
  printf "%-8s %-8s %12s %12s %7s %10s %8s\n" "$stack" "${result:-ERROR}" "${instrs:--}" \
         "${cycles:--}" "${ipc:--}" "${relerr:--}" "$wall"
  if [ -n "$instrs" ] && [ "$instrs" != 0 ]; then
    plots+=("$stack${tag:+_$tag}=$log")
  fi
done

if [ ${#plots[@]} -gt 0 ]; then
  # shellcheck disable=SC2086
  python3 "$script_dir/plot_perf.py" "${plots[@]}" --metric instrs --metric cycles \
    --title "softmax ${size}x${size}${tag:+ ($tag)}" -o "$outdir/softmax_n${size}${tag:+_$tag}.png" \
    ${PLOT_ARGS:-} | tail -1
fi
echo "logs: $outdir/"
