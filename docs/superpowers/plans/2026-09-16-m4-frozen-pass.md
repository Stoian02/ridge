# Milestone 4 implementation plan

Approved scope: `../specs/2026-09-15-m4-frozen-pass-design.md`, plus the owner's
2026-09-16 clarification: snow shoulders with a distinct tint; appropriate ice
collision for the gorge; material support for glossy ice. Finish desktop
development and PC playtesting before phone installation and measurements.

Branch: `m4-frozen-pass`, from master at `947a17d`. Do not merge.

1. Add the approved surface values, grip entries, snow spray/sound and muted ice
   squeal. Make terrain and shoulder surfaces configurable with existing defaults.
2. Parallelize road chunk data and terrain carving. Preserve serial output,
   accumulation order and main-thread node creation; test equivalence.
3. Add tunnel data, arched shell, portals, lamps, ridge and portal earthworks.
   Verify collision, ground clearance, and camera clearance.
4. Add bridge data, individual collidable logs, lowered far deck, posts and
   broken rails. Skip its road span and cut an icy gorge with normal reset rules.
5. Generate the Frozen Pass curve and assemble the third catalog level: snow
   valley, two climbing hairpins, bridge, summit tunnel and icy rolling descent.
   Add full-width rollers and surface-specific road materials as needed.
6. Add snow and ice lanes to Test Ground, move rough asphalt and update signs.
7. Run focused tests throughout, then unit/scenario/all gates. Drive each car
   with the scenario driver, measure braking, time builds, capture screenshots
   and render counts. Write `docs/notes/performance-m4.md` and
   `docs/notes/codex-report-m4.md`, with phone checks explicitly deferred.

Commit tested steps by explicitly named paths, including new script UIDs.
Preserve the owner's `project.godot` formatting and `tmux-session.sh`.
Keep sound-loop tail padding and audio shutdown intact. No car physics changes.
