#!/usr/bin/env python3
"""Review per-case water gates and paired GPU deltas from validated exports.

Usage: python3 tools/report_wave_acceptance.py <run directory> [<run directory> ...]
This is evidence reporting, not automatic milestone acceptance. No case pooling.
CPU scope/limits are inherited from check_wave_acceptance.py; GPU/frame/setup/
drawing gates are unchanged. A GPU difference is between matched case p95s,
not the p95 of per-frame incremental GPU work (counters are backend-delayed).
"""
import argparse
import contextlib
import io
import json
from pathlib import Path

from check_wave_acceptance import TOTAL_WATER_P95_MS, TOTAL_WATER_P99_MS, require, total_water_pass, validate_case


def gpu_pairs(results):
    groups = {}
    for row in results:
        key = (row["car"], row["round"])
        require(row["mode"] not in groups.setdefault(key, {}), "duplicate mode in GPU pair")
        groups[key][row["mode"]] = row
    pairs = []
    for (car, round_index), modes in groups.items():
        if 0 not in modes:
            continue
        for mode in (1, 2, 3):
            if mode not in modes:
                continue
            off, on = modes[0], modes[mode]
            valid = off["gpu_valid"] and on["gpu_valid"]
            delta = on["gpu_p95_ms"] - off["gpu_p95_ms"]
            pairs.append(dict(car=car, round=round_index, mode=mode, valid=valid,
                              delta_p95_ms=delta, inside_allocation=valid and delta <= .5))
    return pairs


def report(directory):
    results = json.loads((directory / "summary.json").read_text())
    metadata = json.loads((directory / "metadata.json").read_text())
    options = metadata["options"]
    expected = int(options["rounds"]) * len(str(options.get("modes", "0,1,2")).split(",")) * (3 if options["car"] == "all" else 1)
    require(len(results) == expected, "incomplete matrix")
    require(len({row["case"] for row in results}) == expected, "duplicate cases")
    print(f"\n## {directory.name}: {options}\n")
    print(f"CPU policy: Test Ground {TOTAL_WATER_P95_MS:g}/{TOTAL_WATER_P99_MS:g} ms p95/p99. "
          "Modes: 0 Off, 1 Car waves, 2 Full, 3 debug refined-flat.\n")
    print("Feedback scope:", metadata.get("feedback_scope", "legacy whole mixed callback upper bound"), "\n")
    print("| Case | Water p95/p99 ms | CPU | Frame p95/p99 ms | FPS | Frame | Max ms / tails | GPU p95 | Draws / primitives max | Setup ms |")
    print("| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |")
    tails = []
    for result in results:
        with contextlib.redirect_stdout(io.StringIO()):
            frames, ticks = validate_case(directory, result)
        require(sum(frame["frame_usec"] for frame in frames) / 1e6 >= float(options["seconds"]) - .1,
                result["case"] + ": truncated interval")
        cpu = "PASS" if total_water_pass(result) else "FAIL"
        frame_pass = result["fps"] >= 59 and result["frame_p95_ms"] <= 18.5 and result["frame_p99_ms"] <= 25
        draw_max = max(frame["draws"] for frame in frames)
        primitive_max = max(frame["primitives"] for frame in frames)
        drawing = "" if draw_max < 150 and primitive_max < 300000 else " FAIL"
        preparation = result["preparation_usec"] / 1000
        setup = "" if preparation <= 250 else " FAIL"
        print(f"| {result['case']} | {result['total_upper_p95_ms']:.3f}/{result['total_upper_p99_ms']:.3f} | {cpu} "
              f"| {result['frame_p95_ms']:.3f}/{result['frame_p99_ms']:.3f} | {result['fps']:.3f} "
              f"| {'PASS' if frame_pass else 'FAIL'} | {result['frame_p100_ms']:.3f} / {result['over_33ms']} "
              f"| {result['gpu_p95_ms']:.3f} | {draw_max:.0f} / {primitive_max:.0f}{drawing} | {preparation:.3f}{setup} |")
        for frame in frames:
            if frame["frame_usec"] <= 33300:
                continue
            children = [tick for tick in ticks if tick["process_frame"] == frame["process_frame"]]
            tails.append(dict(case=result["case"], frame=frame, ticks=children,
                              clock_anchor=result.get("clock_anchor")))
    print("\nMatched-case GPU p95 differences versus Off (unchanged +0.50 ms allocation):")
    if options["fixture"] == "live":
        print("LIVE trajectories differ: these differences are descriptive, NOT matched-pose GPU acceptance.")
    for pair in gpu_pairs(results):
        print(f"- {pair['car']} round {pair['round']} mode {pair['mode']}: {pair['delta_p95_ms']:+.3f} ms "
              f"({'inside' if pair['inside_allocation'] else 'outside/unavailable'}); valid={pair['valid']}")
    print("\nRetained >33.3 ms frame/tick records (correlation only, not cause):")
    print(json.dumps(tails, indent=2))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("directories", nargs="+", type=Path)
    args = parser.parse_args()
    for directory in args.directories:
        report(directory)


if __name__ == "__main__":
    main()
