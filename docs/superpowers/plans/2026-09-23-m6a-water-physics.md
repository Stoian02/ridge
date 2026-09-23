# Milestone 6A — water physics implementation plan

Approved spec: `docs/superpowers/specs/2026-09-23-m6a-water-physics-design.md`.
Owner authorized implementation on 2026-09-23. Branch `m6a-water-physics`, based
on `master` at `a3dbee4`. No merge or push; stop for owner/Claude review after A.

## Guardrails

- Implement the approved spec, not Coastal Highway, aquaplaning or skimming.
- No old car tuning, surface stats, geometry fixtures, shelf difficulty or
  loose-stone activation changes. Only water-specific car code/profile wiring.
- Preserve owner changes to `project.godot` and never touch `tmux-session.sh`.
- The coordinator owns all Godot runs. Check for the owner's game before each
  run; no parallel tests, benchmarks, imports or captures, including agents.
- Capture baseline water geometry before adapters change. Do not regenerate
  existing protected fixtures. Stage named files and commit by coherent feature.
- Later tuning outside the approved starting values needs owner approval.

## Dependency order and independent work

Baseline → water queries and pure vehicle model → course/adapters/car wiring →
effects and UI → integrated tests/captures → phone measurements → report/review.

The repo's inherited handover requests sub-agent development after approval.
Parallel workers may own geometry queries/adapters, vehicle simulation, and the
test course. The coordinator owns shared rig wiring, feedback, baseline capture,
test execution, integration review and commits. No worker starts Godot or commits.

### 1. Baseline and safety checks

- [x] Verify branch and inactive desktop game; inspect phone availability without
  launching anything the owner might be using.
- [x] Add `tools/record_water_geometry.gd` and
  `tests/unit/test_water_geometry_baseline.gd`. Capture complete existing water
  mesh arrays/transforms for creek, ford ribbon and ruts before their changes.
- [x] Run baseline unit and relevant scenarios, and the unchanged load benchmark;
  retain logs under `/tmp/ridge-m6a-*`. Prefer isolated test saves.

### 2. Water geometry/query foundation

- [x] Implement `WaterBodyDef`, `WaterSample`, `WaterBody`, `WaterWorld`.
- [x] Use the real top triangles, finite bed, 16 m spatial bins, deterministic
  overlap selection and no solid water collision. Reuse exact terrain/road bed
  samples or relevant collision triangles, not the entire world every frame.
- [x] Test gaps, banks, seams, depth, overlap, transform/scale validation,
  removal/rebuild and finite bottom bounds. Keep buffers reusable.

Shared interface for independent work:

- `WaterSample`: `valid: bool`, `surface_y: float`, `bed_y: float`,
  `current: Vector3`, `edge_weight: float`, `body_id: StringName`, `color: Color`;
  `clear()` resets it. Valid means a water column exists at X/Z, not that the
  query is already submerged; above-surface intake queries need clearance.
- `WaterWorld.sample(point: Vector3, result: WaterSample, radius: float = 0.0)`
  fills in-place. Radius permits a probe to intersect a finite volume when its
  centre is just outside the vertical span; it never expands dry banks sideways.
- `WaterWorld.add_body(def: WaterBodyDef, top_faces: PackedVector3Array,
  bed_faces: PackedVector3Array, transform: Transform3D = Transform3D.IDENTITY,
  face_currents: PackedVector3Array = PackedVector3Array()) -> WaterBody`.
  Inputs are triangle lists in the supplied transform's local coordinates;
  optional currents are one per top triangle. `remove_body(body)` and `clear()`.
- `WaterBodyDef`: `id`, `current_velocity`, `shore_probe_blend = 0.10`,
  `depth_epsilon = 0.002`, `color`; appearance helpers are separate from physics.

### 3. Vehicle state and force model

- [x] Implement profiles with the approved numbers, per-instance stall/flood
  state, probe positions/cap fractions, horizontal-axis relative-water drag and
  bounded combined impulses. Test energy dissipation and zero-speed/tilt cases.
- [x] Add optional `CarStats.water_profile` and wire two water-only resources into
  the three cars without changing old fields.
- [x] Add explicit controller stepping to `Car`: body/intake before drivetrain,
  wheels after contact update, forces once, wet-body air-control suppression.
- [x] Stall/restart gates retain service brakes, gear, steering and TC authority;
  dry path and support coupling stay unchanged. Reset all new state.
- [x] Unit tests for timers, hysteresis, pause, per-car independence, dry bypass;
  fixture scenarios for floating/sinking, restart, currents and 60/120 Hz stability.

Runtime interface: `Car.water: VehicleWaterController`; `water.set_world(world)`;
`water.state: VehicleWaterState`; `water.wheel_samples: Array[WaterSample]` and
`water.wheel_wetness: PackedFloat32Array`. Expose body immersion, intake clearance,
water-relative speed/current and measured water time for feedback/telemetry.
Coordinate exact field names before the feedback integration. No resource stores
mutable car state. Unbound worlds use the original dry path.

### 4. Raised Test Ground course

- [x] Build shallow bays at X=60 and matching 2.8 m deep calm/current basins at
  X=105/155, +Z from 30, using the spec's profiles, side ramps and closed sides.
- [x] Preserve slab, spawn and every old course. Use asphalt bed and match mesh
  collision; register water using the shared query interface.
- [x] Implement lightweight pool/river material helper; preserve old water mesh
  arrays. Add depth marks, labels, direction sign and current arrow, with budgets.
- [x] Unit tests for footprint separation, depths, collision and matching basins.

### 5. Existing-level adapters and rig ownership

- [x] Add explicit current settings to ford/creek/rut defs and authored resources.
- [x] Register existing drawn water in a level-owned world without changing any
  mesh arrays, seeds, banks, roads or collision. Set approved translucency.
- [x] Bind worlds in `RunLevel` and Test Ground before placing/playing the car;
  clear registrations on rebuild/exit and handle direct test fixtures.
- [x] Verify new water baselines and protected geometry/balance tests unchanged.

### 6. Feedback and recording

- [x] Reuse wheel emitters, blend out dry spray, place water spray at waterline;
  one bounded body-entry/wake emitter, no rigid droplets.
- [x] Add padded synthesized wash/entry sounds, engine stall/restart audio,
  teardown/reset/pause handling and no duplicate teleport splash.
- [x] Add rig-owned nonblocking warning label, priority/hysteresis, optional
  intake debug marker; append water telemetry/CSV columns without breaking old
  recordings or reordering old columns.
- [x] Unit tests for effects, mix, warnings, reset, audio padding and CSV fallback.

### 7. Integration verification

- [x] All cars: dry/wet matched beds at 3/8/15 m/s, deep float/sink, current sign,
  stalled forward/reverse brakes, recover/re-enter, pause/reset/restart/car-change.
- [x] Real ford, rut climb, creek/banks, full Rock Canyon 4×4, Muddy Valley and
  loose shelf. Investigate failures; never relax protected assertions.
- [x] Run `./run_tests.sh all`, no script errors. Record exact result and any
  inherited pending/flaky findings; run desktop captures for all requested views.

### 8. Phone, commits and handoff

- [x] Build/install preserving saves when phone is available and idle. Measure
  all five levels in matched three-round load order, water p95/max physics time,
  drawing/FPS, repeated reset/load cleanup and audio behaviour.
- [ ] Phone performance acceptance: the 2026-09-23 retest **failed** water,
  setup and creek primitive budgets. Corrections and owner handling/audio
  approval remain outstanding; completed measurements are not acceptance.
- [x] Report all misses honestly, including inherited Rock Canyon >3 s. Do not
  add an unapproved build-speed project or alter physics/geometry to force budgets.
- [x] Commit by feature, update AGENTS and write
  `docs/notes/codex-report-m6a-water.md` with logs/limits and a playtest guide.
- [x] Stop for owner playtesting and Claude review. Phone acceptance remains
  pending as recorded above; never start Part B here.

## Progress log

- 2026-09-23: written spec approved; plan created. No runtime changes at this
  checkpoint. Baselines and implementation follow; unchecked boxes are not claims
  of completed or verified work.
- 2026-09-23: water implementation complete. Full desktop suite: 728 passing,
  one inherited pending, no script errors; final menu checks 8/8 and the
  one-shot benchmark launcher smoke test passed. Original protected fixtures
  remain unchanged. Desktop captures and three-round load measurements are
  recorded in `docs/notes/codex-report-m6a-water.md`. Phone unavailable; its
  measurement/acceptance gate remains open, including existing load-budget miss.
- Implementation commits: `3021d5b` water volumes/adapters; `9e33cf7` vehicle
  integration; `ddda98e` test courses and feedback. Measurement tools and this
  handoff are a separate final commit. No merge/push or Part B work.
- 2026-09-23 review follow-up: repeated original desktop benchmark in three
  pacing modes, 36 phone course cases, 15 real-level phone views, 60 matched
  baseline/current phone loads. Raw data and independent CSV checker retained.
  Full suite rerun: 730 passing / one inherited pending / no script errors.
  See `docs/notes/m6a-performance-retest-2026-09-23.md`: performance acceptance
  fails. No runtime physics/tuning/geometry changes. Latest water APK restored,
  save checksum unchanged. Waves/displacement recorded as a separate future
  part for later brainstorming, not implemented or added to Coastal Highway.
