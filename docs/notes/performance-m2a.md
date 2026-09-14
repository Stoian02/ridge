# Performance: Rally Road and game flow on the phone (Milestone 2 A + B1)

Device: Xiaomi 13 (2211133G). Build: debug export from `master` at 1891512 (Milestone 2 Part B1 merged). Session: 2026-09-14.

## Frame rate
- The user drove Rally Road (several runs) and Free Drive with telemetry available: **never below 60 fps**.

## Level load time
`RallyRoad built in N s` from `adb logcat -s godot`:

| Load | Build time |
|---|---|
| 1st load in the app session (09:29) | 4.89 s |
| Retry / return to the level (09:30–09:34) | 4.59, 4.38, 4.98, 5.16 s |
| After the app was restarted (09:37) | **2.83 s** |

- The user's estimate for Rally Road was ~3 s; the Test Ground loads in ~1 s.
- **Budget (spec §8): under 3 s.** A fresh app start meets it (2.83 s). Loads within an app session that already built the level took 4.4–5.2 s, about 1.6–2.3 s slower.
- **Not yet investigated.** A likely cause is building the new trail while the previous level's nodes are still being freed, or memory pressure from the previous build.
- **Next step if it persists:** measure the build phases on repeat loads before choosing a fix. The M2A spec's fallback is baking chunks at edit time.

## Recording
- `runs/run_2026-09-14T09-31-33.csv`: clean Rally Road run, start→finish gate 71.4 s — see `feel-log.md` Session 4.

## Not measured this session
- Physics time on the phone (telemetry line): no reading recorded.
