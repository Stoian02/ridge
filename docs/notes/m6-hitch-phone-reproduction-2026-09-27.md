# The water hitch: phone reproduction and what it shows (2026-09-27)

Run by Claude on the owner's Xiaomi 13, executing the procedure in
`docs/notes/codex-report-hitch.md` §5. Branch `m6-hitch` at `c84bc29`, built and
installed fresh. Waves are Off throughout — this is the M6A water path.

**Conclusion: the recorded tails are overwhelmingly a measurement-start
artefact, and the one genuine warmed-state tail shows identical work taking
twenty times longer, which is a platform effect rather than game work.**

## Method

`debug/water_acceptance.tscn` in course mode with `trace=1`, which drives all
three cars through shallow 5 cm, shallow 30 cm, calm deep and current deep
placements while `WaterHitchTrace` records every physics tick and every rendered
frame. Twenty-five traced cases were available after this run, **291 seconds and
17,480 frames** in total.

```sh
adb shell "run-as com.ridge.game sh -c 'printf \"{\\\"mode\\\":\\\"course\\\",\\\"rounds\\\":1,\\\"trace\\\":1}\" > files/water_acceptance'"
adb shell monkey -p com.ridge.game -c android.intent.category.LAUNCHER 1
```

## Finding 1: thirteen long frames, twelve of them at case start

Thirteen frames exceeded 33.3 ms — one every 22 seconds of measurement. Their
distribution is the opposite of a water-cost explanation:

| Placement | Long frames | Measured | Rate |
| --- | ---: | ---: | --- |
| shallow 5 cm | 7 | 35.6 s | one every 5 s |
| shallow 30 cm | 2 | 35.4 s | one every 18 s |
| calm deep | 2 | 118.4 s | one every 59 s |
| current deep | 2 | 101.4 s | one every 51 s |

The **shallowest** water produces them ten times more often than the deep pools.
Shallow 5 cm is also the **first placement in every car's sequence**.

Placing each spike within its own case settles it: **twelve of the thirteen
occur in frames 2–3 of the case, within 0.10 s of measurement starting.** Only
one occurs in warmed steady state, 10.26 s into a case.

In every one of the thirteen, all instrumented game script — water, effects,
audio, status and every script callback — accounts for **2.9 to 12.1 ms of
intervals lasting 33 to 60 ms**. Between 70% and 95% of each spike is outside
game script entirely.

## Finding 2: the one warmed-state tail is the same work, twenty times slower

`2_offroad_4x4_current`, frame 10680, 38.60 ms. Its ticks:

| tick | water µs | body µs | query µs | queries | triangles | immersion | flooding | stalled | speed |
| ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 21508 | 497 | 278 | 283 | 13 | 52 | 1.00 | 0.91 | 1 | 0.01 |
| 21509 | 476 | 262 | 276 | 13 | 52 | 1.00 | 0.91 | 1 | 0.01 |
| **21510** | **9872** | **9684** | **5511** | 13 | 52 | 1.00 | 0.91 | 1 | 0.02 |
| 21511 | 835 | 202 | 225 | 13 | 52 | 1.00 | 0.91 | 1 | 0.02 |
| 21512 | 368 | 205 | 199 | 13 | 52 | 1.00 | 0.91 | 1 | 0.02 |

**Identical inputs**: the same 13 queries, the same 52 triangle tests, the same
immersion, flooding, stall and contact state, at walking pace. The work did not
grow; it took twenty times longer to perform. No state transition occurs on that
tick — the car has been flooded and stalled for some time already.

That is the signature of the thread being descheduled or the CPU changing
frequency mid-tick. It matches the earlier Perfetto finding of the game thread
runnable but off CPU, now with the workload held constant as a control.

## Finding 3: my own earlier hypothesis was wrong

On 2026-09-24 I reported the tails occurred "only in the deep pools, only when
fully flooded and stalled, and only with the two rally cars", from two spikes in
a small sample. With 25 traced cases that does not hold:

- they occur with **all three cars**, including the 4x4 that never stalls;
- the worst of them (59.64 ms) is the **4x4 in 5 cm of water**;
- they are **most** frequent in the shallowest, least watery placement.

The pattern I saw was the first-case warm-up effect, sampled too narrowly.
Treat the flooded/stalled lead as closed.

## What this does and does not establish

It does establish, for the current build on this device, that the long frames in
these harnesses are dominated by case-start cost and that warmed running shows
about **one long frame per five minutes**, whose profile is constant work
running slowly. That is consistent with the owner's experience: sustained 60 fps
with nothing visible in play.

It does not retroactively explain the historical untraced tails, including the
79.459 ms and 67.294 ms frames in the September 23 M6A data — those were
recorded on a different build with different instrumentation and are not
reproduced here. It is not a Perfetto attribution of these specific frames: the
constant-workload evidence is inferential, strong but indirect. And one
warmed-state tail per five minutes is a rarity, not a proof of zero.

## Recommendation

Close the hitch as platform behaviour on this evidence, record the residual rate
honestly, and stop treating it as a blocker for M6A and M6W acceptance. If a
stricter answer is wanted later, the cheap next step is a streaming Perfetto
capture during this same traced course run, correlating the one warmed-state
tail per case to on-CPU versus runnable-off-CPU time — the tooling for that
already exists under `runs/m6w-review-data/`.

Raw data for this run is under the scratchpad pull of
`files/water_acceptance_results`; the phone retains it until the next harness
run. No production code changed; no merge or push.
