# Milestone 1 performance, Xiaomi 13 (Snapdragon 8 Gen 2)

Date: 2026-09-13
Build: debug APK of the real project (Milestone 1 content), Mobile renderer (Vulkan 1.3, Adreno 740), physics 120 Hz, max 60 FPS

| Scene | Lowest FPS | Highest frame ms | Highest physics ms |
|---|---|---|---|
| Test Ground, idle at spawn, telemetry on (screenshot) | 60 | 9.1 | 2.0 |
| Test Ground, driving across asphalt, dirt, mud, the rough lane and the jump (user, telemetry on) | 60 — never dropped below | not noted | not noted |

Verdict: **meets the 60 FPS target.**
Actions taken: none needed.

Follow-ups for the Milestone 2 performance pass (from the Milestone 1 final review):
- Per-tick allocations in `car/car.gd` (anti-roll array) and `Drivetrain.split_torque` / `split_brake`.
- Glow is enabled in `levels/shared/golden_hour_mood.gd`; check its cost on the Mobile renderer.
- `RoughPatch` mesh size at trail scale (~33k vertices per 200 m strip today).
