# M6A independent phone review and wave-start decision

**Owner decision, 2026-09-24:** approved the proposed **4 ms/frame p95 and
5 ms/frame p99 total-water CPU limits** and the limited isolated wave start from
unmerged M6A. `m6-water-waves` begins at `4d5bd21`; no merge is authorized. Live
car integration waits for the hitch fix/retest. This supersedes the pending
proposal language preserved below, not the evidence or outstanding defects.

## Evidence supplied by the owner

The owner supplied Claude's independent Xiaomi 13 verification of a fresh
`4d5bd21` build, with matched no-water placements on master in a separate
worktree. The numbers below are **Claude's reported results**, not a new Codex
run or an independently revalidated raw-data set. No Godot, build or phone
commands were run while recording this review.

- Ford controller p95: 4.271 -> 1.587 ms/tick, about 63% lower.
- Ruts controller p95: 1.835 -> 0.869 ms/tick.
- Creek primitive peaks: 319,036 / 294,232 / 325,960 ->
  254,804 / 246,128 / 255,512; 121–125 draw calls. The fixes pass drawing limits.
- Desktop: 736 passing, one pending, protected fingerprints unchanged;
  Muddy Valley's mud climb matches master's 12.9 s.

| Matched Rock Canyon placement | No-water frame p95 | M6A frame p95 | Difference between reported p95s |
| --- | ---: | ---: | ---: |
| 340 m | 19.52 ms | 20.48 ms | +0.96 ms |
| 1290 m | 20.30 ms | 20.95 ms | +0.65 ms |

Primitive counts also match closely: 165,774 identical at one placement;
122,472 vs 122,600 at the other. This establishes that the roughly 20 ms
Rock Canyon frame-p95 baseline predates M6A. Record that baseline overage as
**inherited frame-time debt**, not a failure caused wholly by water. It neither
proves zero water regression nor establishes exact CPU/GPU cost by subtraction
of percentiles. Geometry/rendering is the review's explanation; the baseline
comparison alone is not a subsystem trace. Do not charge inherited scene cost
against a water-only budget or silently exempt new water regressions.

## Hitch remains unresolved — distinguish the two runs

Claude reports 46.657 and 30.657 ms frames in deep pools, only for the two rally
cars in that run. Those cases end fully flooded and stalled; controller time
during the affected frames is reported as 5.9–6.6 ms. Their 4x4 cases did not
exceed 19.4 ms and did not stall. This is a useful repro lead, not proof that a
stall transition, effect allocation or audio restart caused the long frames.
Final case state does not by itself identify the state on the first hitch tick.

The earlier Codex audit differs: `m6a-query-fixes-2026-09-24.md` records the
79.459 ms maximum in the **first-round 4x4 current-pool case**, with all deep
cases ending flooded and stalled. It used the old 0.60 s intake delay; the new
`4d5bd21` build includes 3.00 s. The old 39.524 ms water tick and the 79.459 ms
frame are different intervals. Preserve both sets; do not turn the newer
rally-only observation into a universal exclusion of the 4x4.

A focused future diagnostic should use the exact new build, both rally cars
and a 4x4 control, calm/current pools, and record before/after stall, full-flood
and sinking transitions with frame/tick IDs, audio play/reset events, particles,
query/force timing and allocations. Include steady fully flooded operation,
not only transitions. Use bounded/preallocated recording and a trace where
needed; logging overhead must not become the apparent hitch. Preserve the old
case for comparison without reverting production stall tuning. No attribution
to audio, scheduling or allocation is justified without that evidence.

## Wave overlap and approved safe boundary

Read-only code inspection finds separate water state (`VehicleWaterState`),
effects/audio and sampled-force paths. The stalled audio branch sets engine
layer target volumes to zero; it does not explicitly create or restart a player
on the stall transition. The controller's timer excludes effects/audio, Jolt
and the recorder. This narrows what a measurement means but does not diagnose
the hitch.

The planned pure wave model, mesh preparation and synthetic rendering can be
isolated from these paths. That is low-risk groundwork for later integration,
not a guarantee of zero rework: live waves change immersion and intake timing
and can obscure the original reproduction. Keep a waves-Off reproduction and
fix/retest the hitch before live-car wave acceptance; the Task 5a early owner
feel stop remains mandatory.

The owner wants to proceed if doing so will not make the hitch expensive to fix.
Approved exception: start only isolated wave groundwork on a new
branch based on unmerged M6A, keeping master and M6A acceptance untouched; carry
a separately reviewed hitch fix into that branch later. This differs from the
written accepted-M6A/merged-master prerequisite; the owner's subsequent approval
explicitly settles that limited exception, as recorded above.

## Approved budget decision

The owner approved **4.0 ms p95 and 5.0 ms p99 of total measured
water CPU per rendered frame**, summed across all physics ticks and external
water callbacks without double counting. These allocate about 24% / 30% of a
16.7 ms frame, so they are ceilings, not performance targets or demonstrated
spare capacity. Keep the wave increment <=0.50 ms p95 / <=1.0 ms p99 *inside*
those totals, plus the independent whole-frame/GPU and hitch requirements.
The earlier controller-only ford frame p95 around 3.1 ms informs this proposal;
it does not prove that the broader total-water scope passes.

This approval does not retroactively pass M6A, does not
absorb inherited Rock Canyon scene cost and does not permit recurring hitches
hidden below percentiles. The spec now records C95=4.0 and C99=5.0 ms/frame.
Setup/load exceptions remain separate decisions.
