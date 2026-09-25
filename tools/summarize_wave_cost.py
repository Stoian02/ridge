#!/usr/bin/env python3
"""Read opt-in wave cost CSVs. Attribution only, never an acceptance pass."""
import argparse
import csv
import json
import math
from collections import defaultdict
from pathlib import Path


def percentile(values, fraction):
    ordered = sorted(values)
    return ordered[max(0, math.ceil(len(ordered) * fraction) - 1)]


def summarize(path):
    with path.open() as stream:
        rows = [{key: float(value) for key, value in row.items()}
                for row in csv.DictReader(stream)]
    assert len(rows) == 600, (path, len(rows))
    assert all(math.isfinite(v) and v >= 0 for row in rows for v in row.values())
    assert len({row['tick'] for row in rows}) == len(rows)
    assert all(b['tick'] == a['tick'] + 1 for a, b in zip(rows, rows[1:]))
    for row in rows:
        assert row['requests'] * 3 == row['vertices'] + row['cache_hits']
        assert row['same_frame_repeats'] <= row['vertices']
        assert row['ambient_usec'] + row['packet_usec'] + row['bow_usec'] <= row['raw_usec']
    frames = defaultdict(list)
    for row in rows:
        frames[int(row['frame'])].append(row)
    # Boundary frames can contain only part of the capture; retain and report
    # the histogram, but compare a fixed two-tick workload for attribution.
    selected = [group for group in frames.values() if len(group) == 2]
    histogram = defaultdict(int)
    for group in frames.values():
        histogram[len(group)] += 1
    result = {'path': str(path), 'ticks': len(rows), 'frame_tick_histogram': dict(histogram)}
    columns = [key for key in rows[0] if key not in ('tick', 'frame')]
    for key in columns:
        values = [sum(row[key] for row in group) for group in selected]
        result[key] = {'mean': sum(values) / len(values),
                       'p50': percentile(values, .5), 'p95': percentile(values, .95),
                       'p99': percentile(values, .99), 'max': max(values)}
    return result


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('directory', type=Path)
    args = parser.parse_args()
    paths = sorted(args.directory.rglob('cost_mode_*.csv'))
    if not paths:
        parser.error('no cost_mode CSVs found')
    print(json.dumps([summarize(path) for path in paths], indent=2))
