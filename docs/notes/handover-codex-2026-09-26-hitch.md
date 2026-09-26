# Handover to Codex — find the water hitch (2026-09-26)

Written by Claude after reviewing the completed M6W package. One job this time:
**explain the long frames.** Not waves, not Coastal Highway, not merging.

Read `docs/notes/handover-2026-09-17-rock-canyon.md` for the repo rules, which
still apply in full.

Starting point: `m6-water-waves` at `7a2afb2`. Claude independently re-ran the
full suite there — **799 passing, one inherited pending, no `SCRIPT ERROR`** —
and the protected geometry and car-balance fixtures pass unchanged.

## 1. Why this is the next piece of work

Milestone 6 now has two finished, unmerged branches stacked on each other —
`m6a-water-physics` and `m6-water-waves` — and Coastal Highway is blocked behind
both. The single thing preventing M6A's acceptance, and the only defect the
owner's review of M6W did not clear, is the same one: **rare long frames around
water that nobody has explained.** Everything else has either passed or been
consciously accepted.

The owner has played the current build on the phone and reported it feels good
with no visible problems at 60 fps. So this is not a "the game feels broken"
task. It is a "we do not know why this happens, and we should not merge two
milestones on top of an unexplained stall" task.

## 2. What is actually known

Four long frames have been recorded across all the water work. **Their evidence
points in different directions, and that is the most important fact here.**

| Frame | Where | Water's share | What it suggests |
| --- | --- | --- | --- |
| 79.459 ms | M6A current pool, phone retest | not attributed | unknown |
| 53.558 ms | M6W **refined flat control** | control case, no car waves | not wave-caused |
| 35.656 ms | M6W 4x4 / Car waves | **2.170 ms of 35.7** | not water-caused |
| 36.583 ms | M6W rally / Car waves | **19.378 ms of 36.6** | water genuinely implicated |

Claude separately reproduced long frames on the phone in the M6A courses:
**46.657 ms** and **30.657 ms**, and those had a clear pattern — they occurred
only in the deep pools, only with a car **fully flooded and stalled**, and only
with the two rally cars. The 4x4, whose intake is high enough not to stall,
never exceeded 19.4 ms in the same runs.

A 20-minute Perfetto capture during the M6W soaks attributed two reproduced long
frames mainly to **the game thread being runnable but off CPU** — a scheduling
wait, not work the game was doing. That explanation was correctly *not*
projected onto the earlier untraced cases. Fifteen measured minutes of traced
soaking reproduced none of these tails at all.

Read, in this order: `docs/notes/m6a-independent-review-2026-09-24.md`,
`docs/notes/m6w-review-followup-2026-09-24.md`, and the hitch sections of
`docs/notes/codex-report-m6w-waves.md`.

## 3. The question to answer

**Is there one hitch, several, or none that belongs to us?**

The evidence is consistent with at least two different things wearing the same
costume: a platform scheduling wait that can strike any frame, and something
real in the flooded/stalled path. Do not assume a single cause, and do not
assume it is ours — but the 36.583 ms frame with 19.4 ms of water in it is not
explained by scheduling, and Claude's flooded-and-stalled pattern is too
specific to be noise.

Suggested line of attack, though your own will be better once you have looked:

1. **Reproduce deliberately.** Claude's pattern is the most specific lead: a
   rally car, a deep Test Ground pool, driven to fully flooded and stalled. If
   that reproduces long frames on demand, the problem becomes tractable.
   The 4x4 not stalling is the natural control.
2. **Instrument the transition, not the steady state.** The suspicion is that
   something happens *on entering or holding* the flooded/stalled state —
   allocation, an effect or audio restart, a resource load, a state machine
   doing work once — rather than the per-tick water maths, which is measured and
   modest. `debug/water_hitch_trace.gd` already records per-tick and per-frame
   water, effects, audio, status, object/node/resource counts and static memory:
   extend that rather than starting again.
3. **Separate the scheduling waits out.** A frame where the game thread was off
   CPU should be labelled as such and set aside, so the remaining frames are the
   ones worth explaining. The Perfetto method already used is the right tool.
4. **Only then decide whether anything needs fixing.** "This is the Android
   scheduler and here is the evidence" is a perfectly good answer, and it closes
   the prerequisite honestly. So is "here is the allocation, removed". What is
   not acceptable is raising a threshold until the tails fall below it.

## 4. What would close this

Either a demonstrated cause with a fix and a retest, or evidence-backed
attribution to the platform with the reasoning written down, so the owner can
accept M6A knowing what was and was not established. Say plainly which of the
four recorded frames your conclusion covers and which it does not.

If you find it is ours and the fix touches car code, stop and ask: `car/` and
`surfaces/*.tres` still need the owner's approval, and
`tests/scenarios/test_car_balance.gd` must keep passing unchanged.

## 5. Rules

- **Work on a branch off `m6-water-waves`** (that is where the newest tooling
  lives), named `m6-hitch`. **Do not merge. Do not push.**
- **Do not change wave feel, ambient values, car tuning, surfaces or level
  geometry** while chasing this. The owner has approved how it plays.
- **Never re-record** `test_geometry_fingerprints.gd` or
  `test_car_balance.gd`.
- **Stage files by name.** Never `git add -A` or `git add .`. Never touch
  `tmux-session.sh` or `project.godot`.
- **Do not run tests, benchmarks or captures while the owner is playing** —
  check `ps -eo pid,args | grep "godot --path ."` first, and never kill their
  process.
- Commit messages end with the repo's `Co-Authored-By` and `Claude-Session`
  trailers, with your own session link.
- Report honestly, as you have been: say what you could not establish, keep
  failed runs, and never claim a suite you did not run. Finish with
  `docs/notes/codex-report-hitch.md`.

## 6. Tooling

```sh
./run_tests.sh all                                  # about 8 minutes now
tools/android.sh build|install|run|logs
adb shell run-as com.ridge.game touch files/water_acceptance   # JSON opts: mode=course|views
adb shell run-as com.ridge.game touch files/wave_playcheck     # Off / Car waves / Full
adb shell run-as com.ridge.game touch files/water_benchmark
adb logcat -v time -s godot:V
```

`debug/water_hitch_trace.gd` is the per-tick/per-frame recorder;
`debug/water_measurement.gd` and `tools/check_water_measurements.py` validate
the CSVs independently. Previous Perfetto captures and their README are under
`runs/m6w-review-data/`.

## 7. The standing risk, for context

Two milestones are finished and unmerged, with a sixth level waiting behind
them. Every further branch stacked on this pile makes the eventual merge and its
review larger. That is a reason to resolve this cleanly and soon — not a reason
to rush the answer or to declare the hitch closed without evidence.
