#!/usr/bin/env python3
"""Independently validate water_acceptance CSVs against their JSON summaries."""

import argparse
import csv
import json
import math
from pathlib import Path


def check(directory: Path, limit_ms: float | None) -> int:
    summaries = json.loads((directory / "summary.json").read_text())
    if not isinstance(summaries, list) or not summaries:
        raise ValueError("summary must contain at least one measured case")
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
        if "queries" in summary:
            for column, key, scale in [("queries", "queries", 1),
                                       ("triangle_tests", "triangle_tests", 1),
                                       ("query_usec", "query_total_ms", 1000)]:
                values = [float(row[column]) for row in rows]
                if not all(math.isfinite(value) and value >= 0 for value in values):
                    raise ValueError(f"{path}: invalid {column}")
                if not math.isclose(sum(values) / scale, summary[key], abs_tol=1e-8):
                    raise ValueError(f"{path}: {column} total disagrees")
            with path.with_stem(path.stem + "_frames").open(newline="") as stream:
                frames = list(csv.DictReader(stream))
            if not frames or len(frames) != summary["frame_samples"]:
                raise ValueError(f"{path}: missing frame samples")
            frame_ids = [int(row["process_frame"]) for row in frames]
            if any(b != a + 1 for a, b in zip(frame_ids, frame_ids[1:])):
                raise ValueError(f"{path}: skipped or duplicated process frame")
            for column, prefix in [("frame_usec", "frame"), ("water_usec", "water_frame")]:
                values = sorted(float(row[column]) / 1000 for row in frames)
                if not all(math.isfinite(value) and value >= 0 for value in values):
                    raise ValueError(f"{path}: invalid frame data")
                for suffix, value in [("p95", values[math.ceil(len(values) * .95) - 1]),
                                      ("max", values[-1])]:
                    if not math.isclose(value, summary[f"{prefix}_{suffix}_ms"], abs_tol=1e-9):
                        raise ValueError(f"{path}: frame {column} {suffix} disagrees")
            tick_counts = [int(row["physics_ticks"]) for row in frames]
            # The first partial frame and trailing ticks are deliberately not
            # frame intervals; all complete-frame updates must belong to rows.
            if any(count < 0 for count in tick_counts) or sum(tick_counts) > len(rows):
                raise ValueError(f"{path}: impossible frame tick counts")
            if sum(float(row["water_usec"]) for row in frames) > sum(costs) * 1000 + 1e-6:
                raise ValueError(f"{path}: frame water cost exceeds recorded ticks")
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
