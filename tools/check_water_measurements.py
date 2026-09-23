#!/usr/bin/env python3
"""Independently validate water_acceptance CSVs against their JSON summaries."""

import argparse
import csv
import json
import math
from pathlib import Path


def check(directory: Path, limit_ms: float | None) -> int:
    summaries = json.loads((directory / "summary.json").read_text())
    total = 0
    failures = 0
    seen_cases: set[str] = set()
    seen_ticks: set[int] = set()
    for summary in summaries:
        if summary["case"] in seen_cases:
            raise ValueError("duplicate case in summary")
        seen_cases.add(summary["case"])
        path = directory / (summary["case"] + ".csv")
        with path.open(newline="") as stream:
            rows = list(csv.DictReader(stream))
        if not rows or len(rows) != summary["samples"]:
            raise ValueError(f"{path}: missing samples")
        ticks = [int(row["physics_tick"]) for row in rows]
        if any(b != a + 1 for a, b in zip(ticks, ticks[1:])):
            raise ValueError(f"{path}: repeated or skipped tick")
        if seen_ticks.intersection(ticks):
            raise ValueError(f"{path}: tick already recorded in another case")
        seen_ticks.update(ticks)
        costs = sorted(float(row["water_usec"]) / 1000 for row in rows)
        if not all(math.isfinite(cost) and cost >= 0 for cost in costs):
            raise ValueError(f"{path}: invalid timing")
        p95 = costs[math.ceil(len(costs) * 0.95) - 1]
        if not math.isclose(p95, summary["water_p95_ms"], abs_tol=1e-9):
            raise ValueError(f"{path}: p95 disagrees with summary")
        if not math.isclose(costs[-1], summary["water_max_ms"], abs_tol=1e-9):
            raise ValueError(f"{path}: maximum disagrees with summary")
        failed = limit_ms is not None and p95 > limit_ms
        failures += int(failed)
        total += len(rows)
        print(f"{summary['case']}: n={len(rows)} p95={p95:.3f} ms "
              f"max={costs[-1]:.3f} ms{' OVER LIMIT' if failed else ''}")
    gate = f"{failures} over the requested limit" if limit_ms is not None else "no gate requested"
    print(f"Verified {len(summaries)} cases / {total} ticks; {gate}.")
    return 2 if failures else 0


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("directory", type=Path)
    parser.add_argument("--limit-ms", type=float,
                        help="Optional p95 gate; exit 2 if any case exceeds it")
    args = parser.parse_args()
    raise SystemExit(check(args.directory, args.limit_ms))
