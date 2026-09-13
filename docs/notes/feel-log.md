# Feel log: Rally Car

One entry per session. Recordings live in `runs/` (git-ignored); the analysis of each is summarised here.

## Session 1 (2026-09-12) — desktop preview

Notes from the user:
- "The car feels a bit understeery, maybe because of the traction control."
- "When I start to brake and turn, I go forward, and veer slightly to the other direction of the turning."
- "A bit of oversteer would not be a problem, if that complements good driving physics."

Diagnosis (scripted runs):
- Braking at full lock from 60 km/h: ~1°/s of rotation into the turn, then up to +3.2°/s the wrong way below 35 km/h, with front wheels locked (slip ratio −1.00) despite ABS. Cause: sliding tire force took its direction from the normalised slip vector, which is skewed from the real skid direction on a locked, steered wheel.
- Steady 50 km/h full-lock turn: front tires at 19.3° of slip, rears at 4.4°. The steering assist allowed far more lock than the tires could use, so the front ploughed.

Changes made (plan Task 19, "Handling pass"):
- Sliding tires push against the actual skid; ABS holds the brake at what the road can take; the steering limit is grip-based; the car is set up to rotate (rear-biased anti-roll, 60% front brake bias, 35% front drive torque, traction control target 0.3, rear grip 96% of front).
- Result: steady turn 25.7 → 31.9°/s; on mud 15.5 → 26.8°/s; braking in a turn 25.2°/s into the corner with no wrong-way rotation; no locked wheels.

## Session 2 (2026-09-13) — phone, real-project build

Notes from the user:
- "The game behaves good." "It does feel better with the more oversteer, but I do lose control a bit more, maybe I need to practice more."
- "My only concern is the suspension, it may be a bit too soft, but I think it is a bit early to tell."
- Drove all terrains with telemetry on: never below 60 fps.

Recordings:
- **Spin (10 s run):** at 59 km/h, full throttle held while steering swung left → right within 0.5 s; rear slip angle peaked at 77° and the car turned 174°. A power-on direction change with the rotation setup.
- **Jump (9 s run, 1.4 s airborne):** landed at 61 km/h on full throttle with wheel speeds mismatched (fronts ~7.7 m/s slower than the ground, rears ~4 m/s faster) but no kick (peak 1°/s rotation). The suspension used its full 0.35 m of travel — it bottomed out on that landing.
- **Terrain run (34 s, up to 94 km/h, asphalt / dirt / mud):** suspension median travel 0.11–0.12 m, maximum 0.22 m of 0.35 m, **0% of the time in the bump-stop zone** — no bottoming in normal driving. The "soft" feeling is more likely body roll and pitch than lack of travel.

## Milestone 1 sign-off (2026-09-13)

The user signed off Milestone 1: "Overall I am very pleased." The feel stays deliberately open, to be tuned on real tracks as levels are built.

Carried forward to tuning sessions on real tracks (Milestone 2 onward):
1. **Oversteer balance** — first lever: `rear_grip_bias` 0.96 → 0.98 (`car/rally_car.tres`); second: `traction_slip_target` 0.3 → 0.25. Driving tip: lift the throttle for quick direction changes.
2. **Suspension stiffness** — body roll/pitch rather than travel: `spring_stiffness` (26500 N/m, ~1.4 Hz), `compress_damping` / `rebound_damping`, anti-roll bars.
3. **Hard jump landings** — add the scripted jump-landing scenario test first (from the final review), then tune `bump_stop_stiffness` / damping.
4. Still undecided: keep steer-to-roll in the air (`air_roll_torque`), and the default touch steering style.

Not done on purpose: narrowing the scenario-test ranges in `tests/scenarios/feel_baseline.gd` around this tune (plan Task 22 Step 5) — the feel is still expected to change, so the ranges stay wide until a tune is locked.
