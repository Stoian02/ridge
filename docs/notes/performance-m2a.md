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

## Repeat-load investigation (2026-09-14, desktop)

**Question:** why did Rally Road take 4.4–5.2 s to build on the phone in one session, but 2.83 s after the app was restarted?

**Re-reading the phone data:** the slow session was slow from its *first* load (4.89 s at 09:29), not just on repeats. So the difference is between sessions, not between the first load and later ones. That slow session was launched by `tools/android.sh` straight after `adb install -r`. The fast load (09:37) came after the owner restarted the app about 8 minutes later.

**Desktop reproduction:**
- **Setup:** a throwaway script loaded Rally Road five times through real `change_scene_to_file` scene changes, like the game does, both directly and via level select. It ran headless, in a window, and with the debugger on (`-d`). `TrailLevel.build` was timed per phase.
- **Repeat loads:** no slowdown. All 18 builds took 1.14–1.27 s; with the debugger on they took 1.20–1.27 s against 1.14–1.20 s without it.
- **Leaks:** nothing leaked between loads. Nodes stayed at exactly 1,003, objects were flat after the first load, and static memory stayed at 107–116 MiB.
- **Where build time goes (desktop, typical):**

  | Phase | Time | Share |
  |---|---|---|
  | Terrain meshes and collision (`TerrainBuilder`) | 0.60 s | ~52% |
  | Terrain height field (`TerrainField.generate`) | 0.29 s | ~25% |
  | Road (`RoadBuilder`) | 0.21 s | ~18% |
  | Scenery | 0.05 s | |
  | Checkpoints | ~0 s | |

  The phone's fresh 2.83 s is about 2.4× the desktop build.
- **Launch method:** `tools/android.sh` launches through the launcher intent (`adb shell monkey`), with no remote debugger attached.

**Conclusion so far:** the builder itself doesn't slow down between loads. The likeliest cause is the phone's state right after install:
- Android compiling and verifying the app in the background after `adb install`
- heat from the build and install

This is unconfirmed; it needs the phone.

**Phone checks for the next session (with a cable):**
1. Install with `tools/android.sh install`, launch immediately, and load Rally Road 3 times. Note each `built in` time (`adb logcat -d -s godot | grep "built in"`).
2. While those loads run, capture CPU and thermal state: `adb shell top -n 1 -m 10` and `adb shell dumpsys thermalservice | head -30`.
3. Force-stop the app (`adb shell am force-stop com.ridge.game`), wait 10 minutes with the phone idle, launch it from the launcher, and load Rally Road 3 times again.
4. If the step 3 loads are fast (~2.8 s) and the step 1 loads are slow, the cause is post-install or thermal. That's not a game bug; just test after the phone settles.
5. If loads are slow even when the phone is settled, measure the build phases on the phone. Terrain mesh generation is the first thing to optimise, since it's half of the build.
