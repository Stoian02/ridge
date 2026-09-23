# M6A retest evidence

See `../m6a-performance-retest-2026-09-23.md` for interpretation and limits.
These are generated measurement artifacts, not gameplay recordings or saves.
Empty log-message lines have trailing spaces removed for repository whitespace
checks; no timings or messages were removed. CSV archives retain their raw data.

- `desktop-original/`: unchanged original benchmark, three rounds × two cars ×
  three command modes. `fixed` uses `--headless --fixed-fps 120 --max-fps 0`;
  `paced` uses `--headless`; `window` uses normal Vulkan Mobile rendering.
  All use `res://debug/water_benchmark.tscn -- car=<id>`, Godot 4.7.2,
  `DISPLAY=:1 WAYLAND_DISPLAY=wayland-1`, and isolated temporary save paths.
- Phone logs retain failed startup attempts and warnings, not just good samples.
- `phone-course.log` is only the latter half: Android's ring buffer rolled during
  that batch. `phone-course-csv.tar.gz` contains the complete 36-case summary and
  all 45,360 measured ticks. Later phone logs were streamed continuously.
- Acceptance raw CSVs use one row per completed physics tick. Timings are in
  microseconds; summaries use milliseconds. p95 uses nearest rank; each case
  retains its own p95, rather than pooling cars/locations to hide a slow case.
- Headless frame rates/rendering counters are not mobile rendering results.
- PNG captures are local artifacts under `build/`, not part of the CSV archive.

No runtime car, surface, water-force or level-geometry changes accompany this
audit. Only the measurement tools, their debug launcher and tests are new.

Extract either CSV archive to an empty directory, then independently check it:

```bash
python3 tools/check_water_measurements.py <course-directory> --limit-ms 0.50
python3 tools/check_water_measurements.py <views-directory>
```

The course command exits **2** because 34/36 cases exceed the limit; this is the
expected failed acceptance result. It also validates counts, consecutive tick
IDs, nearest-rank water p95 and maxima against the raw CSVs. Without a limit it
checks data consistency only, not acceptance. Frame statistics are summaries
only and are not independently revalidated from the water CSVs.

To rerun the phone acceptance harness, build/install the current checkout while
the owner is not playing. Put `{"mode":"course","rounds":3}` in a local JSON
file, then run:

```bash
adb shell run-as com.ridge.game tee files/water_acceptance < /path/to/options.json
tools/android.sh run
```

Use `"mode":"views"` for the five creek/rut/ford placements. The debug launcher
consumes the flag; gameplay defaults and saves are not edited. Results are in
`files/water_acceptance_results` (CSV, JSON and PNG). Pull them before another
mode overwrites `summary.json`. Stream logcat during the run: the Android ring
buffer did not retain the complete long course session. Do not substitute
`--fixed-fps`/uncapped desktop mode for these real-time device measurements.
