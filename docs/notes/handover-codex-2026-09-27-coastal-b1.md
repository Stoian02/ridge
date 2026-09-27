# Handover to Codex — Coastal Highway Part B1 (2026-09-27)

Written by Claude. Milestone 6 is finished and merged; this starts the sixth
level. Read `AGENTS.md` first — it was rewritten today and is short — then
`docs/notes/handover-2026-09-17-rock-canyon.md` for the repo rules and tooling,
which still apply in full.

## 1. What just happened

**Milestones 1–6 are merged into `master` at `b075946`**, verified by a full
suite on the merged result: **799 passing, one inherited pending, no
`SCRIPT ERROR`**. The four-deep branch stack is gone; `m6a-water-physics`,
`m6-water-waves`, `m6-hitch` and `m6b-coastal-design` are deleted.

What landed with it:

- **Water physics** — depth drag, temporary flotation and sinking, currents,
  3.00 s intake stalls — live in Rock Canyon's ford and rut puddles, Muddy
  Valley's creek and three Test Ground pools.
- **Waves** — ambient, entry, bow and trailing wake, with physics sampling the
  same displaced surface that is drawn. **Test Ground only, default Off.**
  Rolling them into timed levels is separate and unapproved.
- **The long-frame hitch is closed as platform behaviour.** Claude's phone
  reproduction (`docs/notes/m6-hitch-phone-reproduction-2026-09-27.md`) traced
  291 s and 17,480 frames: twelve of thirteen frames above 33.3 ms occurred
  within 0.10 s of a measurement case starting, and the single warmed-state one
  showed identical work — same queries, same triangles, same state — taking
  twenty times longer. Claude's earlier "rally-only, flooded and stalled"
  hypothesis was disproven by the larger sample. Do not reopen this without
  evidence of a *different* shape.
- **Knowingly unmet gates, accepted after the owner playtested at 60 fps:** the
  Test Ground total-water CPU limits fail in synthetic replay and saturation
  cases (live driving and five-minute soaks pass), and the matched GPU increment
  is +0.64–0.92 ms against +0.50 ms. These are optimisation targets now — and
  explicitly **not** spare headroom to spend again on this level.

## 2. What to build

**Coastal Highway Part B1** on branch `m6b-coastal-highway`, already created
from `master`.

The design is approved and written up in
`docs/superpowers/specs/2026-09-26-m6b-coastal-highway-design.md`. **Read §13
first** — the owner's decisions from 2026-09-27 — then the rest of the spec,
whose proposals §13 constrains.

### The split, and what B1 is

B1 is **the driving**: route and generated curve, headland tunnel, the mandatory
gap jump, the stone bridge, surfaces and shoulders, checkpoints, scatter and
presentation. It should end as a playable 3 km level the owner can drive and
judge on its own.

B2, later and separately, is **the water**: flooded dip, sandy crossing with
current, puddles, local surface patches, sea, and any wave presence approved
then. **Do not build B2 in this pass**, and do not start it before B1 is
reviewed and merged.

Wet-grip surface values may land with B1 as data — new `SurfaceDef` files and
grip-table entries for `wet_asphalt`, `coastal_sand` and `soft_sand`, per spec
§5 — because the sandy stretches need them. The water bodies that make a surface
actually wet belong to B2.

### The order that matters

The spec's §10 checkpoints hold, and the first one is the important one: **the
jump feasibility gate comes before scenery.** Greybox the route, prove all three
cars clear the gap reliably from the reset with normal controls at the owner's
usual traction-control setting plus 0% and 100%, and get the owner's feel
feedback, before building anything decorative on top of it. If the weakest car
cannot make it, the gap, ramp or landing changes — not the cars.

### Budgets for this level

- **Build under 5 s on the phone** (levels over 2 km; the 3 s budget stays for
  the existing ones). Spec §13.2 has the arithmetic: Rock Canyon's 3.9 s
  includes 1.28 s of shelf and loose-stone work Coastal will not have, and the
  length-proportional phases scale to roughly 3.3 s at 3 km. It is a real
  constraint. **If it is exceeded, the answer is deferral** — building only what
  the player can reach soon — **not another raise.**
- Under **300k primitives, under 150 draw calls, 60 fps** on the Xiaomi 13.
- Total water CPU is **6 ms p95 / 7 ms p99** when B2 arrives; B1 should not be
  spending water budget at all beyond what already exists.

## 3. Rules

- **Work on `m6b-coastal-highway`. Do not merge. Do not push.**
- **Stage files by name.** Never `git add -A` or `git add .`. Never touch
  `tmux-session.sh` or the owner's modified `project.godot`, and never discard
  working-tree state — use a separate `git worktree` if you need other files.
- **Ask before changing anything under `car/` or the values in
  `surfaces/*.tres`.** New surface files are expected; editing existing ones is
  not. `tests/scenarios/test_car_balance.gd` and
  `tests/unit/test_geometry_fingerprints.gd` must pass **without being
  re-recorded or relaxed** — the fingerprints now cover four levels, and adding
  a fifth level must not move any of them.
- **Do not change the existing levels**, and do not soften Rock Canyon's
  CP4–CP5 shelf or remove `TalusDef.active_distance`.
- **Measure on the phone, not the desktop.** The desktop has misled this project
  three times now: loose stones at 6 ms versus 58 ms, ambient waves at 0.02 ms
  versus 2.7 ms, and water controller costs off by 4×. A desktop number is a
  hypothesis.
- **Never run tests, benchmarks or captures while the owner is playing** — check
  `ps -eo pid,args | grep "godot --path ."` first, and never kill their process.
- Commit messages end with the repo's `Co-Authored-By` and `Claude-Session`
  trailers, with your own session link.
- Report honestly: keep failed runs, say what you could not verify, and never
  claim a suite you did not run. Finish with
  `docs/notes/codex-report-m6b1-coastal.md`.

## 4. Suggested shape of the work

Write the B1 implementation plan first, from the spec, and have the owner review
it before building — that is the pattern that has worked here. Then, roughly:

1. Curve and route greybox: `tools/generate_coastal_highway_curve.gd`, level
   data, checkpoints. Nothing decorative.
2. **The gap jump**, including whatever new opt-in data and builder a true gap
   needs — `TrailDef.jumps` are humps, not gaps. Then the feasibility gate and
   the owner's drive.
3. Tunnel and stone bridge, each as their own opt-in definition and builder; do
   not change `BridgeDef`/`BridgeBuilder`, which build logs and a dropped span.
4. Surfaces, shoulders, edge protection, scatter and presentation.
5. Phone checks throughout, not at the end.

Existing patterns to copy rather than reinvent: `TunnelDef`/`TunnelBuilder` and
`RockStepDef`/`RockStepBuilder` for "small resource on `TrailDef` plus a builder
node that owns its meshes and collision", and the width profile for anything
that varies along the road.
