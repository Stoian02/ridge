# M6W — owner-approved Test Ground CPU budget amendment, 2026-09-25

## Decision and scope

After discussing whether sustained 60 FPS justified accepting more water CPU
cost, the owner explicitly approved the proposed **6 ms/frame p95 /
7 ms/frame p99** total-water ceiling and asked to record why. This replaces the
previous **4/5 ms** ceiling **provisionally on the Test Ground only**.

The former **0.50/1.0 ms p95/p99 incremental wave CPU** figures remain reported
optimization targets, not a second blocking gate. A total-water pass cannot be
claimed from incremental cost alone. The current per-frame measurement scope,
tick grouping, conservative shared feedback attribution and no-double-counting
rules are unchanged. These are percentile limits, not permission to omit maxima
or outliers.

Unchanged gates: average >=59 FPS, frame p95 <=18.5 ms / p99 <=25 ms, review every
>33.3 ms interval, incremental GPU p95 increase <=0.50 ms in matched views,
setup, memory, drawing and bounded-source limits. Reproducible wave-induced
hitches or unexplained clusters still block acceptance. The historical M6A
hitch remains open and separate.

No wave amplitude, appearance, sampling, physics, car tuning or level geometry
changes are authorized by this decision. Defer the proposed C++/GDExtension
path: it was an option for retaining 4 ms, not a demonstrated prerequisite for
smooth gameplay. This does not approve M6A/M6W acceptance, timed-level rollout,
Coastal Highway, a new native-code dependency, merge or push.

## Evidence behind the decision

Source: **f56b62bf48235de4251f73865162c699c714161b**, clean tracked tree, Xiaomi 13
(Adreno 740), Godot 4.7.2, 2400x1080, 120 Hz physics / 60 FPS cap. Local and
installed APK SHA-256 match:
`e6ce529c924a0ba3a08a79eb2c97bff780182b0db6b0a21cd134c1765af27e33`.

These are **existing measurements re-evaluated against a newly approved policy**,
not new phone runs or a performance improvement caused by raising the budget.
Each batch used 60 s app warm-up, 10 s settling per case and 30 s measurement,
one round, the 4x4 only. Replay is a frozen matched-pose cost fixture, not live
driving. Saturation holds all 16 travelling packets active plus bow and ambient
waves, with all water tops in view. The refined-flat control is debug-only.

| Existing case | Total water CPU p95 / p99 (ms) | Frame p95 / p99 (ms) | Average FPS | Frames >33.3 ms |
| --- | --- | --- | --- | --- |
| Replay Off | 2.530 / 2.866 | 17.669 / 18.470 | 60.005 | 0 |
| Replay Full | 4.415 / 4.775 | 17.985 / 18.630 | 60.019 | 0 |
| Saturation Off | 2.431 / 2.796 | 17.783 / 18.909 | 60.002 | 0 |
| Saturation Full | 5.938 / 6.341 | 17.897 / 18.711 | 60.020 | 0 |
| Saturation refined-flat | 3.886 / 4.574 | 17.920 / 18.770 | 60.022 | 0 |

Both Full cases failed the original CPU policy. Their original validation logs
remain unchanged in the retained evidence. The same samples meet the amended
CPU ceiling and unchanged whole-frame numeric checks, **not the complete phone
acceptance protocol**. `tools/check_wave_acceptance.py` now labels its applicable
Test Ground 6/7 policy explicitly; a valid-data exit is not milestone acceptance.

The reported total includes water-specific effects/audio regions with shared
wet spray and mixed tyre audio counted conservatively. The older whole mixed
dry/wet callback upper bound remains separate: Full replay p95 **4.735 ms**,
Full saturation **6.101 ms**. Do not compare these water-region totals against
older mixed-callback or controller-only numbers and claim the entire difference
is optimization. No counters or scope were changed by this budget amendment.

The wave-work attribution subtotals still miss the old optimization targets:
Full replay **2.253 / 2.475 ms p95/p99**, saturation **4.262 / 4.604 ms**.
These are per-frame sums of nested query plus external runtime/emitter/coordinator
work, already included in total water; do not add them again or derive them by
subtracting independently measured percentiles.

GPU remains an open check, not a waived pass: replay Off/Full GPU p95 was
**7.652 / 8.330 ms** (difference **0.678 ms**), saturation Off/Full
**8.667 / 9.572 ms** (difference **0.905 ms**); both exceed the unchanged
0.50 ms allocation in these short, single-order batches. The refined-flat
stress control was **9.488 ms**. Finish repeated balanced, matched-view GPU
comparisons before judging the incremental shader/topology cost; retain these
misses rather than using steady average FPS to waive another gate.

## Why this is a reasonable provisional trade-off

The measured excess over 4 ms did not produce a whole-frame failure in these
latest subchecks. The owner prefers to preserve the approved waves and finish
verification rather than introduce a compiled path solely to meet that CPU
allocation. This accepts **less headroom**, not a claim that water is free or
that 60 FPS is guaranteed elsewhere.

Six/seven milliseconds is roughly **36% / 42% of a 16.7 ms frame**. The stress
p95 has only **0.062 ms** margin to the new ceiling. Longer warmed runs, all-car
coverage and more complex levels may change the outcome. No Test Ground pass
automatically carries this increased budget into Coastal Highway or timed-level
water; revisit the allocation and frame costs when that work is authorized.

The absence of >33.3 ms tails here does not close earlier hitches. The earlier
`3dcf4eb` optimized batch contains a **39.572 ms** Full frame with the 4x4 flooded
but not stalled. No scheduling trace establishes its cause. Preserve it with
the other implementation evidence for the final report; do not equate this
budget decision with a hitch fix.

## Next implementation/verification steps

1. Finish the final-source phone matrix: all three cars, three balanced rounds,
   60 s matched replays, Car waves comparisons, separate live entry at 3/8/15 m/s,
   reverse/current/flooding cases, three saturation rounds and a five-minute
   warmed Full soak. Evaluate CPU and frame distributions case by case.
2. Complete matched GPU/parity and repeated lifecycle/setup verification,
   including mode switching, pause, Reset, car changes and exit/re-entry. Close
   demonstrated test/behaviour gaps without changing approved wave feel.
3. Consolidate prior feature commits and all raw correctness/performance evidence
   into the final milestone report, including failed attempts and open items.
   Run affected tests/full regression again if runtime code changes.
4. Deliver the Test Ground build for owner playtesting and Claude's whole review.
   Coastal Highway and any merge stay separate decisions.

This amendment changes documentation and the offline checker only. No Godot or
phone session is needed to make it, and no new full-suite/phone pass is claimed.
The checker has 11 passing Python tests (including both new limit boundaries),
and all five retained cases validate without changing any raw samples.

Evidence and reproduction: [m6w-budget-amendment-data/README.md](m6w-budget-amendment-data/README.md).
