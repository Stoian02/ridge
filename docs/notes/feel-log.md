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

## Session 3 (2026-09-13) — desktop, Rally Road (Milestone 2 Part A)

Notes from the user:
- Countdown, clock, checkpoints, countdown pedal lock and all resets "work perfect"; never below 60 fps.
- "The car overall is slidy, like you are not on asphalt." Rear grip and the oversteer are fine for now: "you can take the corners nice with a little slide."
- "The car feels too light" — maybe GTA IV-like weight, "but not too much".
- Wants more low-rpm torque and shorter gears: shifts came at ~58 km/h (1→2) and ~100 km/h (2→3), 4th and 5th never reached. (Not deliberate: Milestone 1 used road-car gearing.)
- Asked whether the car is AWD (it is: 35% front / 65% rear); feels the oversteer is a lot for AWD.

Diagnosis:
- Asphalt barely out-gripped dirt: effective grip 1.10 vs 0.92 (real tarmac grips ~40–50% more than gravel).
- Rotation inertia came from the thin 0.5 m gray-box body: roll ~300 kg·m² vs ~550 for a real car, so the body flicked like a light car.
- Old gearing at the 6800 rpm upshift: 58 / 92 / 128 / 167 / 209 / 253 km/h.
- First short-gear attempt (final 5.0) was slower from 40 km/h rolling (3.08 s vs 2.70 s) — an extra shift, and 11% more mass cancelled the torque gain — so the gearing was moved to a middle ratio.

Changes made (`car/rally_car.tres`, `surfaces/grip_table.tres`, new `CarStats.inertia`):
- Grip: `tire_grip` 1.1 → 1.2; rally-on-asphalt multiplier 1.0 → 1.1 (asphalt 1.32, dirt 1.01, mud 0.66). `rear_grip_bias` and `slide_grip` unchanged.
- Weight: `mass` 1300 → 1450; `inertia` (pitch, yaw, roll) = (2400, 2700, 550); springs, dampers and anti-roll bars scaled with mass (+11.5%); `brake_torque` 10000 → 11000; air-control torques scaled with inertia (3700 / 2700); `steer_rate_deg` 180 → 140.
- Engine: torque 220/320/390/380/340/280 → 320/410/440/420/370/300 Nm; `shift_time` 0.18 → 0.12.
- Gearbox: ratios 3.2 / 2.2 / 1.65 / 1.3 / 1.08 / 0.92, `final_drive` 4.4 → 4.8 → shifts at ~55 / 80 / 107 / 136 / 163 / 191 km/h.

Measured (headless, flat asphalt unless noted):
| | Before | After |
|---|---|---|
| 0–70 km/h | 4.12 s | 3.86 s |
| 0–100 km/h | 7.73–8.06 s | 7.50 s |
| 40→80 km/h rolling | 2.70 s | 2.89 s (heavier car) |
| Braking 100–0 | 35.8 m | 33.2 m |
| Steady turn yaw (asphalt / mud) | 31.9 / 26.8 °/s | 35.4 / 33.0 °/s |
| Brake-in-turn | 25.2 °/s, no wrong way | 24.2 °/s, no wrong way |
| Rally Road scripted lap | 1:33.3 | 1:30.3 |
| Kicker, gas held (tilt / landing yaw) | 62° / 41 °/s | 64° / 22 °/s |

User after driving the tune: "a lot better for now"; "not really that much more punchy, but for a stock Subaru I think it is fine" (tuned car versions may come later); "AWD is a lot more planted, but still loose where needed, I like it."

Recordings (desktop, `user://runs/`, analysed against the road curve):
- **Run 1 (22:33, spin):** start→finish gate 78.5 s, max 113 km/h, shifts at 55 / 80 / 107 km/h, throttle 82% of the time. Leaving the rough stretch flat out in 4th at 110–113 km/h, the rear wheels ran onto the left dirt shoulder (~856–872 m), a full-lock flick back right plus a brief lift at ~887 m set the rear sliding. With full throttle and full countersteer the body slip grew steadily from 3° to 32° over ~2 s (rear tyres 21–34°, fronts 10–19°, yaw ~35–45°/s — progressive, not a snap); braking at 67 km/h while ~32° sideways finished the spin (75°) at ~960 m, just past CP3. Recovered by reversing, no reset. Cost: CP3→CP4 27.0 s vs 20.1 s in run 2.
- **Run 2 (22:34, clean):** start→finish gate 71.6 s (scripted driver 90.3 s), max 114 km/h, 34% of the time in 4th, throttle 88%, brake 3%, never beyond the shoulder. Only two mild slides, both in the hairpins at ~45 km/h (16–17° body slip). Jumps: 1.14 s airborne at 446 m (98 km/h), 0.88 s at 1385 m; clean landings. Every other checkpoint segment within 0.2 s of run 1 — very consistent.
- Steering input is on/off (±1.0) in both runs, so countersteer is always full lock.

Open, for the next drive:
0. **Slide recovery** — the run 1 spin shows the tune's bigger asphalt→dirt grip step (1.32 → 1.01) unsettles the car when two wheels drop off at 110 km/h, and power-on full countersteer does not pull the AWD straight (65% rear torque keeps the rears saturated). Realistic enough for now; if recoveries feel impossible, the AWD split (below) and a smaller dirt grip step are the levers. Driving tip: lift, don't brake, when the rear is already sideways.
1. **AWD balance** — for an STI-like AWD the car still rotates more than the real one (65% rear torque, rear anti-roll 8920 vs front 5580, rear grip 96%, 60% front brake bias). Most AWD-like lever: `front_torque_split` 0.35 → ~0.41 and a slightly softer rear bar. User: fine for now.
2. Rolling pull is a little down on the old lighter car; if it feels flat, raise mid-range torque before touching mass.
3. Gas-held jump nose-dive still open (Task 16 test pending).

## Session 4 (2026-09-14) — phone, game flow (Milestone 2 Part B1)

Notes from the user:
- "Everything works fine."
- "I do not like the delay after the finish, so let's not have that." → Results now appear immediately at the finish; the pedals still lock.
- Load time for Rally Road "about 3 seconds", the Test Ground "about 1 second"; "nowhere I saw below 60 fps".
- Measured load times and the repeat-load slowdown: `docs/notes/performance-m2a.md`.

Recording `runs/run_2026-09-14T09-31-33.csv` (phone, Rally Road, analysed against the road curve):
- **Result:** start→finish gate **71.4 s**, the best run so far (desktop best 71.6 s). Max 114 km/h, shifts at 55 / 80 / 107 km/h. Throttle on 78% of the time, brake 2%. Past the shoulder only 1.2% of the time. No resets or spins.
- **Steering:** analog touch steering, with partial inputs (+0.72, +0.92) rather than full lock.
- **Slides:** two controlled power-on slides in the esses and hairpins, 20° at 39 km/h and 26° at 27 km/h. Rear tyres were at 24–31°, fronts at 1°.
- **Jumps:** 1.13 s airborne at 446 m, 0.88 s at 1385 m.
- **After the finish:** the car coasted on the locked pedals and flew off the end of the road, 10 m past the finish gate at 65 km/h. This is hidden behind the results overlay.

Open, for the next session:
1. **Rally Road star times.** They are still the 85 / 74 s placeholders; this run earned 3 stars. Set real times with the user.
2. **Repeat level loads take 4.4–5.2 s on the phone**, against 2.83 s after a fresh app start (performance note).
3. The road ends 10 m past the finish gate, so a finishing car drives off the end.

Not done on purpose: narrowing the scenario-test ranges in `tests/scenarios/feel_baseline.gd` around this tune (plan Task 22 Step 5) — the feel is still expected to change, so the ranges stay wide until a tune is locked.
