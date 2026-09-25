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

## Unchanged acceptance

Absolute total-water CPU ceilings remain **4 ms/frame p95, 5 ms/frame p99**;
incremental budgets must fit inside them. The full spec's frame/GPU/setup/memory
and drawing gates remain in force. The historical M6A hitch stays open unless
its evidence supports closure. Owner approval to finish implementation does not
mean the owner has accepted every behaviour or that phone gates have passed.
