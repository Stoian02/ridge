# Traction control and tyre tuning

2026-09-16, after the Frozen Pass PC handoff. The owner reported intrusive
traction control and explicitly approved the pause-menu strength slider and
the accompanying `car/drivetrain.gd` change. This is additional approved scope,
not part of the original no-car-physics-change Frozen Pass specification.

## Player control

Open **Pause / Escape → Traction control**, in the right-hand settings column.
The slider works in every track and Free Drive, with all three cars:

- **Off (0%)** bypasses traction-control torque cuts completely.
- **1–99%** scales the amount of torque removed, not tyre grip or the slip target.
- **Full (100%)** is exactly the previous behaviour and the default for old saves.

The choice is saved globally and reaches the active car while paused, ready for
Resume. It survives resets, level/car changes and restarts. It does not rewrite
the shared car resources. A car whose resource has `traction_control = false`
still has no TC, regardless of the slider.

At maximum intervention the original system retains 20% of requested engine
torque. At 50% strength it retains 60%; at 0% it retains 100%. Before the slip
threshold is exceeded, all slider positions retain 100%.

ABS, steering assistance, rev limiting, gear-change torque cuts and engine
braking are unchanged. **TC Off does not disable the rev limiter.** More
wheelspin does not necessarily produce more acceleration on ice.

## Where to tune each car

Select one of these resources in Godot's FileSystem panel, then edit its **Tires**
section in the Inspector. Restart the running game after resource changes so
the car is recreated with the new setup.

| Car | Tuning resource | Current `tire_grip` |
|---|---|---:|
| Rally Car | [`car/rally_car.tres`](../../car/rally_car.tres) | 1.20 |
| Rally Car Tuned | [`car/rally_car_tuned.tres`](../../car/rally_car_tuned.tres) | 1.30 |
| Off-road 4x4 | [`car/offroad_4x4.tres`](../../car/offroad_4x4.tres) | 1.05 |

The similarly named files inside `car/cars/` are catalog/body definitions that
point to these stats resources. You do not need to edit physics code to tune tyres.

Useful controls in **Tires**:

- `tire_grip`: the main per-car grip multiplier, affecting acceleration, braking
  and cornering on every surface. Start here for more or less overall traction.
- `slide_grip`: the fraction of peak grip remaining when fully sliding. A higher
  value preserves more grip during a slide; it is not a separate surface grip.
- `rear_grip_bias`: rear grip relative to front grip. Lower values reduce rear
  grip and encourage rotation/oversteer.
- `peak_slip_ratio`: where forward/braking grip peaks on the slip curve.
- `peak_slip_angle_deg`: where sideways grip peaks. The two peak settings reshape
  the response; increasing them is not a simple increase in grip.

In **Assists**, `traction_slip_target` (currently 0.3 on all three) controls how
much driven-wheel slip is allowed before TC begins cutting power. Higher means
later intervention. The pause slider changes the strength of that intervention,
not this threshold. `traction_control` is the car's base on/off switch.

## Surface-specific tyre behaviour

[`surfaces/grip_table.tres`](../../surfaces/grip_table.tres) contains the
car-archetype/surface multipliers. For example, `offroad/snow = 1.3` gives the
4x4 an extra snow multiplier. **Stock and tuned rally cars both use the `rally`
archetype**, so changing `rally/snow` affects both. Unlisted pairs default to 1.0.

[`surfaces/snow.tres`](../../surfaces/snow.tres),
[`surfaces/ice.tres`](../../surfaces/ice.tres), and the other surface resources
control the ground itself and therefore affect every car touching that surface.
Their `grip` is separate from `drag`, `rolling_resistance` and `sink_depth`.

Before the slip curve is applied, available tyre grip is:

```text
surface.grip × car.tire_grip × grip_table[archetype/surface]
```

Rear wheels additionally multiply this by `rear_grip_bias`. For example, the
stock rally car's snow factor is `0.4 × 1.2 × 1.0 = 0.48`; the 4x4's is
`0.4 × 1.05 × 1.3 = 0.546`. This explains why its lower base tyre number does not
mean worse snow grip.

Change one value at a time and compare the same car on the same Test Ground
strip, at a fixed TC setting. Small relative steps (for example 1.20 → 1.26)
make effects easier to isolate. No tyre or surface tuning values were changed
when adding the slider.

## Verification and implementation notes

Final verification: **426 unit tests pass**; full suite **488 pass / 1 known
pending**, 489 tests in 70 scripts, 158.266 s, exit 0 with no `SCRIPT ERROR`
(`/tmp/ridge-tc-final.log`). The pending held-gas jump test is unchanged. The
strength test was then tightened to compare directly with the legacy formula;
all 30 drivetrain tests pass separately as well. Existing full-TC Frozen Pass
times remain exactly 218.22 / 201.01 / 191.74 s for stock / tuned / 4x4.

- `car/drivetrain.gd`: runtime strength, original full-strength arithmetic kept
  exactly, interpolated torque cuts for partial strength; reset preserves it.
- `game/progress.gd`, `game/game_state.gd`: backward-compatible saved setting,
  clamped finite values, notification on changes/reload.
- `levels/shared/driving_rig.gd`: applies the saved setting on creation and listens
  for live updates without mutating `CarStats`.
- `ui/pause_menu.gd`, `ui/slider_thumb.svg`: native mouse/touch/keyboard slider,
  large thumb and input area, two-column layout that fits the landscape viewport.
- Unit checks cover off/partial/full torque, save defaults/validation, live
  paused updates, all cars, reloads, resets and menu sizing.
- `tests/scenarios/test_traction_control.gd` launches every car on snow and ice at
  0%, 50% and 100%. All remain upright and pull away; off permits more wheelspin
  than full. On flat ice, final speed changed little: tyre grip/rev limiting
  remain important, so the slider is not presented as a guaranteed speed boost.

The first temporary screenshot harness used a custom SceneTree and failed before
autoload registration. It was replaced by a normal scene with an isolated save;
this was a verification-harness startup issue, not a change to the game's startup.
Normal pause-menu captures are in ignored `build/tc_pause_000.png`,
`tc_pause_037.png` and `tc_pause_100.png`.

One initial full-suite run stalled after the Frozen Pass completion checks. Its
test process was stopped; the cause was not established. The final gate uses
one runner with fresh, isolated temporary save/config directories (no GUI capture
or second suite sharing its save path). This is not claimed as an audio/engine
hang fix. Focused launches and visual verification passed independently.
