# M6W completion evidence — 2026-09-25

Completed verification for owner/Claude review; see the current section of
`../codex-report-m6w-waves.md`. No archived run is an implicit pass. In particular,
CPU and GPU gate failures and all three untraced >33.3 ms frames are retained.

## Earlier implementation evidence

- `optimization-phone.tar.gz`: the corrected baseline (`5203e46`), intermediate
  height-only experiment, and optimized (`3dcf4eb`) phone batches. Original
  validation output uses the then-current 4/5 ms policy and is retained unchanged.
  Normal `results.tar` transport copies are excluded because their extracted
  CSV/JSON/PNG content is present. The failed/truncated baseline `exec-out` export
  is preserved separately inside the baseline folder, alongside the successful
  `adb shell -T` re-export.
- `implementation-checks.tar.gz`: the preceding import/build/focused-test,
  real-GPU parity and full-regression logs through `f56b62b`, including failed
  or limited attempts and native audio-release warnings. These predate the new
  phone lifecycle audit and are not a substitute for its final regression.
- The final `f56b62b` 30-second candidate/saturation subchecks are already in
  `../m6w-budget-amendment-data/phone-subchecks.tar.gz`; do not silently overwrite
  their original failures after changing the policy.

The intermediate height-only APK is exploratory: its local/installed hashes
match, but the launch-time working-tree patch contains later harness edits made
after that export. Do not treat it as a clean source-pinned acceptance build.
The optimized/candidate builds have clean recorded build revisions/patches.
Neither code optimizations nor the later feedback-scope refinement can be
credited with the whole before/after difference across differently timed runs.

## Final verification evidence

- `final-matrix.tar.gz`: all 27 normally paced 60-second replay cases on clean
  `18a4d4e`, APK/local-installed hashes, source state, save hashes, each raw CSV,
  per-case screenshots and summaries, independent validation/report, host-side
  stream from before launch through completion and sampled thermal/frequency
  observations. Recorder v2: no frame-end clock anchors, therefore no exact
  scheduling attribution for its one 36.583 ms frame. This archive retains CPU
  and GPU failures; 60 FPS does not turn them into passes.

The later opt-in verification commit `f0c033b` adds lifecycle coverage, live
shallow/exit fixtures and recorder v3 trace clocks; production water/car/level
code is unchanged. Later batches record that revision and a documentation-only
working-tree patch, not an unstated runtime edit.

- `final-desktop-checks.tar.gz`: `f0c033b` full suite (799 passing, one inherited
  pending, no SCRIPT ERROR, exit 0), real-GPU parity, focused lifecycle and
  Python checks, export/build provenance and unchanged protected-file checks.
  Includes the first audit's type-inference parse errors and corrected rerun,
  plus the sandbox socket-limited import and successful unrestricted rerun.
  No failure log was replaced by its later passing result.
- `final-stress-and-lifecycle.tar.gz`: both nine-cycle real-control phone audits
  and all nine rotated maximum-source/refined-flat cases on `f0c033b`. The
  original host launcher race is retained; game audit success is not confused
  with the wrapper's failed early fetch. Complete continuous batch logging and
  sampled thermal state are retained with the remaining batch evidence.

All-top stress Full ticks have exactly 16 active slots; controls have zero.
This is a fixed-capacity saturation fixture, not naturally generated driving.
Mode 3 is a debug refined-flat surface, not an owner UI option or an ordinary
waves-Off baseline. Its GPU and one long frame must remain separately labelled.

- `final-live.tar.gz`: all nine unfrozen-car/mode cases, each 108 seconds;
  raw samples, summaries, PNGs, validation, per-case report and descriptive
  eight-segment trajectory breakdown. Includes the script that reproduces that
  breakdown. Initial 3/8/15 m/s is followed by normal forces/input, not a
  constant-speed drive. The recovery segment initializes a stalled engine.
  All reset-boundary frames remain in the primary statistics and tail list;
  only the descriptive per-segment breakdown excludes 0.1 s near each boundary.
  Different trajectories are not a matched-GPU acceptance comparison.

- `final-soak-parity-and-host.tar.gz`: three 300-second Full live soaks, their
  raw samples and per-segment coverage; final Android GPU parity logs; complete
  successful batch stream, thermal/frequency observations, device/build/save
  checks, host runner/configs and trace-analysis scripts/SQL/output. No >33.3 ms
  frame recurred in this separately traced soak. The trace analysis includes
  each case's maximum below that threshold without relabelling it a hitch.

## Trace provenance and limitations

Full system trace is **local-only**, outside git:
`runs/m6w-completion-data/final-soak.pftrace.gz` (129 MiB compressed), with the
original raw copy also retained at `/tmp/ridge-m6w-final-soak.pftrace`.

- Raw SHA-256: `6bc92753bf9a9649881e0f40ed911c432e4c171fa60140d954bf44491362df33`.
- Gzip SHA-256: `06b23d3e604a32b3a4ca309bb0ebb8689487e567b84309d206f503974ea6c8ee`.
- Official Perfetto v58.2 trace processor SHA-256:
  `58042408e6cc861fb1a731c26bb082dc222285561eaa4e12a48a8b2b90dca7b9`.
- The phone's temporary trace file was removed only after its hash matched the
  local raw file and gzip integrity passed. No save, app results or caches were
  removed. Local copies retain recoverability.

Repeat with the archived `soak-windows.sql` and the matching trace:

```sh
trace_processor query -f soak-windows.sql final-soak.pftrace.gz
```

Or regenerate the SQL using the archived script and exported soak directory:

```sh
python3 ridge-m6w-trace-windows.py <soak run> --include-max --tid 14678 > windows.sql
```

TID 14678 / PID 14498 belongs **only to this capture**, established from the
contemporaneous Godot logcat. Three Vulkan threads share the `VkThread` name.
The first exploratory name-only query incorrectly summed all three and is
retained with `NOT-game-thread` in its filename; do not use it as evidence about
one thread. The corrected output selects the actual game TID and checks the
summed state intervals equal each complete frame duration. Clock-offset spread
is 781 ns across 1,202 snapshots, but JSON anchors have microsecond-scale
precision. R/R+ measures runnable waiting, S does not by itself identify a wait
reason. These whole-frame windows neither identify call stacks nor explain the
three **untraced** earlier spikes. No hitch fix is claimed.

## Integrity

From this evidence directory, run `sha256sum -c SHA256SUMS` before extraction.
Raw archive contents and original verdicts are not rewritten when the current
checker or budget changes. Transport `results.tar` duplicates are omitted only
where the complete extracted CSV/JSON/PNG data is retained.

The original mixed dry/wet callback total and the finer water/shared-region
total are separate columns. Controller-only historical playchecks are narrower
still. Preserve those distinctions when comparing reports.

## Tools

After extracting a batch into a fresh temporary directory:

```sh
python3 -B tools/check_wave_acceptance.py <batch>/wave_acceptance_results/<tag>
python3 -B tools/report_wave_acceptance.py <batch>/wave_acceptance_results/<tag>
python3 -B -m unittest discover -s tools -p 'test_*wave_acceptance.py'
```

The validator rejects corrupt/incomplete data but returns success for valid
evidence even when numeric gates print FAIL. The report tool pairs GPU values
by car/round, retains every frame tail and does not pool slow cases into a pass.
