# Hitch evidence re-analysis, 2026-09-26

This is an **offline audit of retained phone captures**, not a new phone run.
See [the partial investigation report](../codex-report-hitch.md). Game behaviour
and performance gates are unchanged; fresh phone reproduction is pending.

`offline-audit.tar.gz` contains:

- `transition-audit.json`: all 24 September 24 cases, every >33.3 ms frame,
  transition-containing frames, ±250 ms overlapping-frame windows, state tick
  counts and net monitor changes (not allocation churn).
- `expanded-windows.sql`, `expanded-scheduling.txt`, `expanded-loader.log`:
  69 windows, actual PID/TID, parser/clock/coverage checks and scheduling totals.
- `rechecked-original-scheduling.txt`, `rechecked-original-loader.log`:
  re-execution of the original committed fixed-window SQL.
- `historical-frames.json`: direct extraction of the named four historical
  cases, retaining all their >33.3 ms rows including the M6A 67.294 ms event.
- `python-tests.log`: all 42 tool tests passing.
- `source-identities.txt`: original evidence archives, exact trace and reader
  identities. Original source evidence is not copied or overwritten.

The system trace remains local-only at
`runs/m6w-review-data/all-cars.pftrace.gz`; this is not uploaded or added to git.
If missing on another checkout, request it before claiming independent scheduling
verification. The matching CSVs and metadata are committed under
`docs/notes/m6w-review-data/`. The historical M6W/M6A archive paths are in
`historical_rows.py` and its output.

## Repeat without running the game

From the repo root, extract into a fresh temporary directory (do not overwrite
an existing capture). These commands never start Godot or access the phone:

```sh
audit_dir=$(mktemp -d /tmp/ridge-hitch-audit.XXXXXX)
tar -xzf docs/notes/m6w-review-data/all-cars-csv.tar.gz -C "$audit_dir"
tar -xzf docs/notes/m6w-review-data/hitch-metadata.tar.gz -C "$audit_dir"
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tools -p 'test_*.py'
PYTHONDONTWRITEBYTECODE=1 python3 tools/analyze_water_hitch.py "$audit_dir"
PYTHONDONTWRITEBYTECODE=1 python3 docs/notes/hitch-investigation-data/historical_rows.py
gzip -dc runs/m6w-review-data/all-cars.pftrace.gz > "$audit_dir/all-cars.pftrace"
PYTHONDONTWRITEBYTECODE=1 python3 tools/water_hitch_windows.py "$audit_dir" \
  --clock-log "$audit_dir/all-cars/logcat.txt" --pid 1094 --tid 1195 \
  --realtime-offset-ns 1789885938447045119 > "$audit_dir/windows.sql"
```

Use the official Perfetto v58.2 Linux-amd64 `trace_processor_shell`, SHA256
`58042408e6cc861fb1a731c26bb082dc222285561eaa4e12a48a8b2b90dca7b9`:

```sh
trace_processor_shell query -f "$audit_dir/windows.sql" "$audit_dir/all-cars.pftrace"
trace_processor_shell query -f tools/water_hitch_trace.sql "$audit_dir/all-cars.pftrace"
```

The download used is the official
[v58.2 artifact](https://commondatastorage.googleapis.com/perfetto-luci-artifacts/v58.2/linux-amd64/trace_processor_shell).
For a new capture, derive its own clocks and game PID/TID; **never reuse these
identifiers/offsets merely because the thread is also named `VkThread`**.
Nonempty parser-error or uncovered-window output invalidates attribution of
the affected data. Sleeping is not equivalent to runnable scheduler delay.

No fresh full Godot suite, phone timing, APK installation, GPU run or fix is
claimed. Initial download required network approval after a sandbox DNS failure;
the downloaded reader was hash-verified before execution. The large trace was
only decompressed locally and no phone data was deleted.
