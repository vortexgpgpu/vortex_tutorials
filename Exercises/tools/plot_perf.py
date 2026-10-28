#!/usr/bin/env python3
"""Plot Vortex PERF: results from several run logs as a grouped bar chart.

Each input is LABEL=LOGFILE, where LOGFILE is the captured output of a
blackbox.sh / make run-simx run. The tool reads the summary line

    PERF: instrs=..., cycles=..., IPC=...

and any "name=value%" fields of other PERF: lines (stalls, inst_mix, your
own counters), so it works for every assignment.

Examples:
    python3 plot_perf.py base=base.log prefetch=pf.log -o prefetch.png
    python3 plot_perf.py gto=gto.log rr=rr.log --metric cycles --normalize gto
    python3 plot_perf.py a=a.log b=b.log --list      # print every parsed metric
"""
import argparse
import re
import sys

SUMMARY = re.compile(r"PERF:\s+instrs=(\d+),\s*cycles=(\d+),\s*IPC=([0-9.]+)")
FIELD = re.compile(r"([A-Za-z_][\w]*)=([0-9.]+)%")


def parse(path):
    metrics = {}
    with open(path, errors="replace") as f:
        for line in f:
            if "PERF:" not in line:
                continue
            m = SUMMARY.search(line)
            if m:
                # Multi-core runs print one summary per core before the total;
                # the last one is the total.
                metrics["instrs"] = int(m.group(1))
                metrics["cycles"] = int(m.group(2))
                metrics["IPC"] = float(m.group(3))
                continue
            head = line.split("PERF:", 1)[1].split(":", 1)
            group = head[0].strip().split()[-1] if len(head) > 1 else ""
            for name, value in FIELD.findall(line):
                metrics[f"{group}.{name}" if group else name] = float(value)
    if "cycles" not in metrics:
        sys.exit(f"{path}: no 'PERF: instrs=..., cycles=...' line (run with PERF enabled?)")
    return metrics


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("runs", nargs="+", metavar="LABEL=LOG")
    ap.add_argument("--metric", action="append",
                    help="metric to plot (repeatable); default: instrs and cycles")
    ap.add_argument("--normalize", metavar="LABEL", help="divide every value by this run's value")
    ap.add_argument("--title", default="")
    ap.add_argument("--list", action="store_true", help="print all parsed metrics and exit")
    ap.add_argument("-o", "--output", default="perf.png")
    args = ap.parse_args()

    labels, data = [], {}
    for spec in args.runs:
        label, _, path = spec.partition("=")
        if not path:
            sys.exit(f"expected LABEL=LOG, got '{spec}'")
        labels.append(label)
        data[label] = parse(path)

    if args.list:
        for label in labels:
            print(f"[{label}]")
            for k, v in sorted(data[label].items()):
                print(f"  {k} = {v}")
        return

    metrics = args.metric or ["instrs", "cycles"]
    for label in labels:
        for m in metrics:
            if m not in data[label]:
                sys.exit(f"{label}: metric '{m}' not found (use --list)")

    values = {m: [data[l][m] for l in labels] for m in metrics}
    if args.normalize:
        if args.normalize not in data:
            sys.exit(f"--normalize: unknown label '{args.normalize}'")
        for m in metrics:
            base = data[args.normalize][m]
            values[m] = [v / base for v in values[m]]

    width = max(len(m) for m in metrics)
    print(f"{'run':<16}" + "".join(f"{m:>{max(width, 12) + 2}}" for m in metrics))
    for i, label in enumerate(labels):
        print(f"{label:<16}" + "".join(f"{values[m][i]:>{max(width, 12) + 2}.4g}" for m in metrics))

    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt

    fig, axes = plt.subplots(1, len(metrics), figsize=(3.2 * len(metrics) + 1, 3.6), squeeze=False)
    for ax, m in zip(axes[0], metrics):
        bars = ax.bar(labels, values[m], color="#4C72B0")
        ax.bar_label(bars, fmt="%.3g", fontsize=8)
        ax.set_title(m + (f" (vs {args.normalize})" if args.normalize else ""))
        ax.tick_params(axis="x", rotation=30)
        ax.spines[["top", "right"]].set_visible(False)
    if args.title:
        fig.suptitle(args.title)
    fig.tight_layout()
    fig.savefig(args.output, dpi=150)
    print("wrote", args.output)


if __name__ == "__main__":
    main()
