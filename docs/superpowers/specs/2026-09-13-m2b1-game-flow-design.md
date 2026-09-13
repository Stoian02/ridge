# Ridge Milestone 2, Part B1 — Game Flow: Design Spec

**Date:** 2026-09-13
**Status:** Draft for review
**Parent spec:** `docs/superpowers/specs/2026-09-11-ridge-design.md` (binding; this document refines its Milestone 2 Part B for the game-flow half)
**Builds on:** Milestone 2 Part A (`docs/superpowers/specs/2026-09-13-m2a-rally-road-design.md`, merged to `master` at e25d8f6); car tune from `docs/notes/feel-log.md` Session 3

---

## 1. Summary

Part B1 turns Rally Road into a game you can open, play and come back to. It adds:
- a **main menu**, **level select** and a **Free Drive** entry for the Test Ground;
- **stars** from target times, and a **results screen** after the finish line;
- a **pause menu** that also holds the steering style and the developer toggles;
- **save data**: best time with its checkpoint splits, best stars, and the steering style, kept between app sessions.

Part B2 (a separate spec) adds Muddy Valley and the trail-builder changes for dirt and mud roads.

## 2. Decisions from the design conversation

| Question | Decision |
|---|---|
| Part B order | Split into B1 (game flow) then B2 (Muddy Valley); B1 first |
| Test Ground | Kept, as a **Free Drive** button on the main menu: no clock, no stars, always available |
| Level unlocks | Finishing a level unlocks the next one (catalog order); star thresholds come later |
| Star targets | Placeholders now from the user's desktop runs, retuned from phone runs by editing the level's data file |
| On-screen during a run | **Reset** and **Pause** only; steering style, Telemetry and Rec move into the pause menu; Track button removed |
| Split comparison | Against the saved **all-time best run** on that level |
| Structure | Separate scenes for menus; pause and results as overlays in the level; one `GameState` autoload |
| Results timing | A short delay after the finish line (~1 s) with the pedals locked, so the car coasts past the gate |

## 3. Player experience

### 3.1 Flow
```
Main menu ──Play──► Level select ──card──► Rally Road ──finish──► Results ──Retry──► Rally Road
    │                    ▲  │                   │                   │  └──Next level──► (next level, when unlocked)
    │                    │  └──Back─► Main menu │                   └──Level select──► Level select
    └──Free Drive──► Test Ground                └──Pause──► Pause menu (Resume / Restart / Level select / Main menu)
```
The app opens on the main menu.

### 3.2 Main menu
Title **RIDGE**, the player's total stars, and two buttons: **Play** (level select) and **Free Drive** (Test Ground).

### 3.3 Level select
One card per catalog level: display name, best time (or "—"), stars earned (0–3), or a lock with "Finish <previous level> to unlock". Tapping an unlocked card loads the level. **Back** returns to the main menu. Only Rally Road exists in B1.

### 3.4 Driving a level
Countdown, clock, checkpoints and resets as in Part A. The top strip shows **Reset** and **Pause**. The checkpoint split shows +/− against the reference best run (§5.4); no delta when the level has never been finished.

### 3.5 Pause menu
Opened by the Pause button, the phone's back gesture, or Escape on desktop; the back gesture or Escape while paused resumes. The game freezes: car, clock, countdown and recorder stop. Pausing during the countdown is allowed and freezes it. Contents:
- **Resume**, **Restart** (levels only), **Level select** (levels only), **Main menu**;
- **Steering: Analog / Buttons** — saved immediately;
- **Telemetry: on/off** and **Rec: on/off** — show the current state.

### 3.6 Results
When the car enters the finish gate the pedals lock and the car coasts; after `RESULTS_DELAY` (1.0 s) the results overlay appears:
- the run time, large;
- stars earned this run, with the targets: "★ finish · ★★ under 1:25.0 · ★★★ under 1:14.0";
- the all-time best time, and **New best!** when this run set it;
- **Retry**, **Next level** (only when a next level exists and is unlocked), **Level select**.

The run is saved at the finish, before the delay. Pause is unavailable while results are showing; the back gesture goes to level select.

### 3.7 Free Drive
The Test Ground as today, with **Reset** and **Pause** on screen. Its pause menu has Resume, Main menu, Steering, Telemetry and Rec (no Restart or Level select: there is no run).

## 4. Architecture

```
GameState (autoload) ── LevelCatalog (levels/catalog.tres) ── LevelDef × n
     │                 └─ Progress (save data in memory) ◄─► SaveSystem (user://save.json)
     │
MainMenu / LevelSelect (scenes) ──GameState.change_scene(path)──► level scene
     │
RunLevel ── finds its LevelDef by scene path ── RunController(RunClock with reference best)
     │                                   └─ run_finished ─► GameState.record_finish ─► ResultsScreen
     └── PauseMenu (overlay) ◄── DrivingRig.pause_requested / back gesture
TestGround ── PauseMenu (no Restart)
```

### 4.1 Files and responsibilities

| File | Kind | Responsibility |
|---|---|---|
| `game/level_def.gd` | Resource | One level: `id`, `display_name`, `scene_path`, `two_star_time`, `three_star_time` |
| `game/level_catalog.gd` | Resource | Ordered `levels: Array[LevelDef]`; `find_by_id`, `find_by_scene`, `next_after` |
| `game/stars.gd` | Pure static | `for_time(time, level) -> int` (0–3) |
| `game/progress.gd` | RefCounted | Save data in memory: best time, best splits and stars per level id; steering style; `record_finish`, `is_unlocked`, `total_stars`; to/from a Dictionary |
| `game/save_system.gd` | Pure static | Read and write a Dictionary as JSON at a given path: temp file then rename; damaged file kept as `.bad`; missing file → empty |
| `game/game_state.gd` | Node (autoload `GameState`) | Holds the catalog, the `Progress`, the save path; loads on start, saves after changes; `change_scene(path)` through an overridable callable |
| `levels/catalog.tres` | Resource | The catalog: Rally Road |
| `levels/rally_road/rally_road_level.tres` | Resource | Rally Road's `LevelDef` (placeholder star times 85 s / 74 s) |
| `ui/ui_kit.gd` | Pure static | Shared thumb-sized buttons, outlined labels and panels in the HUD's text style |
| `ui/main_menu.tscn`, `.gd` | Scene | Main menu |
| `ui/level_select.tscn`, `.gd` | Scene | Level cards, locks, Back |
| `ui/pause_menu.gd` | CanvasLayer | Pause overlay; processes while paused; `show_restart` flag |
| `ui/results_screen.gd` | CanvasLayer | Results overlay |

Changes to Part A / Milestone 1 code:
- `game/run_clock.gd`: the session best becomes a **reference best** (§5.4).
- `game/run_controller.gd`: locks the pedals at the finish; `run_finished(time, splits)` carries the splits.
- `ui/run_hud.gd`: the finish panel moves out to `ResultsScreen`.
- `levels/shared/run_level.gd`: finds its `LevelDef`, seeds the reference best, records the finish, shows results after the delay, owns the pause menu and the back gesture.
- `input/touch_controls.gd`: top strip becomes Reset + Pause; `pause_requested` signal; `release_all_touches()`; steering-style, Telemetry, Rec and Track buttons and their signals removed.
- `levels/shared/driving_rig.gd`: forwards `pause_requested`; applies the saved steering style on ready; no longer wires Telemetry/Rec buttons.
- `levels/test_ground/test_ground.gd`: pause menu (no Restart) and back gesture; Track switching removed.
- `levels/shared/level_switcher.gd` and its test: deleted.
- `project.godot`: main scene `res://ui/main_menu.tscn`; autoload `GameState`; `application/config/quit_on_go_back=false` so the back gesture reaches the game.

## 5. Game systems

### 5.1 LevelDef and LevelCatalog
- `LevelDef` fields as in §4.1. Times are seconds.
- `LevelCatalog.levels` order is the unlock order. `find_by_scene(path)` lets a level scene launched directly from the editor still find its data.
- Free Drive is not a catalog level.

### 5.2 Stars
`Stars.for_time(time, level)`: 1 for any finish; 2 if `time < two_star_time`; 3 if `time < three_star_time`. A time exactly on a target does not beat it. A non-finish (negative time) is 0.

### 5.3 Progress and unlocks
- Per level id: `best_time` (−1 when never finished), `best_splits` (checkpoint index → seconds), `stars` (0–3).
- `record_finish(level, time, splits)` returns `{stars, best_time, new_best}`: `stars` keeps the maximum ever earned; `best_time` and `best_splits` are replaced together, only when `time` is faster.
- `is_unlocked(catalog, level)`: the first catalog level always; any other when the previous level has `stars >= 1`.
- `steer_mode`: `"analog"` or `"buttons"` (default analog).
- `to_dictionary()` / `from_dictionary()` produce and read the save format (§5.5); unknown keys are ignored, missing keys take defaults, wrong types are treated as missing.

### 5.4 Reference best in RunClock
- `RunClock` gets `set_reference_best(time, splits)`. `split_delta(index)` compares with the reference splits (NAN when there are none).
- On `finish()`, if there is no reference or the run is faster, the run becomes the reference (so a new record shows deltas against itself on the next run).
- `RunLevel` seeds the reference from `Progress` when the level loads.

### 5.5 Save file
`user://save.json`:
```json
{
  "version": 1,
  "settings": { "steer_mode": "analog" },
  "levels": {
    "rally_road": { "best_time": 71.6, "best_splits": { "1": 14.8, "2": 26.2 }, "stars": 3 }
  }
}
```
- `SaveSystem.write(path, data)` writes `path + ".tmp"`, then renames it over `path`.
- `SaveSystem.read(path)` returns `{}` for a missing file. A file that is not valid JSON (or not an object) is renamed to `path + ".bad"` (replacing an older `.bad`) and `{}` is returned, with a warning printed.
- `GameState` saves after `record_finish` and after a steering-style change. No autosave timer.

### 5.6 GameState
- Autoload node named `GameState`, created from `game/game_state.gd`.
- `save_path` defaults to `user://save.json`; tests set it to a throwaway path and call `reload()`.
- `catalog`, `progress`, `level_for_scene(path)`, `record_finish(...)`, `set_steer_mode(mode)`, `change_scene(path)`.
- `change_scene(path)` calls `scene_changer`, a Callable defaulting to `get_tree().change_scene_to_file`. Tests replace it so a menu test records the requested scene instead of replacing the test runner.

## 6. Levels and overlays

### 6.1 RunLevel
- On ready: find the `LevelDef` via `GameState.level_for_scene(scene_file_path)`; if none (e.g. a test-built level), run without stars or saving.
- Seed the reference best from `Progress`.
- On `run_finished(time, splits)`: `GameState.record_finish`, then after `RESULTS_DELAY` (1.0 s, a named constant) show `ResultsScreen` with the returned stars, best and new-best, and the next level if unlocked.
- Pause: `DrivingRig.pause_requested`, the back gesture (`NOTIFICATION_WM_GO_BACK_REQUEST`) and the `ui_cancel` action toggle pause, except while results are showing (back then goes to level select).

### 6.2 PauseMenu
- `CanvasLayer` with `process_mode = PROCESS_MODE_WHEN_PAUSED` for its controls; opening sets `get_tree().paused = true` and calls `touch_controls.release_all_touches()`; closing clears it.
- `show_restart` hides Restart and Level select for Free Drive.
- Signals: `resume_pressed`, `restart_pressed`, `level_select_pressed`, `main_menu_pressed`. Leaving the level unpauses first.
- Steering toggles `touch_controls.steer_mode` and calls `GameState.set_steer_mode`. Telemetry and Rec call the rig's overlay and recorder and read `telemetry.visible` / `recorder.is_recording()` for their labels.

### 6.3 ResultsScreen
- `show_results(time, stars, level, best_time, new_best, has_next)`; signals `retry_pressed`, `next_pressed`, `level_select_pressed`.
- Retry and Next load scenes through `GameState.change_scene` (Retry reloads the current level scene, so every run starts clean).

### 6.4 Menus
- Built in code with `UiKit` in the HUD's text style; buttons at least 110 px tall for thumbs on the 1080p-landscape phone. Functional, not polished.
- `LevelSelect` builds one card per catalog level from `Progress`.

## 7. Performance
Menus are separate light scenes; levels are unchanged. Re-measure Rally Road's load time on desktop after the change (Part A: ~1.1 s). Budgets from Part A §8 still apply.

## 8. Testing

### 8.1 Unit tests
- `Stars.for_time`: just under, exactly on and over each target; non-finish.
- `LevelCatalog`: find by id and scene; `next_after` for middle and last.
- `Progress`: unlock rules; `record_finish` keeps max stars, replaces best time and splits together only when faster, reports new best; dictionary round trip; unknown/missing/wrong-typed keys.
- `SaveSystem` (throwaway paths): round trip; missing file → `{}`; damaged file → `{}` plus `.bad`; no `.tmp` left after a write.
- `RunClock` reference best: seeded reference gives deltas from the first checkpoint; a faster finish replaces it; a slower one does not.
- `PauseMenu` and `ResultsScreen`: which buttons show; toggle labels reflect state; steering change saves.
- `TouchControls`: strip has Reset and Pause only; `release_all_touches` clears throttle, brake and steer.

### 8.2 Scenario tests (headless)
All scenario tests that can finish a run point `GameState` at a throwaway save path first, and replace `scene_changer`.
- **Loop:** level select opens Rally Road (recorded scene path) → the scripted driver finishes → results appear 1.0 s (±0.1) after the finish → correct stars → the throwaway save holds time and splits → Retry requests the Rally Road scene.
- **Pause:** pausing mid-run freezes the clock and the car for 2 s; resuming continues; a held throttle is released on pause.
- **Free Drive:** the main menu's Free Drive requests the Test Ground; its pause menu has no Restart.
- **Locks:** a catalog with a second level shows it locked until the first has a finish.
- **Real save untouched:** the real `user://save.json` (if any) has the same content and modification time before and after the scenario suite.
- Existing Part A scenario tests stay green.

### 8.3 Visual checks
Screenshots of the main menu, level select, pause menu and results at 1920×1080, reviewed before hand-off; Rally Road load time recorded.

## 9. Verified during plan writing (before tasks are dispatched)
- An autoload is present in GUT headless runs, and its save path can be redirected before any file is touched.
- `get_tree().paused` stops the car's physics, `RunController` and the recorder, while a `PROCESS_MODE_WHEN_PAUSED` overlay still receives touch/mouse input.
- Replacing `scene_changer` keeps menu tests inside the GUT runner.
- JSON round trip of the save format (float precision, integer keys stored as strings).
- The back gesture setting and notification exist in Godot 4.7.2 (behaviour on the phone is checked in the phone task).

## 10. Out of scope for B1
Muddy Valley and dirt/mud trail building (B2); car select and car unlocks; a settings screen; audio; menu art and animation; cloud save; star-threshold unlocks.

## 11. Done when
On the Xiaomi 13: the app opens on the main menu; Rally Road can be played from level select to results and back at 60 fps; pause and the back gesture work in every screen; best time, stars and steering style survive closing and reopening the app; Free Drive works; all unit and scenario tests pass. Rally Road's star targets are updated from the user's phone runs.
