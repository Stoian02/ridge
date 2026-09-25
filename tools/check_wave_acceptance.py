#!/usr/bin/env python3
"""Recompute every gate statistic and tick/frame sum, without trusting Godot's summary.

Usage: python3 tools/check_wave_acceptance.py <exported run directory>
Exit 1: corrupt/incomplete evidence. Gate failures print FAIL, not parser failure.
Recorder v1 includes whole mixed effects/audio; v2 measures water regions with
shared work conservatively and retains the original mixed upper bound separately.
Current policy: owner-approved Test Ground CPU ceilings of 6/7 ms p95/p99
(2026-09-25). This does not waive GPU, frame-pacing or hitch checks.
"""
import argparse
import csv
import json
import math
from collections import defaultdict
from pathlib import Path


# Scope/rationale: docs/notes/m6w-budget-amendment-2026-09-25.md.
TOTAL_WATER_P95_MS = 6.0
TOTAL_WATER_P99_MS = 7.0


def total_water_pass(result):
    return (result["total_upper_p95_ms"] <= TOTAL_WATER_P95_MS
            and result["total_upper_p99_ms"] <= TOTAL_WATER_P99_MS)


def percentile(values, fraction):
    ordered = sorted(values)
    return ordered[max(0, math.ceil(len(ordered) * fraction) - 1)]


def read_csv(path):
    with path.open() as stream:
        return [{key: float(value) for key, value in row.items()} for row in csv.DictReader(stream)]


def require(condition, message):
    if not condition:
        raise ValueError(message)


def validate_case(directory, result):
    name = result["case"]
    frames = read_csv(directory / (name + "_frames.csv"))
    ticks = read_csv(directory / (name + "_ticks.csv"))
    require(len(frames) == result["frames"] and len(frames) > 0, name + ": frame count")
    require(len({row["process_frame"] for row in frames}) == len(frames), name + ": duplicate frame")
    require(len({row["physics_tick"] for row in ticks}) == len(ticks), name + ": duplicate tick")
    for rows, key in [(frames, "process_frame"), (ticks, "physics_tick")]:
        require(all(b[key] == a[key] + 1 for a, b in zip(rows, rows[1:])), name + ": missing/reordered " + key)
        signed = {"x", "y", "z", "velocity_x", "velocity_y", "velocity_z"}
        require(all(math.isfinite(value) and (value >= 0 or key in signed) for row in rows for key, value in row.items()), name + ": invalid number")
    if "end_usec" in frames[0]:
        require(all(b["end_usec"] - a["end_usec"] == b["frame_usec"] for a, b in zip(frames, frames[1:])),
                name + ": inconsistent frame clock")
    groups = defaultdict(list)
    for row in ticks:
        groups[row["process_frame"]].append(row)
    require(set(groups) <= {row["process_frame"] for row in frames}, name + ": unassociated tick")
    for row in frames:
        children = groups[row["process_frame"]]
        require(len(children) == row["physics_ticks"], name + ": ticks/frame")
        for column in ("controller", "runtime", "emitter", "coordinator", "wave_query"):
            key = column + "_usec"
            require(sum(child[key] for child in children) == row[key], name + ": component sum " + key)
        require(row["wave_query_usec"] <= row["controller_usec"], name + ": nested query exceeds controller")
        total = sum(row[key + "_usec"] for key in ("controller", "runtime", "emitter", "coordinator", "effects_upper", "audio_upper", "hud", "flat"))
        require(total == row["total_upper_usec"], name + ": overlapping/missing total")
        if "total_mixed_upper_usec" in row:
            mixed = total - row["effects_upper_usec"] - row["audio_upper_usec"] + row["effects_all_usec"] + row["audio_all_usec"]
            require(mixed == row["total_mixed_upper_usec"] and mixed >= total, name + ": inconsistent mixed upper bound")
    columns = ["frame", "controller", "runtime", "emitter", "coordinator", "effects_upper", "audio_upper", "hud", "flat", "total_upper", "wave_query", "gpu", "render_cpu"]
    if "total_mixed_upper_usec" in frames[0]:
        columns += ["effects_all", "audio_all", "total_mixed_upper"]
    for column in columns:
        unit = "ms" if column in ("gpu", "render_cpu") else "usec"
        values = [row[column + "_" + unit] / (1 if unit == "ms" else 1000) for row in frames]
        for fraction in (.95, .99, 1):
            key = f"{column}_p{round(fraction * 100)}_ms"
            require(math.isclose(percentile(values, fraction), result[key], abs_tol=.000001), name + ": incorrect " + key)
    fps = len(frames) * 1e6 / sum(row["frame_usec"] for row in frames)
    require(math.isclose(fps, result["fps"], abs_tol=.000001), name + ": fps")
    tails = sum(row["frame_usec"] > 33300 for row in frames)
    require(tails == result["over_33ms"], name + ": omitted tails")
    require(result["gpu_valid"] == all(row["gpu_ms"] > 0 for row in frames), name + ": GPU validity")
    if "wave_work_p95_ms" in result:
        wave_work = [sum(row[key + "_usec"] for key in ("runtime", "emitter", "coordinator", "wave_query")) / 1000 for row in frames]
        for quantile in (95, 99):
            require(math.isclose(percentile(wave_work, quantile / 100), result[f"wave_work_p{quantile}_ms"], abs_tol=.000001), name + ": wave work attribution")
    total_pass = total_water_pass(result)
    frame_pass = fps >= 59 and result["frame_p95_ms"] <= 18.5 and result["frame_p99_ms"] <= 25
    print(f"{name}: total {result['total_upper_p95_ms']:.3f}/{result['total_upper_p99_ms']:.3f} ms p95/p99 "
          f"{'PASS' if total_pass else 'FAIL'} (Test Ground limits {TOTAL_WATER_P95_MS:g}/{TOTAL_WATER_P99_MS:g}); "
          f"frame {result['frame_p95_ms']:.3f}/{result['frame_p99_ms']:.3f} "
          f"{'PASS' if frame_pass else 'FAIL'}; {fps:.2f} fps, {tails} tails; GPU valid={result['gpu_valid']}")
    return frames, ticks


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("directory", type=Path)
    args = parser.parse_args()
    metadata = json.loads((args.directory / "metadata.json").read_text())
    results = json.loads((args.directory / "summary.json").read_text())
    options = metadata["options"]
    expected = int(options["rounds"]) * len(str(options.get("modes", "0,1,2")).split(",")) * (3 if options["car"] == "all" else 1)
    require(len(results) == expected, "incomplete case matrix")
    require(len({result["case"] for result in results}) == expected, "duplicate cases")
    for result in results:
        frames, _ = validate_case(args.directory, result)
        measured = sum(row["frame_usec"] for row in frames) / 1e6
        require(measured >= float(options["seconds"]) - .1, result["case"] + ": truncated interval")
    print(f"Verified {len(results)} cases. Subcheck only; this does not accept the whole milestone.")


if __name__ == "__main__":
    main()
