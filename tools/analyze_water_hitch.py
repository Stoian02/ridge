#!/usr/bin/env python3
"""Validate bounded hitch captures and report transitions/tails, not causation."""
import argparse
import csv
import json
import math
from pathlib import Path


def rows(path):
    with Path(path).open() as stream:
        return [{key: float(value) for key, value in row.items()}
                for row in csv.DictReader(stream)]


def percentile(values, fraction):
    ordered = sorted(values)
    if not ordered:
        raise ValueError("empty sample set")
    return ordered[max(0, math.ceil(len(ordered) * fraction) - 1)]


def validate(ticks, frames):
    if not ticks or not frames:
        raise ValueError("empty trace")
    for samples, key in [(ticks, "tick"), (frames, "frame")]:
        for row in samples:
            if any(not math.isfinite(value) for value in row.values()):
                raise ValueError("non-finite sample")
        for previous, current in zip(samples, samples[1:]):
            if current[key] != previous[key] + 1:
                raise ValueError(f"non-consecutive {key}")
    indexed = {int(row["tick"]): row for row in ticks}
    covered = set()
    for frame in frames:
        first, last, count = (int(frame[key]) for key in ["first_tick", "last_tick", "ticks"])
        if count == 0:
            if first != -1 or last != -1 or frame["water_usec"] != 0:
                raise ValueError("invalid empty frame")
            continue
        if last - first + 1 != count:
            raise ValueError("wrong frame tick count")
        ids = set(range(first, last + 1))
        if ids & covered or not ids <= indexed.keys():
            raise ValueError("duplicate or missing frame ticks")
        covered |= ids
        if abs(sum(indexed[tick]["water_usec"] for tick in ids) - frame["water_usec"]) > 0.01:
            raise ValueError("frame water sum differs from actual ticks")
    # Only the final partial frame may contain unreported ticks.
    missing = sorted(indexed.keys() - covered)
    if missing and missing != list(range(max(covered, default=min(indexed)-1) + 1, max(indexed) + 1)):
        raise ValueError("interior ticks omitted")
    return indexed


def analyze(ticks, frames):
    indexed = validate(ticks, frames)
    first_time = ticks[0]["end_usec"]
    transitions = []
    previous = None
    for row in ticks:
        state = (row["stalled"], row["sinking"], row["flooding"] >= 1.0)
        if state != previous:
            transitions.append({"seconds": (row["end_usec"] - first_time) / 1e6,
                                "tick": row["tick"], "stalled": state[0],
                                "sinking": state[1], "fully_flooded": state[2]})
        previous = state
    measured = [row for row in frames if row["interval_usec"] > 0]
    tails = []
    for frame in sorted(measured, key=lambda row: row["interval_usec"], reverse=True)[:8]:
        row = dict(frame)
        row["seconds"] = (frame["end_usec"] - first_time) / 1e6
        row["last_state"] = indexed.get(int(frame["last_tick"]))
        tails.append(row)
    return {"ticks": len(ticks), "frames": len(frames),
            "frame_p95_ms": percentile([r["interval_usec"] for r in measured], .95) / 1000,
            "frame_max_ms": max(r["interval_usec"] for r in measured) / 1000,
            "over_33ms": sum(r["interval_usec"] > 33333 for r in measured),
            "recorder_p95_usec": percentile([r["recorder_usec"] for r in measured], .95),
            "transitions": transitions, "tails": tails}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("directory", type=Path)
    args = parser.parse_args()
    # Summary selects only this batch, not stale files left on the phone.
    with (args.directory / "summary.json").open() as stream:
        cases = json.load(stream)
    result = {}
    for case in cases:
        name = case["case"]
        result[name] = analyze(rows(args.directory / f"{name}_hitch_ticks.csv"),
                               rows(args.directory / f"{name}_hitch_frames.csv"))
    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()
