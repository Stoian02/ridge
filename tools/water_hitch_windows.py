#!/usr/bin/env python3
"""Generate trace-specific Perfetto SQL from validated WaterHitchTrace CSVs.

Select every >33.3ms frame, each case maximum, each real transition frame,
and >5ms physics-callback spans. Selection is diagnostic, not an acceptance
threshold. Explicit PID/TID and matching per-case logcat clocks are required;
never combine identically named Vulkan threads. Verify clock offset/spread,
parser statistics and accounted spans before interpreting the output.
"""
import argparse
from decimal import Decimal
import json
from pathlib import Path
import re

from analyze_water_hitch import event_context, rows


def clocks(text, pid, tid):
    found = {}
    pattern = re.compile(r"\s(\d+)\s+(\d+)\s+I\s+godot\s*:\s*water hitch clock (\{.*\})")
    for line in text.splitlines():
        match = pattern.search(line)
        if not match:
            continue
        if (int(match[1]), int(match[2])) != (pid, tid):
            continue
        value = json.loads(match[3], parse_float=Decimal)
        name = value["case"]
        if name in found:
            raise ValueError(f"duplicate clock for {name}")
        found[name] = int(Decimal(value["unix_seconds"]) * 1_000_000_000) - int(value["ticks_usec"]) * 1000
    if not found:
        raise ValueError("no clocks for the specified game PID/TID")
    return found


def windows(directory, anchors, realtime_offset_ns):
    result = []
    cases = json.loads((directory / "summary.json").read_text())
    names = [case["case"] for case in cases]
    if len(set(names)) != len(names) or not names:
        raise ValueError("empty or duplicate case list")
    for name in names:
        if name not in anchors:
            raise ValueError(f"missing matching clock for {name}")
        ticks = rows(directory / f"{name}_hitch_ticks.csv")
        frames = rows(directory / f"{name}_hitch_frames.csv")
        context = event_context(ticks, frames)
        selected = {int(frame["frame"]): frame for frame in context["all_long_frames"]}
        maximum = context["maximum_frame"]
        selected[int(maximum["frame"])] = maximum
        for event in context["transition_windows"]:
            frame = event["frame"]
            if frame is not None:
                selected[int(frame["frame"])] = frame
        shift = anchors[name] - realtime_offset_ns
        for frame_id, frame in sorted(selected.items()):
            end = int(frame["end_usec"]) * 1000 + shift
            span = int(frame["interval_usec"]) * 1000
            if span > 0:
                result.append((f"{name}/frame/{frame_id}", end - span, end))
        for tick in ticks:
            if tick["physics_callbacks_usec"] <= 5000:
                continue
            end = int(tick["end_usec"]) * 1000 + shift
            span = int(tick["physics_callbacks_usec"]) * 1000
            result.append((f"{name}/physics/{int(tick['tick'])}", end - span, end))
    return result


def sql(intervals, pid, tid, offset):
    if not intervals:
        raise ValueError("no intervals")
    values = ",\n".join(f"('{label.replace(chr(39), chr(39)*2)}',{start},{end})"
                         for label, start, end in intervals)
    return f"""-- Generated from validated samples; original trace and matching logcat required.
-- Game pid={pid}, tid={tid}; explicit REALTIME-BOOTTIME offset={offset}ns.
-- Per-case JSON timestamps have microsecond-scale precision, not nanosecond.
SELECT name,value FROM stats WHERE severity != 'info' AND value > 0;
SELECT COUNT(*) snapshots, MIN(clock_value-ts) min_offset_ns,
       MAX(clock_value-ts) max_offset_ns,
       MAX(clock_value-ts)-MIN(clock_value-ts) spread_ns
FROM clock_snapshot WHERE clock_name='REALTIME';
SELECT t.utid,t.tid,t.name,p.pid,p.name process FROM thread t JOIN process p USING(upid)
WHERE p.pid={pid} AND t.tid={tid};
CREATE PERFETTO TABLE hitch_windows AS
WITH windows(label,a,b) AS (VALUES {values}) SELECT * FROM windows;
WITH clipped AS (
 SELECT w.label,w.a,w.b,s.state,MIN(s.ts+s.dur,w.b)-MAX(s.ts,w.a) span
 FROM hitch_windows w JOIN thread_state s ON s.ts<w.b AND s.ts+s.dur>w.a
 JOIN thread t USING(utid) JOIN process p USING(upid)
 WHERE t.tid={tid} AND p.pid={pid} AND s.dur>0
)
SELECT label,ROUND((MAX(b)-MIN(a))/1e6,6) wall_ms,
 ROUND(SUM(CASE WHEN state='Running' THEN span ELSE 0 END)/1e6,6) running_ms,
 ROUND(SUM(CASE WHEN state IN ('R','R+') THEN span ELSE 0 END)/1e6,6) runnable_ms,
 ROUND(SUM(CASE WHEN state='S' THEN span ELSE 0 END)/1e6,6) sleeping_ms,
 ROUND(SUM(CASE WHEN state NOT IN ('Running','R','R+','S') THEN span ELSE 0 END)/1e6,6) other_ms,
 ROUND(SUM(span)/1e6,6) accounted_ms
FROM clipped GROUP BY label ORDER BY label;
-- Missing rows or nonzero coverage error invalidate those intervals.
SELECT w.label,(w.b-w.a)-COALESCE(SUM(MIN(s.ts+s.dur,w.b)-MAX(s.ts,w.a)),0) uncovered_ns
FROM hitch_windows w LEFT JOIN thread_state s
 ON s.ts<w.b AND s.ts+s.dur>w.a AND s.dur>0 AND s.utid IN (
  SELECT t.utid FROM thread t JOIN process p USING(upid) WHERE t.tid={tid} AND p.pid={pid})
GROUP BY w.label,w.a,w.b
HAVING ABS(uncovered_ns)>0;
"""


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("directory", type=Path)
    parser.add_argument("--clock-log", required=True, type=Path)
    parser.add_argument("--pid", required=True, type=int)
    parser.add_argument("--tid", required=True, type=int)
    parser.add_argument("--realtime-offset-ns", required=True, type=int)
    args = parser.parse_args()
    anchors = clocks(args.clock_log.read_text(), args.pid, args.tid)
    selected = windows(args.directory, anchors, args.realtime_offset_ns)
    print(sql(selected, args.pid, args.tid, args.realtime_offset_ns))


if __name__ == "__main__":
    main()
