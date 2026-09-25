# M6W completion — owner-authorized continuation, 2026-09-25

The owner approved correcting the measurements and finishing this milestone,
with focused commits and documentation for a whole-milestone Claude review.
Here “this milestone” means M6W, not Coastal Highway. The previously accepted
Test Ground prototype remains the only live binding; no merge/push, timed-level
rollout, car/surface tuning or geometry changes are included.

## Sequence

1. Preserve the completed diagnosis separately (`17ccc98`).
2. Correct measurement coverage and protocol, with independently checked CSVs.
3. Measure the steady-state phone workload; optimize only a demonstrated cost,
   retaining exactly the same surface, source strengths and current-tick queries.
4. Complete behaviour/lifecycle tests, GPU parity and phone stress/soak checks.
5. Run the full regression, retain failed attempts as well as final evidence,
   update the milestone report and leave focused commits for review.

## Corrected protocol

- Fresh APK; record source state, local/installed APK hashes, device/renderer,
  resolution, physics rate, save hash, temperatures and configuration.
- Warm the app for **60 seconds** before collecting cases. Use equal **10-second
  per-case** warm-ups. No manual input during measurements. Rotate Off / Car waves
  / Full order across rounds; retain every individual case, not a pooled result
  that hides a late slowdown. Short desktop smoke runs are explicitly not gates.
- Record actual physics ticks grouped by rendered process frame. Total CPU is
  controller + field/snapshot/upload + emitter + coordinator + flat-water
  animation + feedback/audio + water HUD. Query cost is a nested controller
  subset, never added twice. Use the **whole mixed dry/wet effects and audio
  callbacks as a conservative upper bound**, clearly labelled; neither nested
  WaterEffects nor water audio is counted again. Rendering-server/Jolt/audio
  worker execution is outside the script CPU sum and covered by whole-frame
  timings and renderer GPU timings, not mislabelled as script CPU.
- Recorder v2 additionally times the water-specific effects/audio regions,
  including shared wet-spray submission and the complete wet/dry tyre-audio mix
  conservatively. Dry-only wheel-motion/engine/road updates are excluded from
  that total; the original **whole mixed-callback upper bound remains a separate
  CSV field** for like-for-like before/after comparisons. This is finer
  attribution, not an optimization or a changed budget.
- Frame records include p95/p99, all >33.3 ms tails, separate component values,
  renderer timing validity, draw calls/primitives and case-relative tick phase.
  Export/readback happens outside the measured window. Reject incomplete or
  internally inconsistent output. Engine GPU counters have backend-dependent
  latency and are case distributions, not tick-correlated attribution.
- Start with steady-state comparison/stress before spending time on the full
  matrix. Final coverage follows spec §9: three cars, balanced repeated cases,
  matched replay and live driving, bounded-source saturation, five-minute soak,
  lifecycle/setup repeats and real-renderer parity. Record unavailable or failed
  checks as such, never as acceptance passes.

## Amended acceptance — owner approval, 2026-09-25

Provisional **Test Ground** total-water CPU ceilings are **6 ms/frame p95,
7 ms/frame p99**, replacing 4/5 in this scope. The incremental wave CPU
0.50/1.0 ms p95/p99 figures are retained as reported optimization targets, not
another blocking gate. See `m6w-budget-amendment-2026-09-25.md` for rationale,
unchanged raw results and limitations. Defer the proposed native/C++ path.

The full spec's frame/GPU/setup/memory and drawing gates remain in force. The
historical M6A hitch stays open unless its evidence supports closure. Owner
approval to finish implementation or change a budget does not mean the owner
has accepted every behaviour or that final phone gates have passed. This is
not a blanket budget change for timed levels or Coastal Highway.

## Remaining work after the budget decision

1. Finish the final-source phone matrix: balanced repeated Off/Car waves/Full
   cases across all cars, 60-second matched replays, separate live driving,
   three saturation rounds and at least five minutes of warmed Full operation.
   Retain every case and investigate tails; no pooling away slow late cases.
2. Complete phone GPU comparisons/parity and repeated preparation/lifecycle
   checks (mode switches, pause, Reset, car change and scene exit/re-entry).
   Review existing automated coverage and fix only demonstrated remaining gaps.
3. Retain the complete implementation/verification evidence, reconcile the
   original historical task checklists with delivered commits, and finish the
   milestone report. Re-run affected checks/full regression if runtime changes.
4. Hand the final Test Ground build to the owner and Claude for whole-milestone
   review. No merge, rollout or Coastal Highway without the next decision.
