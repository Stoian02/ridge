#!/usr/bin/env python3
"""Validate bounded hitch captures and report transitions/tails, not causation."""
import argparse
import csv
import json
import math
from pathlib import Path

LONG_FRAME_USEC = 33300  # Match the milestone's >33.3ms rule (not rounded 1/30s).


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


def event_context(ticks, frames, radius_usec=250000):
    """Transitions are changes, not the first observed state; keep all tails.

    Neighbour windows use interval overlap, not just the frame's endpoint.
    Object/resource/memory differences are net monitor changes, not a measure
    of total allocation churn. Nothing here attributes CPU work or causation.
    """
    indexed = validate(ticks, frames)
    tick_frames = {tick: frame for frame in frames
                   for tick in range(int(frame["first_tick"]), int(frame["last_tick"]) + 1)
                   if tick >= 0}
    previous_frames = {int(current["frame"]): previous
                       for previous, current in zip(frames, frames[1:])}
    first_time = ticks[0]["end_usec"]

    def describe(frame):
        result = dict(frame)
        result["seconds"] = (frame["end_usec"] - first_time) / 1e6
        result["last_state"] = indexed.get(int(frame["last_tick"]))
        previous = previous_frames.get(int(frame["frame"]))
        if previous is not None:
            result["net_monitor_changes"] = {
                key: frame[key] - previous[key]
                for key in ("loop_starts", "water_entries", "thumps", "objects",
                            "nodes", "resources", "static_bytes")
                if key in frame and key in previous}
        return result

    transitions = []
    for previous, current in zip(ticks, ticks[1:]):
        for key in ("stalled", "sinking", "flooding"):
            before, after = previous[key] >= 1.0, current[key] >= 1.0
            if before == after:
                continue
            at = current["end_usec"]
            nearby = [frame for frame in frames if frame["interval_usec"] > 0
                      and frame["end_usec"] >= at - radius_usec
                      and frame["end_usec"] - frame["interval_usec"] <= at + radius_usec]
            containing = tick_frames.get(int(current["tick"]))
            transitions.append({
                "state": "fully_flooded" if key == "flooding" else key,
                "before": before, "after": after, "tick": current["tick"],
                "seconds": (at - first_time) / 1e6,
                "frame": describe(containing) if containing is not None else None,
                "nearby_frame_count": len(nearby),
                "nearby_max_ms": max((f["interval_usec"] for f in nearby), default=0) / 1000,
            })
    measured = [frame for frame in frames if frame["interval_usec"] > 0]
    state_ticks = {"not_stalled": 0, "stalled_not_full": 0, "stalled_full": 0}
    for row in ticks:
        key = ("not_stalled" if not row["stalled"] else
               "stalled_full" if row["flooding"] >= 1.0 else "stalled_not_full")
        state_ticks[key] += 1
    return {
        "initial_state": {key: ticks[0][key] for key in ("stalled", "sinking", "flooding")},
        "transition_radius_usec": radius_usec, "transition_windows": transitions,
        "state_tick_counts": state_ticks,
        "all_long_frames": [describe(frame) for frame in measured if frame["interval_usec"] > LONG_FRAME_USEC],
        "maximum_frame": describe(max(measured, key=lambda frame: frame["interval_usec"])),
    }


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
            "over_33ms": sum(r["interval_usec"] > LONG_FRAME_USEC for r in measured),
            "recorder_p95_usec": percentile([r["recorder_usec"] for r in measured], .95),
            "transitions": transitions, "tails": tails,
            "event_context": event_context(ticks, frames)}


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
