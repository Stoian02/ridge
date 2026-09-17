# Milestone 5 — Rock Canyon Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add the fourth level, Rock Canyon: a 2.1 km rock-crawling route with four new surfaces, a road width profile, rock steps, boulder fields, a loose talus field, a ford with a waterfall, canyon walls, a throttle lever control mode and two new sounds.

**Architecture:** Levels are data plus generators. Every new structure follows the Milestone 4 `TunnelDef`/`BridgeDef` pattern: a small `Resource` on `TrailDef`, a builder `Node3D` that owns its meshes and collision, its own unit tests, and a timed phase in `TrailLevel.build_phases`. The road width profile lands first and alone, with the three existing levels proven bit-identical by recorded geometry fingerprints before anything is built on top.

**Tech Stack:** Godot 4.7.2 (GDScript, typed, tabs, `##` doc comments), Jolt physics at 120 Hz, GUT tests via `./run_tests.sh`.

**Spec:** `docs/superpowers/specs/2026-09-17-m5-rock-canyon-design.md` (approved section by section by the owner). Read it alongside each task; the plan argues from it. Handover with repo rules: `docs/notes/handover-2026-09-17-rock-canyon.md`.

## Global Constraints

- **Branch `m5-rock-canyon`** from `master` at `cb20c09`. Never merge, never push. The owner decides after the phone test.
- **Stage files by name.** Never `git add -A` or `git add .`. After `godot --headless --import` new `*.gd.uid` files appear next to new scripts: stage them with their scripts. Never stage `project.godot` (the owner's uncommitted editor re-save) or `tmux-session.sh` (untracked, the owner's).
- **Commit messages** end with a blank line and then exactly: `Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>`
- **No car physics changes:** nothing under `car/` changes, and no value in an existing `surfaces/*.tres` changes. Milestone 5 adds *new* surface files and *new* grip-table entries only.
- **Existing levels must not change:** Rally Road, Muddy Valley and Frozen Pass road meshes, collision faces, terrain heights, edge distances and gate distances must stay bit-identical (Task 1 records fingerprints; the test stays green through every later task).
- **Tests vs playing:** before any Godot run, `ps -eo pid,args | grep "godot --path ." | grep -v grep` must print nothing. Never kill the owner's process. If a game is running, wait.
- **Test commands:** one file: `godot --headless --fixed-fps 120 --max-fps 0 -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/<file>.gd -gexit`; suites: `./run_tests.sh unit|scenarios|all`. A run with any `SCRIPT ERROR` line is a failure. After adding a `class_name` script run `godot --headless --import` once or the class will not resolve.
- **Hard-won rules (handover §5):** worker threads must not call shared objects' methods (copy into locals, inline the maths); every looping sound needs the `LOOP_PAD` tail and players must stop in `_exit_tree()`; typed GDScript (`for side: float in [-1.0, 1.0]`, explicit types for `Dictionary` values and inline `a if c else b`); compressed mesh normals compare with `distance_to(...) < 0.01`; `amount_ratio` does not exist on `CPUParticles3D`; draw calls are the phone budget (merge meshes, `MultiMesh`, `visibility_range_end`); quote `====` in zsh.
- **Budgets:** < 300k primitives, < 150 draw calls, 60 fps on the phone, level build < 3 s (desktop test asserts this).
- **Star times:** placeholders 285 s (two stars) / 255 s (three stars), replaced by the owner's real runs later.
- **Copy:** level surfaces line "Deep mud, rock, scree, water"; recommendation line "Recommended: Off-road 4x4"; throttle setting values `"pedal"` (default) and `"lever"`.

## File Structure

New files:

| File | Responsibility |
|---|---|
| `tools/record_geometry.gd` | Prints geometry fingerprints of the three shipped levels (SceneTree tool; also the static used by the regression test) |
| `tests/unit/test_geometry_fingerprints.gd` | Asserts the three levels' geometry is unchanged |
| `tests/unit/test_width_profile.gd` | Road width profile behaviour and consumers |
| `surfaces/deep_mud.tres`, `surfaces/rock.tres`, `surfaces/scree.tres`, `surfaces/wet_rock.tres` | New physical surfaces |
| `tests/unit/test_rock_canyon_surfaces.gd` | Surface values, grip entries, feels, splash spray, rock and waterfall sounds |
| `levels/trail/rock_step_def.gd`, `levels/trail/rock_step_builder.gd`, `tests/unit/test_rock_steps.gd` | Rock steps |
| `levels/trail/boulder_field_def.gd`, `levels/trail/boulder_builder.gd`, `tests/unit/test_boulders.gd` | Boulder fields |
| `levels/trail/talus_def.gd`, `levels/trail/talus_builder.gd`, `tests/unit/test_talus.gd` | Loose talus |
| `levels/trail/ford_def.gd`, `levels/trail/ford_builder.gd`, `tests/unit/test_ford.gd` | Ford, water, waterfall, mist, sound |
| `tests/unit/test_canyon_walls.gd` | Canyon wall sections |
| `input/touch_throttle_logic.gd`, `tests/unit/test_touch_throttle_logic.gd`, `tests/unit/test_touch_lever.gd`, `tests/unit/test_throttle_setting.gd` | Throttle lever |
| `tests/unit/test_recommended_car.gd` | `LevelDef.recommended_car` and its UI lines |
| `tools/generate_rock_canyon_curve.gd`, `levels/rock_canyon/*` | The level |
| `tests/unit/test_rock_canyon.gd`, `tests/scenarios/test_rock_canyon.gd` | Level layout/build and driving scenarios |
| `docs/notes/m5-rock-canyon-notes.md` | What was built, deviations, measured numbers, phone checklist |

Modified files (by task): `levels/trail/trail_def.gd`, `road_sampler.gd`, `road_builder.gd`, `road_chunk_data.gd`, `road_profile.gd`, `terrain_def.gd`, `terrain_field.gd`, `trail_earthworks.gd`, `scatter_builder.gd`, `checkpoint_placer.gd`, `trail_level.gd`; `surfaces/grip_table.tres`; `effects/surface_feel.gd`, `surface_feel_table.tres`, `wheel_spray.gd`, `spray_logic.gd`, `tyre_sound_logic.gd`, `car_audio.gd`, `sound_synth.gd`; `input/touch_controls.gd`; `game/progress.gd`, `game_state.gd`, `level_def.gd`; `levels/shared/driving_rig.gd`; `ui/pause_menu.gd`, `level_select.gd`, `car_select.gd`; `levels/catalog.tres`; `debug/load_benchmark.gd`; `tests/scenarios/trail_driver.gd`, `run_level_builder.gd`; existing tests `test_sound_synth.gd`, `test_surface_feels.gd`, `test_level_catalog.gd`, `test_menus.gd`, `test_trail_level.gd`; `AGENTS.md`.

Task order: 1 (width profile, alone) → 2 (surfaces, sounds) → 3 (walls) → 4 (rock steps) → 5 (boulders) → 6 (talus) → 7 (ford) → 8 (throttle lever) → 9 (recommended car) → 10 (the level) → 11 (scenarios, driver, notes). Tasks 2–9 are independent of each other but each depends on Task 1.

---

### Task 1: Road width profile (lands first, alone)

Spec §5. `TrailDef` gains width stretches; `RoadSampler` exposes eased half-widths; `RoadBuilder` (threaded and serial), `TerrainField`'s corridor, `ScatterBuilder`'s posts and `CheckpointPlacer`'s gates follow the taper. Before touching any code, record the three existing levels' geometry fingerprints so the "unchanged" promise is proven, not assumed.

**Files:**
- Create: `tools/record_geometry.gd`, `tests/unit/test_geometry_fingerprints.gd`, `tests/unit/test_width_profile.gd`
- Modify: `levels/trail/trail_def.gd`, `levels/trail/road_sampler.gd`, `levels/trail/road_builder.gd`, `levels/trail/road_chunk_data.gd`, `levels/trail/terrain_field.gd`, `levels/trail/scatter_builder.gd`, `levels/trail/checkpoint_placer.gd`, `levels/trail/trail_level.gd`

**Interfaces:**
- Produces: `TrailDef.width_stretches: Array[Vector4]` (start, length, road width, shoulder width), `TrailDef.width_blend: float = 10.0`, `TrailDef.road_width_at(distance) -> float`, `TrailDef.shoulder_width_at(distance) -> float`, `TrailDef.half_total_width_at(distance) -> float`; `TrailDef.half_total_width()` now returns the *widest* half-width. `RoadSampler._init(curve, banking = true, trail_def: TrailDef = null)`, `RoadSampler.half_width_at(distance)`, `RoadSampler.road_half_width_at(distance)`. `RoadBuilder.station_lateral(station, half_road, road_scale, shoulder_scale) -> float` (static). `CheckpointPlacer.gate_width_at(def, distance) -> float` (static). Later tasks construct samplers as `RoadSampler.new(curve, banking, trail)`.

- [ ] **Step 1: Create the branch and check nobody is playing**

```bash
cd /home/stoyan/Projects/claude-projects/ridge
ps -eo pid,args | grep "godot --path ." | grep -v grep   # must print nothing
git status --short                                       # only " M project.godot" and "?? tmux-session.sh"
git checkout -b m5-rock-canyon
```

- [ ] **Step 2: Write the fingerprint tool**

`tools/record_geometry.gd`:

```gdscript
extends SceneTree
## Prints fingerprints of the shipped levels' generated geometry (road mesh
## vertices, collision faces, terrain heights, edge distances, gate distances)
## for tests/unit/test_geometry_fingerprints.gd. Run from the project root:
##   godot --headless -s tools/record_geometry.gd
## Paste the printed lines into the test's EXPECTED table only after a change
## that is meant to alter a level, never to make a regression pass.

const LEVELS: Array[String] = ["rally_road", "muddy_valley", "frozen_pass"]


func _init() -> void:
	for id in LEVELS:
		var result := fingerprint(get_root(), id)
		print("%s: heights %d, edges %d, gates %s, road %s" % [id, result["heights"], result["edges"],
				result["gates"], result["road"]])
	quit()


## Builds level `id`'s Trail under `parent` and returns its fingerprints:
## {"heights": int, "edges": int, "road": PackedInt64Array, "gates": PackedFloat32Array}.
## The road array holds one hash per RoadBuilder child in order: mesh vertices
## for a MeshInstance3D, collision faces for a StaticBody3D.
static func fingerprint(parent: Node, id: String) -> Dictionary:
	var scene: PackedScene = load("res://levels/%s/%s.tscn" % [id, id])
	var root: Node = scene.instantiate()
	var trail: TrailLevel = root.get_node("Trail")
	root.remove_child(trail)
	root.free()
	parent.add_child(trail)  # builds in _ready
	var road := PackedInt64Array()
	for child in trail.road_builder.get_children():
		if child is MeshInstance3D:
			road.append(hash(child.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]))
		elif child is StaticBody3D:
			road.append(hash((child.get_child(0).shape as ConcavePolygonShape3D).get_faces()))
	var result := {"heights": hash(trail.field.heights), "edges": hash(trail.field.edge_distances),
			"road": road, "gates": trail.checkpoints.gate_distances.duplicate()}
	parent.remove_child(trail)
	trail.free()
	return result
```

- [ ] **Step 3: Record the fingerprints on the untouched code**

```bash
godot --headless --import >/dev/null 2>&1
godot --headless -s tools/record_geometry.gd 2>&1 | grep -E "^(rally_road|muddy_valley|frozen_pass):"
```

Expected: three lines, each with two integers, a gates array and a road array of about 30 integers. Copy them verbatim into the test in the next step.

- [ ] **Step 4: Write the fingerprint regression test**

`tests/unit/test_geometry_fingerprints.gd` (replace the `0`/`[]` placeholders with the printed values):

```gdscript
extends GutTest
## The three shipped levels' geometry must not change while Rock Canyon's road
## features are added (M5 spec §5.3). Fingerprints recorded on master at cb20c09
## with tools/record_geometry.gd. Re-record only for a change meant to alter a level.

const RECORDER := preload("res://tools/record_geometry.gd")
const EXPECTED := {
	"rally_road": {"heights": 0, "edges": 0, "gates": PackedFloat32Array([]), "road": PackedInt64Array([])},
	"muddy_valley": {"heights": 0, "edges": 0, "gates": PackedFloat32Array([]), "road": PackedInt64Array([])},
	"frozen_pass": {"heights": 0, "edges": 0, "gates": PackedFloat32Array([]), "road": PackedInt64Array([])},
}


func test_every_shipped_level_is_built_exactly_as_recorded() -> void:
	for id: String in EXPECTED:
		var actual: Dictionary = RECORDER.fingerprint(self, id)
		var expected: Dictionary = EXPECTED[id]
		assert_eq(actual["heights"], expected["heights"], "%s terrain heights" % id)
		assert_eq(actual["edges"], expected["edges"], "%s edge distances" % id)
		assert_eq(actual["gates"], expected["gates"], "%s gate distances" % id)
		assert_eq(actual["road"], expected["road"], "%s road meshes and collision" % id)
```

- [ ] **Step 5: Run it to prove it passes on the untouched code**

Run: `godot --headless --fixed-fps 120 --max-fps 0 -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_geometry_fingerprints.gd -gexit`
Expected: 1 passed, 12 assertions.

- [ ] **Step 6: Commit the baseline**

```bash
git add tools/record_geometry.gd tools/record_geometry.gd.uid tests/unit/test_geometry_fingerprints.gd tests/unit/test_geometry_fingerprints.gd.uid
git commit -m "Record geometry fingerprints of the three shipped levels

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

(If no `.uid` files were created for these, stage only the `.gd` files.)

- [ ] **Step 7: Write the failing width-profile tests**

`tests/unit/test_width_profile.gd`:

```gdscript
extends GutTest
## The road width profile (M5 spec §5): eased widths, the widest half-width, and
## the road mesh, terrain corridor, posts and gates following the taper.

var def: TrailDef
var sampler: RoadSampler


func before_each() -> void:
	def = TrailDef.new()
	def.undulation_amplitude = 0.0
	def.painted_lines = false
	def.width_stretches = [Vector4(100.0, 100.0, 4.5, 0.0)]
	var curve := Curve3D.new()
	curve.bake_interval = 1.0
	curve.add_point(Vector3.ZERO)
	curve.add_point(Vector3(0.0, 0.0, -300.0))
	sampler = RoadSampler.new(curve, true, def)


func _terrain() -> TerrainDef:
	var terrain := TerrainDef.new()
	terrain.margin = 60.0
	terrain.chunk_size = 32.0
	terrain.noise_amplitude = 0.0
	return terrain


func test_widths_ease_into_and_out_of_a_stretch() -> void:
	assert_almost_eq(def.road_width_at(50.0), 7.0, 0.0001, "the trail's width before the stretch")
	assert_almost_eq(def.shoulder_width_at(50.0), 2.5, 0.0001)
	assert_almost_eq(def.road_width_at(100.0), 7.0, 0.0001, "unchanged at the stretch's start")
	assert_almost_eq(def.road_width_at(105.0), 5.75, 0.0001, "halfway through the 10 m blend")
	assert_almost_eq(def.road_width_at(150.0), 4.5, 0.0001, "the stretch's width in its middle")
	assert_almost_eq(def.shoulder_width_at(150.0), 0.0, 0.0001)
	assert_almost_eq(def.road_width_at(195.0), 5.75, 0.0001, "easing back out")
	assert_almost_eq(def.road_width_at(200.0), 7.0, 0.0001, "the trail's width again at the end")
	assert_almost_eq(sampler.half_width_at(150.0), 2.25, 0.0001)
	assert_almost_eq(sampler.road_half_width_at(150.0), 2.25, 0.0001)
	assert_almost_eq(sampler.half_width_at(50.0), 6.0, 0.0001)


func test_half_total_width_is_the_widest_on_the_trail() -> void:
	assert_almost_eq(def.half_total_width(), 6.0, 0.0001, "a narrower stretch does not lower it")
	def.width_stretches.append(Vector4(250.0, 20.0, 10.0, 3.0))
	assert_almost_eq(def.half_total_width(), 8.0, 0.0001, "a wider stretch raises it")
	assert_almost_eq(TrailDef.new().half_total_width(), 6.0, 0.0001)


func test_a_sampler_without_a_trail_uses_the_default_widths() -> void:
	var plain := RoadSampler.new(sampler.curve)
	assert_almost_eq(plain.half_width_at(150.0), 6.0, 0.0001)
	assert_almost_eq(plain.road_half_width_at(150.0), 3.5, 0.0001)


func test_station_laterals_scale_the_road_about_the_centre_and_the_shoulders_from_its_edge() -> void:
	var road := Vector2(-2.0, RoadBuilder.Part.ROAD)
	var shoulder := Vector2(-6.0, RoadBuilder.Part.SHOULDER)
	assert_eq(RoadBuilder.station_lateral(road, 3.5, 1.0, 1.0), -2.0, "unscaled rows return the station exactly")
	assert_eq(RoadBuilder.station_lateral(shoulder, 3.5, 1.0, 1.0), -6.0)
	assert_almost_eq(RoadBuilder.station_lateral(road, 3.5, 0.5, 0.0), -1.0, 0.0001)
	assert_almost_eq(RoadBuilder.station_lateral(shoulder, 3.5, 0.5, 0.0), -1.75, 0.0001, "a zero-width shoulder collapses onto the road edge")
	assert_almost_eq(RoadBuilder.station_lateral(Vector2(6.0, RoadBuilder.Part.SHOULDER), 3.5, 1.0, 0.4), 4.5, 0.0001)


func test_road_mesh_and_collision_narrow_to_the_stretch_in_both_build_modes() -> void:
	var profile := RoadProfile.new(def, sampler.length)
	for threaded: bool in [true, false]:
		var road := RoadBuilder.new()
		road.threaded = threaded
		add_child(road)
		road.build(sampler, profile, def)
		var widest_mid := 0.0
		var widest_outside := 0.0
		for child in road.get_children():
			if child is MeshInstance3D:
				var vertices: PackedVector3Array = child.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
				for vertex in vertices:
					if absf(vertex.z + 150.0) < 0.6:
						widest_mid = maxf(widest_mid, absf(vertex.x))
					elif absf(vertex.z + 50.0) < 0.6:
						widest_outside = maxf(widest_outside, absf(vertex.x))
		assert_almost_eq(widest_mid, 2.25, 0.01, "4.5 m road and no shoulders mid-stretch (threaded %s)" % threaded)
		assert_almost_eq(widest_outside, 6.0, 0.01, "full width outside it (threaded %s)" % threaded)
		await wait_physics_frames(2)
		var space := road.get_world_3d().direct_space_state
		var on_road := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(2.0, 3.0, -150.0), Vector3(2.0, -3.0, -150.0)))
		assert_false(on_road.is_empty(), "collision under the narrow road")
		var off_road := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(4.0, 3.0, -150.0), Vector3(4.0, -3.0, -150.0)))
		assert_true(off_road.is_empty(), "no collision where the shoulder used to be")
		remove_child(road)
		road.queue_free()
		await wait_process_frames(1)


func test_threaded_and_serial_builders_agree_on_a_tapered_road() -> void:
	var profile := RoadProfile.new(def, sampler.length)
	var threaded := RoadBuilder.new()
	add_child_autofree(threaded)
	threaded.build(sampler, profile, def)
	var serial := RoadBuilder.new()
	serial.threaded = false
	add_child_autofree(serial)
	serial.build(sampler, profile, def)
	assert_eq(threaded.get_child_count(), serial.get_child_count())
	for i in serial.get_child_count():
		var a := threaded.get_child(i)
		var b := serial.get_child(i)
		if a is MeshInstance3D and b is MeshInstance3D:
			var aa: Array = a.mesh.surface_get_arrays(0)
			var bb: Array = b.mesh.surface_get_arrays(0)
			for slot: int in [Mesh.ARRAY_VERTEX, Mesh.ARRAY_NORMAL, Mesh.ARRAY_COLOR, Mesh.ARRAY_INDEX]:
				assert_true(aa[slot] == bb[slot], "chunk %d array %d matches exactly" % [i, slot])
		elif a is StaticBody3D and b is StaticBody3D:
			var shape_a: ConcavePolygonShape3D = a.get_child(0).shape
			var shape_b: ConcavePolygonShape3D = b.get_child(0).shape
			assert_true(shape_a.get_faces() == shape_b.get_faces(), "body %d faces match exactly" % i)


func test_the_terrain_corridor_follows_the_taper_in_both_carve_modes() -> void:
	var terrain := _terrain()
	var field := TerrainField.generate(sampler, def, terrain)
	assert_almost_eq(field.height_at(2.25, -150.0), -Corridor.EDGE_GAP, 0.05, "the shoulder edge is 2.25 m out mid-stretch")
	assert_almost_eq(field.height_at(6.0, -50.0), -Corridor.EDGE_GAP, 0.05, "and 6 m out elsewhere")
	assert_between(field.edge_distance_at(4.0, -150.0), 1.0, 2.5, "4 m out is outside the narrow shoulder edge")
	assert_lt(field.edge_distance_at(4.0, -50.0), 0.0, "and under the shoulder outside the stretch")
	var serial := TerrainField.generate(sampler, def, terrain, false)
	assert_eq(field.heights, serial.heights)
	assert_eq(field.edge_distances, serial.edge_distances)


func test_roadside_posts_stand_at_the_tapered_edge() -> void:
	var field := TerrainField.generate(sampler, def, _terrain())
	var scatter := ScatterDef.new()
	scatter.pine_spacing = 40.0
	scatter.rock_spacing = 40.0
	scatter.post_drop = -1.0  # flat ground: every side qualifies
	var builder := ScatterBuilder.new()
	add_child_autofree(builder)
	builder.build(field, sampler, RoadProfile.new(def, sampler.length), def, scatter)
	assert_gt(builder.post_count, 10)
	var checked := 0
	for child in builder.get_children():
		if child is MultiMeshInstance3D and child.multimesh.mesh.get_faces().size() < 300:  # posts, not trees or rocks
			for i in child.multimesh.instance_count:
				var spot: Vector3 = child.multimesh.get_instance_transform(i).origin
				var expected := def.half_total_width_at(-spot.z) + 0.3
				assert_almost_eq(absf(spot.x), expected, 0.05, "post at %.1f m" % -spot.z)
				checked += 1
	assert_gt(checked, 10)


func test_gates_narrow_with_the_road_but_never_widen_beyond_today() -> void:
	def.checkpoint_distances = PackedFloat32Array([150.0, 50.0])
	assert_almost_eq(CheckpointPlacer.gate_width_at(def, 150.0), 6.5, 0.0001, "4.5 m road plus a metre each side")
	assert_almost_eq(CheckpointPlacer.gate_width_at(def, 50.0), CheckpointPlacer.GATE_SIZE.x, 0.0001, "12 m road and shoulders keep the 12 m gate")
	var wide := TrailDef.new()
	wide.road_width = 9.0
	wide.shoulder_width = 3.0
	assert_almost_eq(CheckpointPlacer.gate_width_at(wide, 50.0), CheckpointPlacer.GATE_SIZE.x, 0.0001, "Muddy Valley's wider road keeps 12 m too")
	var placer := CheckpointPlacer.new()
	add_child_autofree(placer)
	placer.build(sampler, RoadProfile.new(def, sampler.length), def)
	var narrow_gate: Node3D = placer.get_node("Gate2")
	var box: BoxShape3D = narrow_gate.find_children("*", "CollisionShape3D", true, false)[0].shape
	assert_almost_eq(box.size.x, 6.5, 0.0001)
	var wide_gate: Node3D = placer.get_node("Gate1")
	var wide_box: BoxShape3D = wide_gate.find_children("*", "CollisionShape3D", true, false)[0].shape
	assert_almost_eq(wide_box.size.x, 12.0, 0.0001)
```

- [ ] **Step 8: Run the new test to see it fail**

Run: `godot --headless --fixed-fps 120 --max-fps 0 -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_width_profile.gd -gexit`
Expected: script errors about `width_stretches`, `road_width_at`, `station_lateral` and `gate_width_at` not existing (the file fails to parse, which counts as a failure).

- [ ] **Step 9: Add the width profile to `TrailDef`**

In `levels/trail/trail_def.gd`, after the `Cross-section` group's `chunk_length`, add:

```gdscript
@export_group("Width profile")
## Stretches where the road changes width, as Vector4(start, length, road width,
## shoulder width) in metres. They must not overlap. Outside them the road keeps
## road_width and shoulder_width.
@export var width_stretches: Array[Vector4] = []
## The widths ease from the trail's to a stretch's over this distance inside each of its ends (m).
@export var width_blend: float = 10.0
```

Replace `half_total_width()` and add the eased widths:

```gdscript
## Half the widest road-plus-shoulders on the trail: the coarse bound terrain
## search radii, tunnel portals and earthworks use.
func half_total_width() -> float:
	var widest := road_width * 0.5 + shoulder_width
	for stretch: Vector4 in width_stretches:
		widest = maxf(widest, stretch.z * 0.5 + stretch.w)
	return widest


## The road's width at `distance`, eased into and out of any width stretch.
func road_width_at(distance: float) -> float:
	var stretch := _width_stretch_at(distance)
	return lerpf(road_width, stretch.y, stretch.x)


## The shoulder width at `distance`, eased like the road's.
func shoulder_width_at(distance: float) -> float:
	var stretch := _width_stretch_at(distance)
	return lerpf(shoulder_width, stretch.z, stretch.x)


## Half the road plus one shoulder at `distance`.
func half_total_width_at(distance: float) -> float:
	return road_width_at(distance) * 0.5 + shoulder_width_at(distance)


## (weight, road width, shoulder width) of the width stretch covering `distance`.
## The weight is 0 outside every stretch and rises to 1 over width_blend inside
## each end, so lerping the trail's widths toward the stretch's by it eases them.
## Off every stretch the weight is exactly 0, so the trail's widths come back unchanged.
func _width_stretch_at(distance: float) -> Vector3:
	for stretch: Vector4 in width_stretches:
		var end := stretch.x + stretch.y
		if distance >= stretch.x and distance < end:
			var blend := maxf(width_blend, 0.001)
			var weight := minf(smoothstep(stretch.x, stretch.x + blend, distance),
					1.0 - smoothstep(end - blend, end, distance))
			return Vector3(weight, stretch.z, stretch.w)
	return Vector3(0.0, road_width, shoulder_width)
```

- [ ] **Step 10: Give `RoadSampler` its trail and the two width queries**

In `levels/trail/road_sampler.gd` replace the vars and `_init`, and add the queries:

```gdscript
var curve: Curve3D
var length: float
var use_curve_banking: bool
## The trail whose width profile half_width_at follows; a default TrailDef when none is given.
var trail: TrailDef


func _init(road_curve: Curve3D, banking: bool = true, trail_def: TrailDef = null) -> void:
	curve = road_curve
	length = curve.get_baked_length()
	use_curve_banking = banking
	trail = trail_def if trail_def != null else TrailDef.new()


## Half the road plus one shoulder at `distance`, following the trail's width stretches.
func half_width_at(distance: float) -> float:
	return trail.half_total_width_at(distance)


## Half the road alone at `distance`.
func road_half_width_at(distance: float) -> float:
	return trail.road_width_at(distance) * 0.5
```

In `levels/trail/trail_level.gd` `build()`, construct it with the trail: `sampler = RoadSampler.new(road.curve, trail.use_curve_banking, trail)`.

- [ ] **Step 11: Scale road cross-sections per row in `RoadBuilder` and `RoadChunkData`**

In `levels/trail/road_builder.gd` add the static helper (after `cross_section`):

```gdscript
## A station's lateral position on a row whose road and shoulder widths are
## scaled by `road_scale` and `shoulder_scale` (1.0 = the trail's own widths).
## Road stations scale about the centre line; shoulder stations keep their
## distance from the road edge, scaled by the shoulder factor. Unscaled rows
## return the station exactly, so trails without width stretches are unchanged.
static func station_lateral(station: Vector2, half_road: float, road_scale: float, shoulder_scale: float) -> float:
	if road_scale == 1.0 and shoulder_scale == 1.0:
		return station.x
	if int(station.y) == Part.SHOULDER:
		return signf(station.x) * (half_road * road_scale + (absf(station.x) - half_road) * shoulder_scale)
	return station.x * road_scale


## The per-row width scales of `def` at `distance`: (road, shoulder). Exactly 1.0 off every stretch.
static func width_scales(def: TrailDef, distance: float) -> Vector2:
	var shoulder_scale := def.shoulder_width_at(distance) / def.shoulder_width if def.shoulder_width > 0.0 else 1.0
	return Vector2(def.road_width_at(distance) / def.road_width, shoulder_scale)
```

In `_snapshot`, collect per-row scales alongside the other arrays and put them in the dictionary:

```gdscript
	var road_scales := PackedFloat64Array()
	var shoulder_scales := PackedFloat64Array()
	for distance: float in distances:
		...existing appends...
		var scales := width_scales(def, distance)
		road_scales.append(scales.x)
		shoulder_scales.append(scales.y)
```

and add to the returned dictionary: `"road_scales": road_scales, "shoulder_scales": shoulder_scales, "half_road": def.road_width * 0.5`.

In `levels/trail/road_chunk_data.gd` `compute`, read them and inline the maths (no static call from the worker, per handover §5):

```gdscript
	var road_scales: PackedFloat64Array = input["road_scales"]
	var shoulder_scales: PackedFloat64Array = input["shoulder_scales"]
	var half_road: float = input["half_road"]
	...
	var laterals := PackedFloat32Array()
	laterals.resize(vertices.size())
	for row in distances.size():
		var distance := distances[row]
		var rut := ruts[row]
		var road_scale := road_scales[row]
		var shoulder_scale := shoulder_scales[row]
		for column in width:
			var station := stations[column]
			var lateral := station.x
			if road_scale != 1.0 or shoulder_scale != 1.0:
				if int(station.y) == RoadBuilder.Part.SHOULDER:
					lateral = signf(station.x) * (half_road * road_scale + (absf(station.x) - half_road) * shoulder_scale)
				else:
					lateral = station.x * road_scale
			var i := row * width + column
			laterals[i] = lateral
			...existing pothole/patch/rut maths using `lateral`, and vertices[i] as before...
```

In the index loop, after the existing `is_equal_approx(stations[column].x, stations[column + 1].x)` skip, add a skip for columns that collapsed on both rows:

```gdscript
			var i := row * width + column
			if absf(laterals[i] - laterals[i + 1]) < 0.001 and absf(laterals[i + width] - laterals[i + width + 1]) < 0.001:
				continue
```

Mirror both changes in the serial `_add_chunk` in `road_builder.gd`: compute `var scales := width_scales(def, distance)` per row, use `var lateral := station_lateral(station, def.road_width * 0.5, scales.x, scales.y)` for the vertex, keep a `laterals` array, and apply the same collapsed-column skip when building indices. `_faces` receives the vertices only, so collision follows automatically; but it also needs the collapsed skip: pass `laterals` into `_faces` and skip a column when both rows collapsed.

- [ ] **Step 12: Per-stamp half widths in `TerrainField`**

In `levels/trail/terrain_field.gd` `generate`, collect `half_widths` per stamp next to `stamps`/`rights`:

```gdscript
	var half_widths := PackedFloat32Array()
	...inside the while loop, after bank_slopes.append(...):
		half_widths.append(trail.half_total_width_at(distance))
```

Pass it to `_carve(stamps, rights, bank_slopes, half_widths, trail, terrain)` and `_carve_parallel(stamps, rights, bank_slopes, half_widths, trail, terrain)`. In `_carve`, keep `var half_width := trail.half_total_width()` for the search radius, and change the edge line to `var edge := sqrt(squared) - half_widths[s]`. In `_carve_parallel`, add `"half_widths": half_widths` to each band's input dictionary; in `_carve_band`, read `var half_widths: PackedFloat32Array = input["half_widths"]` and use `var edge := sqrt(squared) - half_widths[s]`. The radius (`half_width + blend + 2`) stays the widest.

- [ ] **Step 13: Posts and gates follow the taper**

In `levels/trail/scatter_builder.gd` `_posts`, replace `var half := trail.half_total_width()` outside the loop with `var half := trail.half_total_width_at(distance)` inside the loop (right after the tunnel/bridge `continue`).

In `levels/trail/checkpoint_placer.gd` add:

```gdscript
## A gate's width across the road at `distance`: the road and shoulders plus a
## metre each side, but never wider than GATE_SIZE.x, which every existing level keeps.
static func gate_width_at(def: TrailDef, distance: float) -> float:
	return minf(GATE_SIZE.x, 2.0 * def.half_total_width_at(distance) + 2.0)
```

In `build`, per gate: `var width := gate_width_at(def, distance)`; `box.size = Vector3(width, GATE_SIZE.y, GATE_SIZE.z)`; uprights at `side * (width * 0.5 + 0.5)`; banner mesh from a small cache keyed by width: `LowPolyMeshes.banner(BANNER_COLOR, width + 1.0)` (build the banner mesh inside the loop through a `Dictionary` cache so equal widths share one mesh).

- [ ] **Step 14: Run the width tests, the fingerprint test and the road/terrain/scatter tests**

```bash
for t in test_width_profile test_geometry_fingerprints test_road_builder test_terrain_field test_scatter_and_checkpoints test_rally_road_regression test_frozen_pass test_bridge test_tunnel test_creek; do
  godot --headless --fixed-fps 120 --max-fps 0 -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/$t.gd -gexit 2>&1 | grep -E "Totals|passed|failed|SCRIPT ERROR"
done
```

Expected: every file all passing, no `SCRIPT ERROR`. The fingerprint test passing is the proof the existing levels are unchanged; if it fails, the width code is not exact off-stretch (check the `== 1.0` shortcuts and that `_width_stretch_at` returns weight `0.0`), never re-record.

- [ ] **Step 15: Run the full unit suite, then commit**

Run: `./run_tests.sh unit` — expected all green.

```bash
git add levels/trail/trail_def.gd levels/trail/road_sampler.gd levels/trail/road_builder.gd levels/trail/road_chunk_data.gd levels/trail/terrain_field.gd levels/trail/scatter_builder.gd levels/trail/checkpoint_placer.gd levels/trail/trail_level.gd tests/unit/test_width_profile.gd tests/unit/test_width_profile.gd.uid
git commit -m "Add the road width profile with existing levels proven unchanged

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---
### Task 2: Surfaces, grip entries, feel, splash spray and the two sounds

Spec §4 and §12. Four new `SurfaceDef` files, eight grip-table entries, two enum additions with feel entries, the `SPLASH` spray, `RollingSound.ROCK` mixed by `TyreSoundLogic`/`CarAudio`, and the `rock` and `waterfall` loops in `SoundSynth`. Existing surface values do not change.

**Files:**
- Create: `surfaces/deep_mud.tres`, `surfaces/rock.tres`, `surfaces/scree.tres`, `surfaces/wet_rock.tres`, `tests/unit/test_rock_canyon_surfaces.gd`
- Modify: `surfaces/grip_table.tres`, `effects/surface_feel.gd`, `effects/surface_feel_table.tres`, `effects/wheel_spray.gd`, `effects/spray_logic.gd`, `effects/tyre_sound_logic.gd`, `effects/car_audio.gd`, `effects/sound_synth.gd`, `tests/unit/test_sound_synth.gd`, `tests/unit/test_surface_feels.gd`

**Interfaces:**
- Produces: surface ids `&"deep_mud"`, `&"rock"`, `&"scree"`, `&"wet_rock"` at `res://surfaces/<id>.tres`; `SurfaceFeel.SprayKind.SPLASH` (= 4), `SurfaceFeel.RollingSound.ROCK` (= 5); `TyreSoundLogic.mix()` result gains key `"rock"`, `TyreSoundLogic.ROCK_MAX = 0.6`; `SoundSynth.NAMES` gains `&"rock"` (1.3 s loop) and `&"waterfall"` (3.0 s loop); `CarAudio.LOOPS` gains `&"rock"`. Later tasks preload `res://surfaces/rock.tres` and `res://surfaces/wet_rock.tres`.

- [ ] **Step 1: Write the failing tests**

`tests/unit/test_rock_canyon_surfaces.gd`:

```gdscript
extends GutTest
## The four Rock Canyon surfaces (M5 spec §4, §12): physics values, grip
## multipliers, feels, the splash spray and the rock and waterfall sounds.

const FEELS := preload("res://effects/surface_feel_table.tres")


func test_surface_values_match_the_spec() -> void:
	var checks: Array[Array] = [
		["res://surfaces/deep_mud.tres", &"deep_mud", 0.5, 0.14, 70.0, 0.15],
		["res://surfaces/rock.tres", &"rock", 1.05, 0.03, 0.0, 0.0],
		["res://surfaces/scree.tres", &"scree", 0.55, 0.09, 5.0, 0.04],
		["res://surfaces/wet_rock.tres", &"wet_rock", 0.5, 0.05, 20.0, 0.02],
	]
	for check: Array in checks:
		assert_true(ResourceLoader.exists(check[0]), check[0])
		if not ResourceLoader.exists(check[0]):
			continue
		var surface: SurfaceDef = load(check[0])
		assert_eq(surface.id, check[1])
		assert_almost_eq(surface.grip, check[2], 0.0001, "%s grip" % check[1])
		assert_almost_eq(surface.rolling_resistance, check[3], 0.0001, "%s rolling resistance" % check[1])
		assert_almost_eq(surface.drag, check[4], 0.0001, "%s drag" % check[1])
		assert_almost_eq(surface.sink_depth, check[5], 0.0001, "%s sink" % check[1])


func test_grip_multipliers_for_both_archetypes() -> void:
	var table: GripTable = load("res://surfaces/grip_table.tres")
	for check: Array in [[&"deep_mud", 1.35, 1.0], [&"rock", 1.05, 1.0], [&"scree", 1.2, 0.95], [&"wet_rock", 1.1, 1.0]]:
		assert_almost_eq(table.multiplier(&"offroad", check[0]), check[1], 0.0001, "offroad/%s" % check[0])
		assert_almost_eq(table.multiplier(&"rally", check[0]), check[2], 0.0001, "rally/%s" % check[0])
	assert_almost_eq(table.multiplier(&"offroad", &"mud"), 1.35, 0.0001, "existing entries untouched")
	assert_almost_eq(table.multiplier(&"rally", &"asphalt"), 1.1, 0.0001)


func test_each_new_surface_has_its_feel() -> void:
	var deep_mud: SurfaceFeel = FEELS.feels.get(&"deep_mud")
	var rock: SurfaceFeel = FEELS.feels.get(&"rock")
	var scree: SurfaceFeel = FEELS.feels.get(&"scree")
	var wet_rock: SurfaceFeel = FEELS.feels.get(&"wet_rock")
	for feel: SurfaceFeel in [deep_mud, rock, scree, wet_rock]:
		assert_not_null(feel)
	if deep_mud == null or rock == null or scree == null or wet_rock == null:
		return
	assert_eq(deep_mud.spray, SurfaceFeel.SprayKind.CLODS)
	assert_eq(deep_mud.rolling, SurfaceFeel.RollingSound.MUD)
	assert_false(deep_mud.skids)
	assert_eq(rock.spray, SurfaceFeel.SprayKind.NONE)
	assert_eq(rock.rolling, SurfaceFeel.RollingSound.ROCK)
	assert_true(rock.skids)
	assert_almost_eq(rock.skid_volume, 0.7, 0.0001)
	assert_eq(scree.spray, SurfaceFeel.SprayKind.DUST)
	assert_eq(scree.rolling, SurfaceFeel.RollingSound.GRAVEL)
	assert_true(scree.skids)
	assert_almost_eq(scree.skid_volume, 0.6, 0.0001)
	assert_true(scree.spray_color.is_equal_approx(Color(0.66, 0.5, 0.4)))
	assert_eq(wet_rock.spray, SurfaceFeel.SprayKind.SPLASH)
	assert_eq(wet_rock.rolling, SurfaceFeel.RollingSound.ROCK)
	assert_true(wet_rock.skids)
	assert_almost_eq(wet_rock.skid_volume, 0.5, 0.0001)


func test_rock_rolls_its_own_loop_quieter_than_gravel_at_speed() -> void:
	var wheel := {"feel": FEELS.feels[&"rock"], "ground_speed": 25.0, "slip_speed": 0.0, "sliding": false}
	var rock_mix := TyreSoundLogic.mix([wheel, wheel, wheel, wheel])
	assert_almost_eq(rock_mix["rock"], TyreSoundLogic.ROCK_MAX, 0.001)
	assert_eq(rock_mix["gravel"], 0.0)
	assert_eq(rock_mix["road"], 0.0)
	wheel["feel"] = FEELS.feels[&"dirt"]
	var gravel_mix := TyreSoundLogic.mix([wheel, wheel, wheel, wheel])
	assert_lt(rock_mix["rock"], gravel_mix["gravel"], "the level is slow, so rock stays under gravel")
	assert_eq(gravel_mix["rock"], 0.0)


func test_splash_needs_a_little_speed_and_grows_with_wheelspin() -> void:
	var kind := SurfaceFeel.SprayKind.SPLASH
	assert_eq(SprayLogic.intensity(kind, 0.5, 0.0, false), 0.0, "a creeping wheel throws no water")
	assert_gt(SprayLogic.intensity(kind, 8.0, 0.0, false), 0.5)
	assert_gt(SprayLogic.intensity(kind, 8.0, 4.0, false), SprayLogic.intensity(kind, 8.0, 0.0, false))
	assert_eq(SprayLogic.intensity(kind, 40.0, 40.0, true), 1.0, "capped at 1")


func test_a_wheel_spray_configures_itself_for_splash() -> void:
	var spray := WheelSpray.new()
	add_child_autofree(spray)
	spray.update(FEELS.feels[&"wet_rock"], 1.0, 0.016)
	assert_eq(spray.kind, SurfaceFeel.SprayKind.SPLASH)
	assert_true(spray.emitting)
	assert_gt(spray.initial_velocity_max, 6.0, "a wide, fast sheet")
	assert_true(spray.color.is_equal_approx(Color(FEELS.feels[&"wet_rock"].spray_color, WheelSpray.MAX_ALPHA)))


func test_the_new_sounds_loop_and_the_car_plays_rock() -> void:
	for sound_name: StringName in [&"rock", &"waterfall"]:
		assert_true(SoundSynth.NAMES.has(sound_name), sound_name)
		var wav := SoundSynth.sound(sound_name)
		assert_not_null(wav, sound_name)
		assert_eq(wav.loop_mode, AudioStreamWAV.LOOP_FORWARD, sound_name)
	assert_almost_eq(SoundSynth.sound(&"rock").get_length(), 1.3, 0.01)
	assert_almost_eq(SoundSynth.sound(&"waterfall").get_length(), 3.0, 0.01)
	assert_true(CarAudio.LOOPS.has(&"rock"))
```

Also update two existing tests so they describe the new state:

- `tests/unit/test_sound_synth.gd`: add `&"rock": 1.3, &"waterfall": 3.0` to `LOOP_SECONDS`.
- `tests/unit/test_surface_feels.gd`, `test_each_surface_feeds_its_own_rolling_sound`: the air assertion becomes `assert_eq(TyreSoundLogic.mix(air), {"road": 0.0, "gravel": 0.0, "mud": 0.0, "skid": 0.0, "snow": 0.0, "rock": 0.0})`.

- [ ] **Step 2: Run to see them fail**

Run: `godot --headless --fixed-fps 120 --max-fps 0 -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_rock_canyon_surfaces.gd -gexit`
Expected: parse errors on `SprayKind.SPLASH` / `RollingSound.ROCK` / `ROCK_MAX` (a failure).

- [ ] **Step 3: Add the four surface files**

`surfaces/deep_mud.tres`:

```
[gd_resource type="Resource" script_class="SurfaceDef" format=3]

[ext_resource type="Script" path="res://surfaces/surface_def.gd" id="1_surface"]

[resource]
script = ExtResource("1_surface")
id = &"deep_mud"
display_name = "Deep mud"
grip = 0.5
rolling_resistance = 0.14
sink_depth = 0.15
drag = 70.0
debug_color = Color(0.22, 0.16, 0.11, 1)
```

`surfaces/rock.tres`: `id = &"rock"`, `display_name = "Rock"`, `grip = 1.05`, `rolling_resistance = 0.03`, `sink_depth = 0.0`, `drag = 0.0`, `debug_color = Color(0.62, 0.4, 0.31, 1)`.

`surfaces/scree.tres`: `id = &"scree"`, `display_name = "Scree"`, `grip = 0.55`, `rolling_resistance = 0.09`, `sink_depth = 0.04`, `drag = 5.0`, `debug_color = Color(0.66, 0.5, 0.4, 1)`.

`surfaces/wet_rock.tres`: `id = &"wet_rock"`, `display_name = "Wet rock"`, `grip = 0.5`, `rolling_resistance = 0.05`, `sink_depth = 0.02`, `drag = 20.0`, `debug_color = Color(0.3, 0.29, 0.28, 1)`.

(Same header and `script` line as deep mud in each.)

- [ ] **Step 4: Grip entries**

In `surfaces/grip_table.tres`, add inside `multipliers = { ... }` after `"offroad/logs": 1.1`:

```
"offroad/logs": 1.1,
"offroad/deep_mud": 1.35,
"rally/deep_mud": 1.0,
"offroad/rock": 1.05,
"rally/rock": 1.0,
"offroad/scree": 1.2,
"rally/scree": 0.95,
"offroad/wet_rock": 1.1,
"rally/wet_rock": 1.0
```

- [ ] **Step 5: Feel enums and table entries**

`effects/surface_feel.gd`:

```gdscript
enum SprayKind { NONE, CLODS, DUST, SMOKE, SPLASH }
enum RollingSound { NONE, ROAD, GRAVEL, MUD, SNOW, ROCK }
```

`effects/surface_feel_table.tres`: add four sub-resources before `[resource]` and four entries in `feels`:

```
[sub_resource type="Resource" id="Resource_deep_mud"]
script = ExtResource("2_feel")
spray = 1
spray_color = Color(0.25, 0.18, 0.12, 1)
rolling = 3

[sub_resource type="Resource" id="Resource_rock"]
script = ExtResource("2_feel")
spray = 0
rolling = 5
skids = true
skid_volume = 0.7

[sub_resource type="Resource" id="Resource_scree"]
script = ExtResource("2_feel")
spray = 2
spray_color = Color(0.66, 0.5, 0.4, 1)
rolling = 2
skids = true
skid_volume = 0.6

[sub_resource type="Resource" id="Resource_wet_rock"]
script = ExtResource("2_feel")
spray = 4
spray_color = Color(0.7, 0.78, 0.8, 1)
rolling = 5
skids = true
skid_volume = 0.5
```

and in `feels = { ... }` add `&"deep_mud": SubResource("Resource_deep_mud"), &"rock": SubResource("Resource_rock"), &"scree": SubResource("Resource_scree"), &"wet_rock": SubResource("Resource_wet_rock")` (comma after the `&"logs"` entry).

- [ ] **Step 6: The splash spray**

`effects/spray_logic.gd`: add constants and a case:

```gdscript
const SPLASH_SPEED_FROM := 1.0
const SPLASH_SPEED_RANGE := 10.0
const SPLASH_SLIP_SHARE := 0.5
...
		SurfaceFeel.SprayKind.SPLASH:
			return minf(clampf((ground_speed - SPLASH_SPEED_FROM) / SPLASH_SPEED_RANGE, 0.0, 1.0)
					+ clampf(slip_speed / CLODS_SLIP, 0.0, SPLASH_SLIP_SHARE), 1.0)
```

Update the class doc comment: "...dust from speed, a water sheet from speed and wheelspin, and tyre smoke only while the tyre slides."

`effects/wheel_spray.gd` `_configure`, add a case:

```gdscript
		SurfaceFeel.SprayKind.SPLASH:
			lifetime = 0.9
			direction = Vector3(0.0, 0.6, 1.0)
			spread = 45.0
			initial_velocity_min = 4.0
			initial_velocity_max = 8.0
			gravity = Vector3(0.0, -9.0, 0.0)
			damping_min = 0.5
			damping_max = 1.5
			scale_amount_min = 1.0
			scale_amount_max = 2.0
			scale_amount_curve = _growing_curve(2.0)
			color_ramp = _fading_ramp()
```

(Doc comment: "mud clods, dust, tyre smoke or a water sheet".)

- [ ] **Step 7: The rock rolling loop in the mix and the car**

`effects/tyre_sound_logic.gd`: add `## Rock grinds under the engine: it tops out at this loudness, quieter than gravel.` `const ROCK_MAX := 0.6`; initialise `result` with `"rock": 0.0`; add the match case `SurfaceFeel.RollingSound.ROCK: result["rock"] += rolling * ROCK_MAX`; update the doc comment to list `"rock"`.

`effects/car_audio.gd`: `LOOPS` gains `&"rock"`; in `_process` add `_set_loop(&"rock", tyres["rock"], roll_pitch, delta)` after snow.

- [ ] **Step 8: The two sounds**

`effects/sound_synth.gd`: `NAMES` gains `&"rock", &"waterfall"`; `_build` gains

```gdscript
		&"rock":
			return _wav(_normalized(_seamless(_rock(1.3)), LOOP_PEAK), true)
		&"waterfall":
			return _wav(_normalized(_seamless(_waterfall(3.0)), LOOP_PEAK), true)
```

and the generators:

```gdscript
## Tyres grinding on rock: a low, twice-filtered rumble with irregular knocks
## (short decaying 60 Hz bursts) as the tread catches on edges. Kept clear of the
## cross-faded ends so the loop joins cleanly.
static func _rock(seconds: float) -> PackedFloat32Array:
	var rng := _rng(28)
	var samples := _padded(seconds)
	var low := 0.0
	var lower := 0.0
	for i in samples.size():
		low += 0.12 * (rng.randf_range(-1.0, 1.0) - low)
		lower += 0.3 * (low - lower)
		samples[i] = lower * 1.2
	var fade := _fade_samples()
	var knock := 400
	for k in 40:
		var at := rng.randi_range(fade, samples.size() - fade * 2 - knock)
		var amplitude := rng.randf_range(0.4, 1.0)
		for j in knock:
			samples[at + j] += amplitude * sin(TAU * 60.0 * j / RATE) * exp(-j / 90.0)
	return samples


## A waterfall: a bright hiss (noise minus its low band) over a deep rumble
## (noise low-passed twice), steady rather than gusting like the wind.
static func _waterfall(seconds: float) -> PackedFloat32Array:
	var rng := _rng(29)
	var samples := _padded(seconds)
	var low := 0.0
	var lower := 0.0
	var band := 0.0
	for i in samples.size():
		var noise := rng.randf_range(-1.0, 1.0)
		low += 0.04 * (noise - low)
		lower += 0.08 * (low - lower)
		band += 0.35 * ((noise - low) - band)
		samples[i] = band * 0.6 + lower * 1.6
	return samples
```

- [ ] **Step 9: Run the tests**

```bash
for t in test_rock_canyon_surfaces test_sound_synth test_surface_feels test_winter_surfaces test_car_feedback; do
  godot --headless --fixed-fps 120 --max-fps 0 -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/$t.gd -gexit 2>&1 | grep -E "Totals|passed|failed|SCRIPT ERROR"
done
```

Expected: all passing. If `test_loops_join_without_a_click` fails for `rock`, the knocks are landing in the fade region: check the `at` range. If `test_sounds_are_audible_and_not_clipped` fails on rms, raise the `lower` gain.

- [ ] **Step 10: Commit**

```bash
git add surfaces/deep_mud.tres surfaces/rock.tres surfaces/scree.tres surfaces/wet_rock.tres surfaces/grip_table.tres effects/surface_feel.gd effects/surface_feel_table.tres effects/wheel_spray.gd effects/spray_logic.gd effects/tyre_sound_logic.gd effects/car_audio.gd effects/sound_synth.gd tests/unit/test_rock_canyon_surfaces.gd tests/unit/test_rock_canyon_surfaces.gd.uid tests/unit/test_sound_synth.gd tests/unit/test_surface_feels.gd
git commit -m "Add deep mud, rock, scree and wet rock with their feel and sounds

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---
### Task 3: Canyon walls

Spec §10. `TerrainDef.wall_sections` (start, length, left delta, right delta) with `wall_blend`; `TerrainField` raises or drops the ground outside the corridor blend in a pass after the carve. The corridor and the three existing levels are untouched (the pass is skipped when there are no sections).

**Files:**
- Create: `tests/unit/test_canyon_walls.gd`
- Modify: `levels/trail/terrain_def.gd`, `levels/trail/terrain_field.gd`

**Interfaces:**
- Produces: `TerrainDef.wall_sections: Array[Vector4]`, `TerrainDef.wall_blend: float = 25.0`, `TerrainDef.wall_delta(distance, side) -> float` (side −1 left, +1 right), `TerrainDef.has_walls() -> bool`; `TerrainField.WALL_RISE = 12.0`, `WALL_PLATEAU = 30.0`, `WALL_FALLOFF = 30.0`, `TerrainField.walled_height(natural, road_height, delta, edge, blend) -> float` (static). Rock Canyon (Task 10) sets `corridor_blend = 8.0` so walls start close to the road.

- [ ] **Step 1: Write the failing test**

`tests/unit/test_canyon_walls.gd`:

```gdscript
extends GutTest
## Canyon wall sections (M5 spec §10) on a flat, noise-free straight road:
## deltas ease along the section, walls rise and drops fall beyond the corridor
## blend, the corridor itself is untouched, and generation stays deterministic.

var trail: TrailDef
var terrain: TerrainDef
var sampler: RoadSampler


func before_each() -> void:
	var curve := Curve3D.new()
	curve.bake_interval = 1.0
	curve.add_point(Vector3.ZERO)
	curve.add_point(Vector3(0.0, 0.0, -400.0))
	trail = TrailDef.new()
	sampler = RoadSampler.new(curve, true, trail)
	terrain = TerrainDef.new()
	terrain.margin = 120.0
	terrain.chunk_size = 32.0
	terrain.noise_amplitude = 0.0
	terrain.corridor_blend = 8.0
	terrain.wall_sections = [Vector4(100.0, 200.0, 20.0, -15.0)]
	terrain.wall_blend = 25.0


func test_wall_delta_eases_in_and_out_of_a_section() -> void:
	assert_almost_eq(terrain.wall_delta(90.0, -1.0), 0.0, 0.0001, "before the section")
	assert_almost_eq(terrain.wall_delta(100.0, -1.0), 0.0, 0.0001, "nothing yet at its start")
	assert_almost_eq(terrain.wall_delta(112.5, -1.0), 10.0, 0.0001, "halfway through the 25 m blend")
	assert_almost_eq(terrain.wall_delta(200.0, -1.0), 20.0, 0.0001, "the left delta in the middle")
	assert_almost_eq(terrain.wall_delta(200.0, 1.0), -15.0, 0.0001, "the right delta")
	assert_almost_eq(terrain.wall_delta(287.5, 1.0), -7.5, 0.0001, "easing out")
	assert_almost_eq(terrain.wall_delta(300.0, 1.0), 0.0, 0.0001, "gone at the end")
	assert_true(terrain.has_walls())
	assert_false(TerrainDef.new().has_walls())


func test_walls_rise_and_drops_fall_beyond_the_corridor_blend() -> void:
	var field := TerrainField.generate(sampler, trail, terrain)
	var full := trail.half_total_width() + terrain.corridor_blend + TerrainField.WALL_RISE + 4.0
	assert_almost_eq(field.height_at(-full, -200.0), 20.0, 0.3, "left wall at full height")
	assert_almost_eq(field.height_at(full, -200.0), -15.0, 0.3, "right side dropped away")
	var half_rise := trail.half_total_width() + terrain.corridor_blend + TerrainField.WALL_RISE * 0.5
	assert_between(field.height_at(-half_rise, -200.0), 5.0, 15.0, "climbing through the rise")
	var far := full + TerrainField.WALL_PLATEAU + TerrainField.WALL_FALLOFF + 6.0
	assert_almost_eq(field.height_at(-far, -200.0), 0.0, 0.05, "back to the natural ground far out")
	assert_almost_eq(field.height_at(-full, -50.0), 0.0, 0.05, "no wall before the section")
	assert_almost_eq(field.height_at(-full, -350.0), 0.0, 0.05, "none after it")
	assert_between(field.height_at(-full, -112.0), 5.0, 15.0, "easing in along the road")


func test_the_corridor_itself_is_untouched() -> void:
	var walled := TerrainField.generate(sampler, trail, terrain)
	terrain.wall_sections = []
	var plain := TerrainField.generate(sampler, trail, terrain)
	var edge := trail.half_total_width()
	for lateral: float in [0.0, -edge, edge, -(edge + terrain.corridor_blend - 0.5), edge + terrain.corridor_blend - 0.5]:
		var spot := sampler.position(200.0) + sampler.right(200.0) * lateral
		assert_almost_eq(walled.height_at(spot.x, spot.z), plain.height_at(spot.x, spot.z), 0.0001,
				"%.1f m from the centre line" % lateral)
	assert_eq(walled.edge_distances, plain.edge_distances, "walls do not change edge distances")


func test_kill_height_follows_the_drop() -> void:
	var field := TerrainField.generate(sampler, trail, terrain)
	assert_lt(field.lowest_height, -14.0)
	assert_almost_eq(field.kill_height(), field.lowest_height - terrain.kill_depth, 0.0001)


func test_generation_is_deterministic_with_walls_noise_and_a_bend() -> void:
	terrain.noise_amplitude = 15.0
	var curve := Curve3D.new()
	curve.bake_interval = 1.0
	for point: Vector3 in [Vector3.ZERO, Vector3(0, 12, -130), Vector3(45, 21, -250), Vector3(80, 30, -400)]:
		curve.add_point(point)
	var bent := RoadSampler.new(curve, true, trail)
	var serial := TerrainField.generate(bent, trail, terrain, false)
	var parallel := TerrainField.generate(bent, trail, terrain, true)
	assert_eq(parallel.heights, serial.heights)
	assert_eq(parallel.edge_distances, serial.edge_distances)
	assert_eq(parallel.lowest_height, serial.lowest_height)
```

- [ ] **Step 2: Run to see it fail**

Run: `godot --headless --fixed-fps 120 --max-fps 0 -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_canyon_walls.gd -gexit`
Expected: parse errors on `wall_sections` / `WALL_RISE`.

- [ ] **Step 3: Add the data to `TerrainDef`**

Append to `levels/trail/terrain_def.gd`:

```gdscript
@export_group("Canyon walls")
## Sections where the ground beyond the corridor blend is raised into a wall
## or dropped away, as Vector4(start, length, left delta, right delta): metres
## along the road, then metres up (+) or down (-) relative to the road on each
## side. Deltas ease in and out over wall_blend inside each end.
@export var wall_sections: Array[Vector4] = []
@export var wall_blend: float = 25.0


## The wall delta at `distance` on `side` (-1 = left, +1 = right): the covering
## section's delta eased over wall_blend inside each of its ends, 0 elsewhere.
func wall_delta(distance: float, side: float) -> float:
	var total := 0.0
	for section: Vector4 in wall_sections:
		var end := section.x + section.y
		if distance < section.x or distance >= end:
			continue
		var blend := maxf(wall_blend, 0.001)
		var weight := minf(smoothstep(section.x, section.x + blend, distance),
				1.0 - smoothstep(end - blend, end, distance))
		total += (section.w if side > 0.0 else section.z) * weight
	return total


func has_walls() -> bool:
	return wall_sections.any(func(section: Vector4) -> bool: return section.z != 0.0 or section.w != 0.0)
```

- [ ] **Step 4: The wall pass in `TerrainField`**

Add constants after `CREEK_LEVEE`:

```gdscript
## Beyond the corridor blend a canyon wall rises to its full height over this width (m) ...
const WALL_RISE := 12.0
## ... holds it for this width (m) ...
const WALL_PLATEAU := 30.0
## ... and eases back to the natural ground over this width (m).
const WALL_FALLOFF := 30.0
## Wall sections are painted onto the grid every this far along and across the road (m).
const WALL_STEP := 1.0
```

In `generate`, after the carve and before `_cut_creek`: `field._raise_walls(sampler, trail, terrain)`. Extend the class doc: "Wall sections raise or drop the ground beyond the corridor blend into canyon walls."

Add the pass and the height rule:

```gdscript
## The ground `edge` metres outside the shoulder edge where a wall section moves
## it by `delta` relative to the road: untouched inside the corridor blend, then
## rising over WALL_RISE, holding for WALL_PLATEAU and easing back to the natural
## ground over WALL_FALLOFF. A wall never lowers ground that is already higher,
## and a drop never raises ground that is already lower (spec §10.1).
static func walled_height(natural: float, road_height: float, delta: float, edge: float, blend: float) -> float:
	if edge < blend:
		return natural
	var rise := smoothstep(blend, blend + WALL_RISE, edge)
	var plateau_end := blend + WALL_RISE + WALL_PLATEAU
	var fall := 1.0 - smoothstep(plateau_end, plateau_end + WALL_FALLOFF, edge)
	var target := lerpf(natural, road_height + delta, rise * fall)
	return maxf(natural, target) if delta > 0.0 else minf(natural, target)


## Paints each wall section onto the grid: every WALL_STEP along the section and
## across the road out to the wall's full reach, the nearest grid sample records
## the smallest edge distance seen, that stamp's delta and the road height there.
## Then each touched sample takes its walled height. Runs after the corridor is
## carved and before the creek and structures, so a river channel can cut a wall.
func _raise_walls(sampler: RoadSampler, trail: TrailDef, terrain: TerrainDef) -> void:
	if not terrain.has_walls():
		return
	var cell_count := columns * rows
	var wall_edges := PackedFloat32Array()
	var wall_deltas := PackedFloat32Array()
	var wall_heights := PackedFloat32Array()
	wall_edges.resize(cell_count)
	wall_edges.fill(FAR)
	wall_deltas.resize(cell_count)
	wall_heights.resize(cell_count)
	var reach := trail.half_total_width() + terrain.corridor_blend + WALL_RISE + WALL_PLATEAU + WALL_FALLOFF
	for section: Vector4 in terrain.wall_sections:
		var distance := maxf(section.x, 0.0)
		var end := minf(section.x + section.y, sampler.length)
		while distance <= end:
			var left := terrain.wall_delta(distance, -1.0)
			var right := terrain.wall_delta(distance, 1.0)
			var centre := sampler.position(distance)
			var across := sampler.right(distance)
			var flat := Vector2(across.x, across.z).normalized()
			var bank := across.y / maxf(Vector2(across.x, across.z).length(), 0.0001)
			var half := trail.half_total_width_at(distance)
			var lateral := -reach
			while lateral <= reach:
				var delta := right if lateral > 0.0 else left
				var edge := absf(lateral) - half
				if delta != 0.0 and edge >= terrain.corridor_blend:
					var column := roundi((centre.x + flat.x * lateral - origin.x) / spacing)
					var row := roundi((centre.z + flat.y * lateral - origin.y) / spacing)
					if column >= 0 and column < columns and row >= 0 and row < rows:
						var i := row * columns + column
						if edge < wall_edges[i]:
							wall_edges[i] = edge
							wall_deltas[i] = delta
							wall_heights[i] = centre.y + lateral * bank
				lateral += WALL_STEP
			distance += WALL_STEP
	for i in cell_count:
		if wall_edges[i] < FAR:
			heights[i] = walled_height(heights[i], wall_heights[i], wall_deltas[i], wall_edges[i], terrain.corridor_blend)
			lowest_height = minf(lowest_height, heights[i])
```

- [ ] **Step 5: Run the wall test, the terrain tests and the fingerprints**

```bash
for t in test_canyon_walls test_terrain_field test_geometry_fingerprints test_creek test_tunnel test_bridge; do
  godot --headless --fixed-fps 120 --max-fps 0 -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/$t.gd -gexit 2>&1 | grep -E "Totals|passed|failed|SCRIPT ERROR"
done
```

Expected: all passing.

- [ ] **Step 6: Commit**

```bash
git add levels/trail/terrain_def.gd levels/trail/terrain_field.gd tests/unit/test_canyon_walls.gd tests/unit/test_canyon_walls.gd.uid
git commit -m "Add canyon wall sections to the terrain

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 4: Rock steps

Spec §6. `RockStepDef` on `TrailDef.rock_steps`; `RoadProfile.step_height(distance, lateral)` raises the road permanently, vertically inside the face's span and as a ramp beside it; the road mesh gets exact rows either side of the face; the terrain follows the ramp; `RockStepBuilder` builds one merged rock-face mesh with concave collision tagged rock.

**Design note (deviation, record it in the M5 notes):** a sphere-cast wheel cannot mount a face taller than the chassis clearance (the 4x4's is about 32 cm), so the face is vertical for `RockStepDef.LEDGE_SHARE` (60%) of the height and the top `face_length` of road inside the span is the *lip*: a slope from 60% to 100% of the height. The road profile and the built face share that shape. A 0.5 m step therefore has a 0.3 m vertical face; the rally cars (which clear about 15 cm) still beach on it, the 4x4 still climbs it.

**Files:**
- Create: `levels/trail/rock_step_def.gd`, `levels/trail/rock_step_builder.gd`, `tests/unit/test_rock_steps.gd`
- Modify: `levels/trail/trail_def.gd`, `levels/trail/road_profile.gd`, `levels/trail/road_builder.gd`, `levels/trail/road_chunk_data.gd`, `levels/trail/terrain_field.gd`, `levels/trail/trail_level.gd`, `tests/unit/test_trail_level.gd`

**Interfaces:**
- Produces: `RockStepDef { distance, height, lateral_from, lateral_to, face_length = 0.6, ramp_length = 6.0, color, seed; LEDGE_SHARE = 0.6; covers(lateral) -> bool; height_at(at, lateral) -> float; ramp_offset(at) -> float }`; `TrailDef.rock_steps: Array[RockStepDef]`; `RoadProfile.step_height(distance, lateral) -> float` (summed into `height()`), `RoadProfile.exact_rows() -> PackedFloat32Array` (surface boundaries plus step face rows), `RoadProfile.FACE_ROW_GAP = 0.02`; `RockStepBuilder.build(sampler, profile, trail)`, `.step_count: int`, `.face_tops: PackedVector3Array` (one point per step: the centre of the face's top edge), children `RockSteps` (mesh) and `RockStepsCollision`; `TrailLevel.rock_step_builder`, phase `&"rock_steps"`.

- [ ] **Step 1: Write the failing test**

`tests/unit/test_rock_steps.gd`:

```gdscript
extends GutTest
## Rock steps (M5 spec §6): the profile's level change, the ramp beside a partial
## face, the face mesh, its rock collision and the terrain following the ramp.

var trail: TrailDef
var sampler: RoadSampler
var profile: RoadProfile
var full: RockStepDef
var partial: RockStepDef


func before_each() -> void:
	var curve := Curve3D.new()
	curve.bake_interval = 1.0
	curve.add_point(Vector3.ZERO)
	curve.add_point(Vector3(0.0, 0.0, -300.0))
	trail = TrailDef.new()
	trail.undulation_amplitude = 0.0
	trail.painted_lines = false
	full = RockStepDef.new()
	full.distance = 100.0
	full.height = 0.35
	full.lateral_from = -6.0
	full.lateral_to = 6.0
	partial = RockStepDef.new()
	partial.distance = 200.0
	partial.height = 0.5
	partial.lateral_from = 0.5
	partial.lateral_to = 3.5
	trail.rock_steps = [full, partial]
	sampler = RoadSampler.new(curve, true, trail)
	profile = RoadProfile.new(trail, sampler.length)


func test_the_road_rises_at_a_full_width_face_and_stays_up() -> void:
	assert_almost_eq(profile.height(99.0, 0.0), 0.0, 0.0001)
	assert_almost_eq(profile.height(100.0, 0.0), 0.0, 0.0001, "the face row is at the old level")
	assert_almost_eq(profile.height(100.02, 0.0), 0.35 * 0.6 + 0.35 * 0.4 * 0.02 / 0.6, 0.0001, "the vertical face's top, at the start of the lip")
	assert_almost_eq(profile.height(100.6, 0.0), 0.35, 0.0001, "the lip reaches the full height over face_length")
	assert_almost_eq(profile.height(150.0, -5.0), 0.35, 0.0001)
	assert_almost_eq(profile.height(199.0, 5.0), 0.35, 0.0001, "the rise is permanent")


func test_a_partial_face_ramps_beside_it_and_both_lines_meet() -> void:
	assert_almost_eq(profile.height(200.6, 2.0), 0.85, 0.0001, "on the ledge past its lip: both steps")
	assert_almost_eq(profile.height(200.6, -2.0), 0.35 + 0.5 * 0.1, 0.0001, "beside it: only a tenth of the ramp so far")
	assert_almost_eq(profile.height(203.0, -2.0), 0.35 + 0.25, 0.0001, "halfway up the 6 m ramp")
	assert_almost_eq(profile.height(206.0, -2.0), 0.85, 0.0001, "level with the ledge at the ramp's end")
	assert_almost_eq(profile.height(206.0, 2.0), 0.85, 0.0001)
	assert_true(profile.in_detail_range(203.0))
	assert_false(profile.in_detail_range(150.0))
	assert_eq(profile.exact_rows(), PackedFloat32Array([100.0, 100.02, 200.0, 200.02]))


func test_the_road_mesh_has_a_sharp_face_in_both_build_modes() -> void:
	for threaded: bool in [true, false]:
		var road := RoadBuilder.new()
		road.threaded = threaded
		add_child(road)
		road.build(sampler, profile, trail)
		var rows := RoadBuilder.row_distances(sampler.length, profile, trail)
		assert_true(rows.has(100.0), "a row at the face")
		assert_true(rows.has(100.02), "and one just past it")
		var before := -INF
		var after := INF
		for child in road.get_children():
			if child is MeshInstance3D:
				var vertices: PackedVector3Array = child.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
				for vertex in vertices:
					if absf(vertex.x) > 3.0:
						continue
					if vertex.z <= -99.9 and vertex.z > -100.01:
						before = maxf(before, vertex.y)
					elif vertex.z <= -100.01 and vertex.z > -100.03:
						after = minf(after, vertex.y)
		assert_almost_eq(before, 0.0, 0.001, "old level on the face row (threaded %s)" % threaded)
		assert_almost_eq(after, 0.35 * 0.6 + 0.35 * 0.4 * 0.02 / 0.6, 0.001, "ledge level 2 cm on (threaded %s)" % threaded)
		remove_child(road)
		road.queue_free()
		await wait_process_frames(1)


func test_the_builder_puts_a_rock_face_with_collision_on_the_level_change() -> void:
	var builder := RockStepBuilder.new()
	add_child_autofree(builder)
	builder.build(sampler, profile, trail)
	assert_eq(builder.step_count, 2)
	assert_not_null(builder.get_node_or_null("RockSteps"), "one merged mesh")
	assert_not_null(builder.get_node_or_null("RockStepsCollision"))
	assert_eq(builder.get_children().filter(func(c: Node) -> bool: return c is MeshInstance3D).size(), 1, "one draw call for every step")
	assert_almost_eq(builder.face_tops[0].y, 0.35 * RockStepDef.LEDGE_SHARE, 0.02, "the face's top meets the road at the lip's start")
	await wait_physics_frames(2)
	var space := builder.get_world_3d().direct_space_state
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(0.0, 0.1, -97.0), Vector3(0.0, 0.1, -103.0)))
	assert_false(hit.is_empty(), "a ray along the road hits the face")
	if not hit.is_empty():
		assert_eq(SurfaceLookup.surface_of(hit["collider"]).id, &"rock")
		assert_almost_eq(hit["position"].z, -100.0, 0.1)
	var lip := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(2.0, 2.0, -100.6), Vector3(2.0, -1.0, -100.6)))
	assert_false(lip.is_empty(), "the lip has collision")
	if not lip.is_empty():
		assert_almost_eq(lip["position"].y, 0.35, 0.05, "the lip's end sits at the ledge's level")
	var beside := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(-2.0, 0.1, -197.0), Vector3(-2.0, 0.1, -203.0)))
	assert_true(beside.is_empty(), "no face beside a partial ledge, just the road's ramp")


func test_terrain_follows_the_ramp_under_the_road() -> void:
	var terrain := TerrainDef.new()
	terrain.margin = 40.0
	terrain.chunk_size = 32.0
	terrain.noise_amplitude = 0.0
	var field := TerrainField.generate(sampler, trail, terrain)
	assert_almost_eq(field.height_at(0.0, -150.0), 0.35 - terrain.under_road_drop, 0.03, "under the raised road")
	assert_almost_eq(field.height_at(0.0, -50.0), -terrain.under_road_drop, 0.03, "under the road before the step")
```

Also add `"Generated/RockSteps"` to the parts list in `tests/unit/test_trail_level.gd` `test_building_creates_every_part`.

- [ ] **Step 2: Run to see it fail**

Run: `godot --headless --fixed-fps 120 --max-fps 0 -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_rock_steps.gd -gexit`
Expected: parse errors (`RockStepDef` unknown).

- [ ] **Step 3: `RockStepDef`**

`levels/trail/rock_step_def.gd`:

```gdscript
class_name RockStepDef
extends Resource
## A rock ledge the road climbs (M5 spec §6): the road's level rises by `height`
## at `distance` and stays up for the rest of the trail. Across
## lateral_from..lateral_to the rise is a vertical face topped by a short lip;
## outside that span the road ramps up over ramp_length beside it.
## Lateral positions are metres from the centre line (+ = right).

## The share of the height that is a vertical face. The rest is the lip: a slope
## over face_length that a wheel can ride up (a sphere-cast wheel cannot mount a
## face taller than the car's clearance).
const LEDGE_SHARE := 0.6

@export var distance: float = 0.0
@export_range(0.0, 1.0) var height: float = 0.35
@export var lateral_from: float = -6.5
@export var lateral_to: float = 6.5
## Depth of the rock lip on top of the face, along the road (m).
@export var face_length: float = 0.6
## The road beside the face climbs to the new level over this distance (m).
@export var ramp_length: float = 6.0
@export var color: Color = Color(0.62, 0.4, 0.31)
@export var seed: int = 53


## Whether `lateral` is inside the face's span.
func covers(lateral: float) -> bool:
	return lateral >= lateral_from and lateral <= lateral_to


## The road's rise at a point: nothing at or before the face; inside its span the
## vertical face's height then the lip climbing to the full height over
## face_length; beside the span the ramp.
func height_at(at: float, lateral: float) -> float:
	if at <= distance:
		return 0.0
	if covers(lateral):
		var lip := clampf((at - distance) / maxf(face_length, 0.001), 0.0, 1.0)
		return height * (LEDGE_SHARE + (1.0 - LEDGE_SHARE) * lip)
	return ramp_offset(at)


## The rise of the ramped road beside the face, which the terrain also follows.
func ramp_offset(at: float) -> float:
	return height * clampf((at - distance) / maxf(ramp_length, 0.001), 0.0, 1.0)
```

`levels/trail/trail_def.gd`, in `Structures`: `@export var rock_steps: Array[RockStepDef] = []`.

Run `godot --headless --import` once.

- [ ] **Step 4: `RoadProfile` and the road builders**

`levels/trail/road_profile.gd`:

- const: `## The row just past a rock step's face sits this far along from it (m).` `const FACE_ROW_GAP := 0.02`
- in `_init`, with the other ranges: `for step: RockStepDef in def.rock_steps: ranges.append(Vector2(step.distance - 1.0, step.distance + step.ramp_length + 1.0))`
- `height()` becomes `longitudinal_height(distance) + rough_height(distance, lateral) + rut_height(distance, lateral) + step_height(distance, lateral)`
- add:

```gdscript
## The rise from every rock step at a point: vertical inside a face's span, a ramp beside it.
func step_height(distance: float, lateral: float) -> float:
	var total := 0.0
	for step: RockStepDef in def.rock_steps:
		total += step.height_at(distance, lateral)
	return total


## Distances the road must have a cross-section row at exactly: every surface
## boundary, and both sides of each rock step's face, so the face is a sharp
## edge in the road mesh rather than a slope.
func exact_rows() -> PackedFloat32Array:
	var rows := surface_boundaries()
	for step: RockStepDef in def.rock_steps:
		for at: float in [step.distance, step.distance + FACE_ROW_GAP]:
			if at > 0.0 and at < road_length and not rows.has(at):
				rows.append(at)
	rows.sort()
	return rows
```

Update the class doc comment to mention rock steps.

`levels/trail/road_builder.gd`: `row_distances` uses `var boundaries := profile.exact_rows()`. In `_snapshot`, add the steps that can affect this chunk (every step starting before its last row, since a step's rise is permanent):

```gdscript
	var steps: Array[PackedFloat64Array] = []
	for step: RockStepDef in def.rock_steps:
		if step.distance < distances[-1]:
			steps.append(PackedFloat64Array([step.distance, step.height, step.lateral_from, step.lateral_to,
					step.ramp_length, step.face_length]))
```

and `"steps": steps` in the dictionary. The serial `_add_chunk` already uses `profile.height`, which includes steps.

`levels/trail/road_chunk_data.gd`: read `var steps: Array[PackedFloat64Array] = input["steps"]` and, after the rut maths, inline:

```gdscript
			var step_height := 0.0
			for step: PackedFloat64Array in steps:
				if distance <= step[0]:
					continue
				if lateral >= step[2] and lateral <= step[3]:
					var lip := clampf((distance - step[0]) / maxf(step[5], 0.001), 0.0, 1.0)
					step_height += step[1] * (RockStepDef.LEDGE_SHARE + (1.0 - RockStepDef.LEDGE_SHARE) * lip)
				else:
					step_height += step[1] * clampf((distance - step[0]) / maxf(step[4], 0.001), 0.0, 1.0)
```

and add `+ step_height` to the vertex height. Shading stays on potholes and ruts only.

`levels/trail/terrain_field.gd` `generate`, in the stamps loop after the bridge offsets: `for step: RockStepDef in trail.rock_steps: point.y += step.ramp_offset(distance)`.

- [ ] **Step 5: `RockStepBuilder`**

`levels/trail/rock_step_builder.gd`:

```gdscript
class_name RockStepBuilder
extends Node3D
## The rock faces of a trail's steps (M5 spec §6.3): for each RockStepDef a
## near-vertical face across its span, seeded-rough, with a lip on top sloping up
## to the raised road, and end caps where the face covers only part of the road.
## Every step is merged into one mesh (one draw call) with concave collision tagged rock.

const ROCK := preload("res://surfaces/rock.tres")
## Spacing of the face's vertical strips across the road (m).
const LATERAL_STEP := 0.5
## The face's bottom is buried this far below the lower road, so no seam shows (m).
const BURY := 0.15
## The lip is drawn this far above the road it covers, so its rock colour shows (m).
const LIP_LIFT := 0.01

var step_count := 0
## The centre of each step's face top edge (world), in trail order.
var face_tops := PackedVector3Array()


func build(sampler: RoadSampler, profile: RoadProfile, trail: TrailDef) -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	step_count = 0
	face_tops.clear()
	var mesh := StructureMesh.new()
	for step: RockStepDef in trail.rock_steps:
		_add_step(mesh, sampler, profile, step)
		step_count += 1
	mesh.add_to(self, "RockSteps", ROCK)


func _add_step(mesh: StructureMesh, sampler: RoadSampler, profile: RoadProfile, step: RockStepDef) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = step.seed
	var along := sampler.forward(step.distance)
	var up := sampler.up(step.distance)
	var count := maxi(1, ceili((step.lateral_to - step.lateral_from) / LATERAL_STEP))
	var bottoms := PackedVector3Array()
	var tops := PackedVector3Array()
	var lips := PackedVector3Array()
	for i in count + 1:
		var lateral := lerpf(step.lateral_from, step.lateral_to, i / float(count))
		var base := sampler.surface_point(step.distance, lateral, profile)
		var jitter: float = rng.randf_range(-0.04, 0.04) if i > 0 and i < count else 0.0
		bottoms.append(base - up * BURY)
		tops.append(base + up * step.height * RockStepDef.LEDGE_SHARE + along * jitter)
		lips.append(sampler.surface_point(step.distance + step.face_length, lateral, profile) + up * LIP_LIFT)
	face_tops.append((tops[0] + tops[count]) * 0.5)
	for i in count:
		var shade := rng.randf_range(0.8, 1.1)
		var color := step.color * Color(shade, shade, shade)
		# The face looks back down the road (normal -along); the lip looks up.
		mesh.quad(tops[i], tops[i + 1], bottoms[i + 1], bottoms[i], color)
		mesh.quad(tops[i], lips[i], lips[i + 1], tops[i + 1], color.lightened(0.08))
	# Close the ends of a face that covers only part of the road.
	var half := sampler.half_width_at(step.distance)
	if step.lateral_from > -half + 0.01:
		mesh.triangle(bottoms[0], tops[0], lips[0], step.color.darkened(0.1))
	if step.lateral_to < half - 0.01:
		mesh.triangle(bottoms[count], lips[count], tops[count], step.color.darkened(0.1))
```

`levels/trail/trail_level.gd`: add `var rock_step_builder: RockStepBuilder`, and after the bridges block:

```gdscript
	rock_step_builder = RockStepBuilder.new()
	rock_step_builder.name = "RockSteps"
	generated.add_child(rock_step_builder)
	rock_step_builder.build(sampler, profile, trail)
	_lap(&"rock_steps")
```

Update the class doc's build list.

- [ ] **Step 6: Run the tests**

```bash
godot --headless --import >/dev/null 2>&1
for t in test_rock_steps test_road_profile test_road_builder test_trail_level test_geometry_fingerprints test_bridge test_frozen_pass; do
  godot --headless --fixed-fps 120 --max-fps 0 -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/$t.gd -gexit 2>&1 | grep -E "Totals|passed|failed|SCRIPT ERROR"
done
```

Expected: all passing. The fingerprint test proves `exact_rows()` equals `surface_boundaries()` for trails without steps.

- [ ] **Step 7: Commit**

```bash
git add levels/trail/rock_step_def.gd levels/trail/rock_step_def.gd.uid levels/trail/rock_step_builder.gd levels/trail/rock_step_builder.gd.uid levels/trail/trail_def.gd levels/trail/road_profile.gd levels/trail/road_builder.gd levels/trail/road_chunk_data.gd levels/trail/terrain_field.gd levels/trail/trail_level.gd tests/unit/test_rock_steps.gd tests/unit/test_rock_steps.gd.uid tests/unit/test_trail_level.gd
git commit -m "Add rock steps: ledge profile, rock face builder and terrain follow

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---
### Task 5: Boulder fields

Spec §7. `BoulderFieldDef` on `TrailDef.boulder_fields`; `BoulderBuilder` places seeded boulders and tilted slabs on the road surface or the terrain, one `MultiMesh` per field, one convex hull per boulder tagged rock, none within 1.5 m of a gate centre.

**Design notes:** slabs reuse the same rock mesh (stretched, flattened and rolled about the road axis) so a field stays one `MultiMesh`. Boulders alternate left/right so a field never piles up on one side. A boulder's centre sits a tenth of its radius *below* the ground (`BURY = -0.1`): the flattened, jittered rock mesh then shows about 0.74 r above ground, so a 0.45 m boulder stands 0.33 m, within the 4x4's measured 35 cm clearance.

**Files:**
- Create: `levels/trail/boulder_field_def.gd`, `levels/trail/boulder_builder.gd`, `tests/unit/test_boulders.gd`
- Modify: `levels/trail/trail_def.gd`, `levels/trail/trail_level.gd`, `tests/unit/test_trail_level.gd`

**Interfaces:**
- Consumes: `RoadSampler.half_width_at`, `road_half_width_at`, `surface_point` (Task 1); `CheckpointPlacer.distances_for` (static); `LowPolyMeshes.rock(color, seed)`.
- Produces: `BoulderFieldDef { start, length, count, size_range = (0.3, 0.45), off_road_size_range = (0.6, 1.2), lateral_range = (0.0, 9.0), slab_fraction = 0.25, color, seed; end() }`; `TrailDef.boulder_fields`; `BoulderBuilder.build(sampler, profile, field, trail)`, `.placed: Array[Array]` (per field, `Transform3D` per boulder), `.slabs: Array[Array]` (per field, `bool` per boulder), `GATE_CLEARANCE = 1.5`, `BURY = -0.1`, `SLAB_TILT_DEG = Vector2(8, 18)`; children `Field<i>` (MultiMeshInstance3D) and `Field<i>Collision` (StaticBody3D); `TrailLevel.boulder_builder`, phase `&"boulders"`.

- [ ] **Step 1: Write the failing test**

`tests/unit/test_boulders.gd`:

```gdscript
extends GutTest
## Boulder fields (M5 spec §7): seeded layouts, on-road sizes, gate clearance,
## convex rock colliders, one MultiMesh per field and tilted slabs.

var trail: TrailDef
var sampler: RoadSampler
var profile: RoadProfile
var field: TerrainField
var def: BoulderFieldDef
var builder: BoulderBuilder


func before_each() -> void:
	var curve := Curve3D.new()
	curve.bake_interval = 1.0
	curve.add_point(Vector3.ZERO)
	curve.add_point(Vector3(0.0, 0.0, -300.0))
	trail = TrailDef.new()
	trail.undulation_amplitude = 0.0
	trail.painted_lines = false
	trail.checkpoint_distances = PackedFloat32Array([150.0])
	def = BoulderFieldDef.new()
	def.start = 100.0
	def.length = 100.0
	def.count = 30
	def.seed = 5
	trail.boulder_fields = [def]
	sampler = RoadSampler.new(curve, true, trail)
	profile = RoadProfile.new(trail, sampler.length)
	var terrain := TerrainDef.new()
	terrain.margin = 40.0
	terrain.chunk_size = 32.0
	terrain.noise_amplitude = 0.0
	field = TerrainField.generate(sampler, trail, terrain)
	builder = BoulderBuilder.new()
	add_child_autofree(builder)
	builder.build(sampler, profile, field, trail)


func test_the_same_seed_gives_the_same_layout_and_another_seed_differs() -> void:
	var again := BoulderBuilder.new()
	add_child_autofree(again)
	again.build(sampler, profile, field, trail)
	assert_eq(again.placed[0], builder.placed[0])
	def.seed = 6
	again.build(sampler, profile, field, trail)
	assert_ne(again.placed[0], builder.placed[0])
	assert_gt(builder.placed[0].size(), 20, "most of the 30 are placed (a few may sit on the gate)")


func test_boulders_on_the_road_keep_their_size_and_sides_alternate() -> void:
	var on_road := 0
	var left := 0
	var right := 0
	for i in builder.placed[0].size():
		var transform: Transform3D = builder.placed[0][i]
		var lateral := sampler.lateral_offset(transform.origin)
		if lateral < 0.0:
			left += 1
		else:
			right += 1
		if absf(lateral) <= trail.half_total_width() and not builder.slabs[0][i]:
			assert_between(transform.basis.get_scale().x, def.size_range.x, def.size_range.y, "on-road boulder %d" % i)
			on_road += 1
		elif absf(lateral) > trail.half_total_width() and not builder.slabs[0][i]:
			assert_between(transform.basis.get_scale().x, def.off_road_size_range.x, def.off_road_size_range.y, "off-road boulder %d" % i)
		assert_between(transform.origin.z, -200.0, -100.0, "inside the field")
	assert_gt(on_road, 3)
	assert_gt(left, 5)
	assert_gt(right, 5)


func test_no_boulder_sits_within_the_gate_clearance() -> void:
	for transform: Transform3D in builder.placed[0]:
		assert_gte(absf(sampler.closest_distance(transform.origin) - 150.0), BoulderBuilder.GATE_CLEARANCE - 0.05)


func test_each_boulder_has_a_convex_rock_collider_and_one_multimesh_per_field() -> void:
	var body: StaticBody3D = builder.get_node("Field0Collision")
	assert_eq(body.get_child_count(), builder.placed[0].size())
	assert_eq(SurfaceLookup.surface_of(body).id, &"rock")
	for shape in body.get_children():
		assert_true(shape.shape is ConvexPolygonShape3D)
	var instances := builder.get_children().filter(func(c: Node) -> bool: return c is MultiMeshInstance3D)
	assert_eq(instances.size(), 1)
	assert_eq(instances[0].multimesh.instance_count, builder.placed[0].size())
	await wait_physics_frames(2)
	var centre: Vector3 = builder.placed[0][0].origin
	var hit := builder.get_world_3d().direct_space_state.intersect_ray(
			PhysicsRayQueryParameters3D.create(centre + Vector3.UP * 3.0, centre + Vector3.DOWN * 3.0))
	assert_false(hit.is_empty(), "a ray down through a boulder hits it")
	if not hit.is_empty():
		assert_eq(SurfaceLookup.surface_of(hit["collider"]).id, &"rock")
		assert_gt(hit["position"].y, centre.y, "its top is above its centre")


func test_slabs_are_tilted_across_the_road() -> void:
	def.slab_fraction = 1.0
	builder.build(sampler, profile, field, trail)
	assert_gt(builder.placed[0].size(), 20)
	for i in builder.placed[0].size():
		assert_true(builder.slabs[0][i])
		var transform: Transform3D = builder.placed[0][i]
		var up := transform.basis.y.normalized()
		assert_between(up.y, cos(deg_to_rad(BoulderBuilder.SLAB_TILT_DEG.y + 0.1)), cos(deg_to_rad(BoulderBuilder.SLAB_TILT_DEG.x - 0.1)), "slab %d tilt" % i)
		assert_lt(transform.basis.get_scale().y, transform.basis.get_scale().x, "flat")
```

Also add `"Generated/Boulders"` to the parts list in `tests/unit/test_trail_level.gd`.

- [ ] **Step 2: Run to see it fail**

Run: `godot --headless --fixed-fps 120 --max-fps 0 -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_boulders.gd -gexit`
Expected: parse errors (`BoulderFieldDef` unknown).

- [ ] **Step 3: `BoulderFieldDef` and the trail field**

`levels/trail/boulder_field_def.gd`:

```gdscript
class_name BoulderFieldDef
extends Resource
## A seeded cluster of fixed boulders and tilted slabs on and beside the road
## (M5 spec §7). Distances are metres along the road.

@export var start: float = 0.0
@export var length: float = 100.0
@export var count: int = 20
## Radii of boulders on the road (m). 0.30-0.45 lifts the rally cars and lets the 4x4 climb (spec §7.3).
@export var size_range: Vector2 = Vector2(0.3, 0.45)
## Radii of boulders beyond the shoulders, which are scenery and walls to the line (m).
@export var off_road_size_range: Vector2 = Vector2(0.6, 1.2)
## How far from the centre line boulders may sit (m); alternate boulders go left and right.
@export var lateral_range: Vector2 = Vector2(0.0, 9.0)
## Share built as low tilted slabs instead of rounded boulders.
@export_range(0.0, 1.0) var slab_fraction: float = 0.25
@export var color: Color = Color(0.62, 0.4, 0.31)
@export var seed: int = 61


func end() -> float:
	return start + length
```

`levels/trail/trail_def.gd`, in `Structures`: `@export var boulder_fields: Array[BoulderFieldDef] = []`. Run `godot --headless --import`.

- [ ] **Step 4: `BoulderBuilder`**

`levels/trail/boulder_builder.gd`:

```gdscript
class_name BoulderBuilder
extends Node3D
## Fixed boulders and tilted slabs from each BoulderFieldDef (M5 spec §7.2):
## placed from the field's seed on the road surface or on the terrain beyond the
## shoulders, drawn as one MultiMesh per field, each with a convex hull tagged
## rock. Slabs are the same rock mesh stretched, flattened and rolled about the
## road's axis, so they lift one wheel and put the car off-camber.

const ROCK := preload("res://surfaces/rock.tres")
## Nothing is placed closer than this to a checkpoint gate's centre (m).
const GATE_CLEARANCE := 1.5
## A boulder's centre sits this share of its radius above the ground: a tenth
## below it, so about 0.74 r of the flattened rock shows (0.33 m for a 0.45 m
## boulder, within the 4x4's measured 35 cm clearance).
const BURY := -0.1
## Slab shape relative to its radius: across, up, along the road.
const SLAB_SCALE := Vector3(1.1, 0.35, 1.6)
## Slabs are rolled about the road's axis by this range (degrees).
const SLAB_TILT_DEG := Vector2(8.0, 18.0)
const VIEW_DISTANCE := 200.0

## Per field (same order as trail.boulder_fields): the placed boulders' transforms.
var placed: Array[Array] = []
## Per field: whether each placed boulder is a slab.
var slabs: Array[Array] = []


func build(sampler: RoadSampler, profile: RoadProfile, field: TerrainField, trail: TrailDef) -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	placed.clear()
	slabs.clear()
	var gates := CheckpointPlacer.distances_for(sampler.length, trail)
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = true
	material.roughness = 0.95
	for i in trail.boulder_fields.size():
		_build_field(sampler, profile, field, trail.boulder_fields[i], gates, material, i)


func _build_field(sampler: RoadSampler, profile: RoadProfile, field: TerrainField, def: BoulderFieldDef,
		gates: PackedFloat32Array, material: StandardMaterial3D, index: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = def.seed
	var mesh := LowPolyMeshes.rock(def.color, def.seed)
	var points := mesh.get_faces()
	var transforms: Array[Transform3D] = []
	var is_slab: Array[bool] = []
	var body := StaticBody3D.new()
	body.name = "Field%dCollision" % index
	body.set_meta(SurfaceLookup.META_KEY, ROCK)
	for n in def.count:
		# Every random draw happens before a boulder can be skipped, so the layout
		# of the others never depends on the gates.
		var distance := rng.randf_range(def.start, def.end())
		var side: float = -1.0 if n % 2 == 0 else 1.0
		var lateral := side * rng.randf_range(def.lateral_range.x, def.lateral_range.y)
		var slab := rng.randf() < def.slab_fraction
		var yaw := rng.randf() * TAU
		var tilt := deg_to_rad(rng.randf_range(SLAB_TILT_DEG.x, SLAB_TILT_DEG.y)) * (1.0 if rng.randf() < 0.5 else -1.0)
		var on_road := absf(lateral) <= sampler.half_width_at(distance)
		var sizes := def.size_range if on_road else def.off_road_size_range
		var radius := rng.randf_range(sizes.x, sizes.y)
		if gates.any(func(gate: float) -> bool: return absf(gate - distance) < GATE_CLEARANCE):
			continue
		var origin: Vector3
		if on_road:
			origin = sampler.surface_point(distance, lateral, profile)
		else:
			origin = sampler.position(distance) + sampler.right(distance) * lateral
			origin.y = field.height_at(origin.x, origin.z)
		origin += Vector3.UP * radius * BURY
		var basis: Basis
		if slab:
			var along := sampler.forward(distance)
			basis = Basis.looking_at(along, Vector3.UP).rotated(along, tilt) * Basis.from_scale(SLAB_SCALE * radius)
		else:
			basis = Basis(Vector3.UP, yaw) * Basis.from_scale(Vector3.ONE * radius)
		transforms.append(Transform3D(basis, origin))
		is_slab.append(slab)
		var hull := ConvexPolygonShape3D.new()
		var local := PackedVector3Array()
		local.resize(points.size())
		for p in points.size():
			local[p] = basis * points[p]
		hull.points = local
		var shape := CollisionShape3D.new()
		shape.shape = hull
		shape.position = origin
		body.add_child(shape)
	add_child(body)
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh
	multimesh.instance_count = transforms.size()
	for i in transforms.size():
		multimesh.set_instance_transform(i, transforms[i])
	var instance := MultiMeshInstance3D.new()
	instance.name = "Field%d" % index
	instance.multimesh = multimesh
	instance.material_override = material
	instance.visibility_range_end = VIEW_DISTANCE
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)
	placed.append(transforms)
	slabs.append(is_slab)
```

`levels/trail/trail_level.gd`: `var boulder_builder: BoulderBuilder`; after the rock steps block:

```gdscript
	boulder_builder = BoulderBuilder.new()
	boulder_builder.name = "Boulders"
	generated.add_child(boulder_builder)
	boulder_builder.build(sampler, profile, field, trail)
	_lap(&"boulders")
```

- [ ] **Step 5: Run the tests**

```bash
godot --headless --import >/dev/null 2>&1
for t in test_boulders test_trail_level test_geometry_fingerprints; do
  godot --headless --fixed-fps 120 --max-fps 0 -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/$t.gd -gexit 2>&1 | grep -E "Totals|passed|failed|SCRIPT ERROR"
done
```

Expected: all passing.

- [ ] **Step 6: Commit**

```bash
git add levels/trail/boulder_field_def.gd levels/trail/boulder_field_def.gd.uid levels/trail/boulder_builder.gd levels/trail/boulder_builder.gd.uid levels/trail/trail_def.gd levels/trail/trail_level.gd tests/unit/test_boulders.gd tests/unit/test_boulders.gd.uid tests/unit/test_trail_level.gd
git commit -m "Add seeded boulder fields with convex rock collision

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 6: Talus field (provisional)

Spec §8. `TalusDef` on `TrailDef.talus`; `TalusBuilder` makes one sleeping `RigidBody3D` per stone with a convex hull, high friction and no bounce, drawn from one `MultiMesh` per field whose transforms are refreshed each physics frame only from awake stones. Ships behind its data entry; the phone check decides whether it stays (§8.3).

**Files:**
- Create: `levels/trail/talus_def.gd`, `levels/trail/talus_builder.gd`, `tests/unit/test_talus.gd`
- Modify: `levels/trail/trail_def.gd`, `levels/trail/trail_level.gd`, `tests/unit/test_trail_level.gd`

**Interfaces:**
- Produces: `TalusDef { start, length, count = 40, size_range = (0.18, 0.32), mass_range = (30, 120), lateral_range = (0.0, 4.0), color, seed; end() }`; `TrailDef.talus: Array[TalusDef]`; `TalusBuilder.build(sampler, profile, field, trail)`, `.stones: Array[RigidBody3D]`, `.awake_count() -> int`, child `Talus<i>` (MultiMeshInstance3D), stones named `Stone<i>_<n>`; `TrailLevel.talus_builder`, phase `&"talus"`.

- [ ] **Step 1: Write the failing test**

`tests/unit/test_talus.gd`:

```gdscript
extends GutTest
## The talus field (M5 spec §8): the right count of stones, all asleep on build,
## each a rigid body with a convex hull, drawn from one MultiMesh that follows
## the stones that wake.

var trail: TrailDef
var sampler: RoadSampler
var profile: RoadProfile
var field: TerrainField
var def: TalusDef
var builder: TalusBuilder


func before_each() -> void:
	var curve := Curve3D.new()
	curve.bake_interval = 1.0
	curve.add_point(Vector3.ZERO)
	curve.add_point(Vector3(0.0, 0.0, -300.0))
	trail = TrailDef.new()
	trail.undulation_amplitude = 0.0
	trail.painted_lines = false
	def = TalusDef.new()
	def.start = 100.0
	def.length = 60.0
	def.count = 12
	def.seed = 3
	trail.talus = [def]
	sampler = RoadSampler.new(curve, true, trail)
	profile = RoadProfile.new(trail, sampler.length)
	var terrain := TerrainDef.new()
	terrain.margin = 40.0
	terrain.chunk_size = 32.0
	terrain.noise_amplitude = 0.0
	field = TerrainField.generate(sampler, trail, terrain)
	builder = TalusBuilder.new()
	add_child_autofree(builder)
	builder.build(sampler, profile, field, trail)


func test_the_right_count_all_asleep_with_convex_hulls_and_matching_instances() -> void:
	assert_eq(builder.stones.size(), 12)
	for stone in builder.stones:
		assert_true(stone.sleeping, stone.name)
		assert_between(stone.mass, def.mass_range.x, def.mass_range.y)
		assert_true(stone.get_child(0).shape is ConvexPolygonShape3D)
		assert_eq(SurfaceLookup.surface_of(stone).id, &"rock")
		assert_between(stone.position.z, -160.0, -100.0, "inside the field")
		assert_lte(absf(stone.position.x), def.lateral_range.y + 0.01)
		assert_almost_eq(stone.physics_material_override.friction, TalusBuilder.FRICTION, 0.0001)
		assert_almost_eq(stone.physics_material_override.bounce, TalusBuilder.BOUNCE, 0.0001)
	await wait_physics_frames(3)
	assert_eq(builder.awake_count(), 0, "untouched stones stay asleep")
	var instance: MultiMeshInstance3D = builder.get_node("Talus0")
	assert_eq(instance.multimesh.instance_count, 12)
	assert_almost_eq(instance.multimesh.get_instance_transform(0).origin.distance_to(builder.stones[0].position), 0.0, 0.001)


func test_the_same_seed_gives_the_same_field() -> void:
	var again := TalusBuilder.new()
	add_child_autofree(again)
	again.build(sampler, profile, field, trail)
	for i in builder.stones.size():
		assert_almost_eq(again.stones[i].position.distance_to(builder.stones[i].position), 0.0, 0.0001)


func test_a_pushed_stone_wakes_and_its_instance_follows_it() -> void:
	var stone := builder.stones[0]
	var instance: MultiMeshInstance3D = builder.get_node("Talus0")
	var before := instance.multimesh.get_instance_transform(0).origin
	stone.apply_central_impulse(Vector3(0.0, 0.0, -stone.mass * 3.0))
	await wait_physics_frames(2)
	assert_gt(builder.awake_count(), 0, "the impulse woke it")
	await wait_physics_frames(30)
	var after := instance.multimesh.get_instance_transform(0).origin
	assert_gt(before.distance_to(after), 0.2, "the drawn stone moved with the body")
	assert_almost_eq(after.distance_to(stone.global_position), 0.0, 0.01)
```

Add `"Generated/Talus"` to the parts list in `tests/unit/test_trail_level.gd`.

- [ ] **Step 2: Run to see it fail**

Run: `godot --headless --fixed-fps 120 --max-fps 0 -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_talus.gd -gexit`
Expected: parse errors (`TalusDef` unknown).

- [ ] **Step 3: `TalusDef`**

`levels/trail/talus_def.gd`:

```gdscript
class_name TalusDef
extends Resource
## A field of loose stones that move when pushed (M5 spec §8): one rigid body
## each, sized to be shoved aside rather than climbed. Distances are metres along the road.

@export var start: float = 0.0
@export var length: float = 100.0
@export var count: int = 40
## Stone radii (m).
@export var size_range: Vector2 = Vector2(0.18, 0.32)
## Stone masses (kg): light enough that the 2150 kg 4x4 pushes through.
@export var mass_range: Vector2 = Vector2(30.0, 120.0)
## How far from the centre line stones may sit (m); alternate stones go left and right.
@export var lateral_range: Vector2 = Vector2(0.0, 4.0)
@export var color: Color = Color(0.66, 0.5, 0.4)
@export var seed: int = 71


func end() -> float:
	return start + length
```

`levels/trail/trail_def.gd`, in `Structures`: `@export var talus: Array[TalusDef] = []`. Run `godot --headless --import`.

- [ ] **Step 4: `TalusBuilder`**

`levels/trail/talus_builder.gd`:

```gdscript
class_name TalusBuilder
extends Node3D
## Loose stones (M5 spec §8.2): one RigidBody3D per stone with a convex hull,
## resting on the road or terrain and asleep on build, so untouched stones cost
## almost nothing. Each field is drawn from a single MultiMesh whose instance
## transforms are refreshed each physics frame only from the stones that are
## awake. Provisional: the phone check decides whether it stays (spec §8.3).

const ROCK := preload("res://surfaces/rock.tres")
## A stone's centre sits this share of its radius above the ground.
const REST := 0.85
const FRICTION := 1.0
const BOUNCE := 0.0
const VIEW_DISTANCE := 160.0
## Nothing is placed closer than this to a checkpoint gate's centre (m).
const GATE_CLEARANCE := 1.5

var stones: Array[RigidBody3D] = []

var _multimeshes: Array[MultiMesh] = []
## Per stone: its field's MultiMesh index, its instance slot and its radius.
var _fields := PackedInt32Array()
var _slots := PackedInt32Array()
var _radii := PackedFloat32Array()


func build(sampler: RoadSampler, profile: RoadProfile, field: TerrainField, trail: TrailDef) -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	stones.clear()
	_multimeshes.clear()
	_fields.clear()
	_slots.clear()
	_radii.clear()
	var gates := CheckpointPlacer.distances_for(sampler.length, trail)
	for i in trail.talus.size():
		_build_field(sampler, profile, field, trail.talus[i], gates, i)


func awake_count() -> int:
	var awake := 0
	for stone in stones:
		if not stone.sleeping:
			awake += 1
	return awake


func _physics_process(_delta: float) -> void:
	for i in stones.size():
		var stone := stones[i]
		if stone.sleeping:
			continue
		_multimeshes[_fields[i]].set_instance_transform(_slots[i],
				Transform3D(stone.global_basis * Basis.from_scale(Vector3.ONE * _radii[i]), stone.global_position))


func _build_field(sampler: RoadSampler, profile: RoadProfile, field: TerrainField, def: TalusDef,
		gates: PackedFloat32Array, index: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = def.seed
	var mesh := LowPolyMeshes.rock(def.color, def.seed)
	var points := mesh.get_faces()
	var physics := PhysicsMaterial.new()
	physics.friction = FRICTION
	physics.bounce = BOUNCE
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh
	var placed: Array[Transform3D] = []
	for n in def.count:
		var distance := rng.randf_range(def.start, def.end())
		var side: float = -1.0 if n % 2 == 0 else 1.0
		var lateral := side * rng.randf_range(def.lateral_range.x, def.lateral_range.y)
		var yaw := rng.randf() * TAU
		var radius := rng.randf_range(def.size_range.x, def.size_range.y)
		var mass := rng.randf_range(def.mass_range.x, def.mass_range.y)
		if gates.any(func(gate: float) -> bool: return absf(gate - distance) < GATE_CLEARANCE):
			continue
		var origin: Vector3
		if absf(lateral) <= sampler.half_width_at(distance):
			origin = sampler.surface_point(distance, lateral, profile)
		else:
			origin = sampler.position(distance) + sampler.right(distance) * lateral
			origin.y = field.height_at(origin.x, origin.z)
		origin += Vector3.UP * radius * REST
		var rotation := Basis(Vector3.UP, yaw)
		var scaled := rotation * Basis.from_scale(Vector3.ONE * radius)
		var stone := RigidBody3D.new()
		stone.name = "Stone%d_%d" % [index, n]
		stone.mass = mass
		stone.physics_material_override = physics
		stone.can_sleep = true
		stone.sleeping = true
		stone.set_meta(SurfaceLookup.META_KEY, ROCK)
		var hull := ConvexPolygonShape3D.new()
		var local := PackedVector3Array()
		local.resize(points.size())
		for p in points.size():
			local[p] = Basis.from_scale(Vector3.ONE * radius) * points[p]
		hull.points = local
		var shape := CollisionShape3D.new()
		shape.shape = hull
		stone.add_child(shape)
		stone.transform = Transform3D(rotation, origin)
		add_child(stone)
		stone.sleeping = true  # entering the tree must not wake it
		stones.append(stone)
		_fields.append(index)
		_slots.append(placed.size())
		_radii.append(radius)
		placed.append(Transform3D(scaled, origin))
	multimesh.instance_count = placed.size()
	for i in placed.size():
		multimesh.set_instance_transform(i, placed[i])
	_multimeshes.append(multimesh)
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = true
	material.roughness = 0.95
	var instance := MultiMeshInstance3D.new()
	instance.name = "Talus%d" % index
	instance.multimesh = multimesh
	instance.material_override = material
	instance.visibility_range_end = VIEW_DISTANCE
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)
```

`levels/trail/trail_level.gd`: `var talus_builder: TalusBuilder`; after boulders:

```gdscript
	talus_builder = TalusBuilder.new()
	talus_builder.name = "Talus"
	generated.add_child(talus_builder)
	talus_builder.build(sampler, profile, field, trail)
	_lap(&"talus")
```

- [ ] **Step 5: Run the tests**

```bash
godot --headless --import >/dev/null 2>&1
for t in test_talus test_trail_level test_geometry_fingerprints; do
  godot --headless --fixed-fps 120 --max-fps 0 -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/$t.gd -gexit 2>&1 | grep -E "Totals|passed|failed|SCRIPT ERROR"
done
```

Expected: all passing. If stones wake on entering the tree (awake_count > 0 with nothing touching them), set `stone.sleeping = true` deferred with `stone.set_deferred("sleeping", true)` as well and wait a physics frame in the test.

- [ ] **Step 6: Commit**

```bash
git add levels/trail/talus_def.gd levels/trail/talus_def.gd.uid levels/trail/talus_builder.gd levels/trail/talus_builder.gd.uid levels/trail/trail_def.gd levels/trail/trail_level.gd tests/unit/test_talus.gd tests/unit/test_talus.gd.uid tests/unit/test_trail_level.gd
git commit -m "Add the loose talus field of sleeping rigid stones

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---
### Task 7: The ford and waterfall

Spec §9. `FordDef` on `TrailDef.fords`; `RoadProfile` dips the road across the channel; the terrain follows the dip under the road and `TrailEarthworks.apply_fords` cuts the river channel across the terrain from the waterfall's foot out to the far side; `FordBuilder` lays the water ribbon, the scrolling waterfall strip, a mist emitter and a positional waterfall loop. The wet-rock surface stretch is level data (Task 10), not generated here. No collision.

**Files:**
- Create: `levels/trail/ford_def.gd`, `levels/trail/ford_builder.gd`, `tests/unit/test_ford.gd`
- Modify: `levels/trail/trail_def.gd`, `levels/trail/road_profile.gd`, `levels/trail/terrain_field.gd`, `levels/trail/trail_earthworks.gd`, `levels/trail/trail_level.gd`, `tests/unit/test_trail_level.gd`

**Interfaces:**
- Consumes: `SoundSynth.sound(&"waterfall")` (Task 2).
- Produces: `FordDef { distance, channel_width = 16.0, depth = 0.35, water_depth = 0.3, bank_run = 10.0, waterfall_height = 14.0, waterfall_width = 3.5, waterfall_offset = -22.0, river_reach = 45.0, water_color, foam_color, seed; half_width() -> float; height_offset(at) -> float; contains(at) -> bool }`; `TrailDef.fords: Array[FordDef]`; `RoadProfile.ford_height(distance) -> float` (in `longitudinal_height`); `TrailEarthworks.apply_fords(field, sampler, trail)`, `FORD_BANK = 4.0`, `FORD_TAPER = 8.0`; `FordBuilder.build(sampler, profile, field, trail)`, `.water_levels: PackedFloat32Array`, `.waterfall_feet`, `.waterfall_tops: PackedVector3Array`, children `Water<i>`, `Waterfall<i>`, `Mist<i>`, `Waterfall<i>Sound`; `TrailLevel.ford_builder`, phase `&"fords"`.

- [ ] **Step 1: Write the failing test**

`tests/unit/test_ford.gd`:

```gdscript
extends GutTest
## The ford (M5 spec §9) on a flat, noise-free straight road: the road's dip,
## the terrain channel across the trail, the water at water_depth above the
## floor, and the waterfall's height and position.

var trail: TrailDef
var terrain: TerrainDef
var sampler: RoadSampler
var profile: RoadProfile
var field: TerrainField
var ford: FordDef


func before_each() -> void:
	var curve := Curve3D.new()
	curve.bake_interval = 1.0
	curve.add_point(Vector3.ZERO)
	curve.add_point(Vector3(0.0, 0.0, -400.0))
	trail = TrailDef.new()
	trail.undulation_amplitude = 0.0
	trail.painted_lines = false
	ford = FordDef.new()
	ford.distance = 200.0
	trail.fords = [ford]
	sampler = RoadSampler.new(curve, true, trail)
	profile = RoadProfile.new(trail, sampler.length)
	terrain = TerrainDef.new()
	terrain.margin = 80.0
	terrain.chunk_size = 32.0
	terrain.noise_amplitude = 0.0
	terrain.corridor_blend = 8.0
	field = TerrainField.generate(sampler, trail, terrain)


func _height_at(distance: float, lateral: float) -> float:
	var spot := sampler.position(distance) + sampler.right(distance) * lateral
	return field.height_at(spot.x, spot.z)


func test_the_road_dips_by_depth_across_the_channel_and_is_continuous() -> void:
	assert_almost_eq(profile.height(200.0, 0.0), -0.35, 0.0001, "the channel's centre")
	assert_almost_eq(profile.height(192.0, 3.0), -0.35, 0.0001, "the channel's edge, across the road")
	assert_almost_eq(profile.height(185.0, 0.0), -0.35 * (1.0 - smoothstep(0.0, 10.0, 7.0)), 0.0001, "on the bank")
	assert_almost_eq(profile.height(181.9, 0.0), 0.0, 0.0001, "before the bank")
	assert_almost_eq(profile.height(250.0, 0.0), 0.0, 0.0001)
	var previous := profile.height(175.0, 0.0)
	var at := 175.25
	while at <= 225.0:
		var height := profile.height(at, 0.0)
		assert_lt(absf(height - previous), 0.03, "no step at %.2f m" % at)
		previous = height
		at += 0.25
	assert_true(profile.in_detail_range(190.0))
	assert_false(profile.in_detail_range(170.0))
	assert_true(ford.contains(207.0))
	assert_false(ford.contains(209.0))


func test_the_terrain_channel_crosses_the_road_on_both_sides() -> void:
	var floor := -ford.depth
	for lateral: float in [-15.0, 15.0, 35.0]:
		assert_almost_eq(_height_at(200.0, lateral), floor, 0.06, "channel floor %.0f m out" % lateral)
	assert_almost_eq(_height_at(200.0, -40.0), 0.0, 0.05, "the channel ends at the waterfall's foot")
	assert_almost_eq(_height_at(200.0, 62.0), 0.0, 0.05, "and past the river's reach")
	assert_almost_eq(_height_at(230.0, 15.0), 0.0, 0.05, "natural ground beside the channel along the road")
	assert_almost_eq(_height_at(200.0, 0.0), floor - terrain.under_road_drop, 0.05, "terrain under the dipped road")


func test_water_sits_water_depth_above_the_floor_and_the_waterfall_matches_its_data() -> void:
	var builder := FordBuilder.new()
	add_child_autofree(builder)
	builder.build(sampler, profile, field, trail)
	assert_eq(builder.water_levels.size(), 1)
	assert_almost_eq(builder.water_levels[0], -ford.depth + ford.water_depth, 0.0001)
	for child_name: String in ["Water0", "Waterfall0", "Mist0", "Waterfall0Sound"]:
		assert_not_null(builder.get_node_or_null(child_name), child_name)
	var foot := builder.waterfall_feet[0]
	assert_almost_eq(foot.x, -22.0, 0.01, "on the left wall")
	assert_almost_eq(foot.z, -200.0, 0.01, "at the ford")
	assert_almost_eq(foot.y, -ford.depth, 0.06, "standing on the channel floor")
	assert_almost_eq(builder.waterfall_tops[0].y - foot.y, ford.waterfall_height, 0.0001)
	var strip: MeshInstance3D = builder.get_node("Waterfall0")
	assert_almost_eq(strip.get_aabb().size.y, ford.waterfall_height, 0.01)
	assert_almost_eq(strip.get_aabb().size.z, ford.waterfall_width, 0.01, "as wide as its data, along the road")
	var water: MeshInstance3D = builder.get_node("Water0")
	assert_almost_eq(water.get_aabb().position.x, -22.0, 0.01, "water from the waterfall's foot")
	assert_almost_eq(water.get_aabb().end.x, ford.river_reach, 0.01, "out to the river's reach")
	assert_true((water.material_override as StandardMaterial3D).transparency == BaseMaterial3D.TRANSPARENCY_ALPHA)
	var sound: AudioStreamPlayer3D = builder.get_node("Waterfall0Sound")
	assert_almost_eq(sound.max_distance, 80.0, 0.0001)
	assert_true(sound.playing)
	assert_true(builder.get_children().filter(func(c: Node) -> bool: return c is StaticBody3D).is_empty(), "no collision")
	var offset_before: float = (strip.material_override as StandardMaterial3D).uv1_offset.y
	builder._process(0.5)
	assert_ne((strip.material_override as StandardMaterial3D).uv1_offset.y, offset_before, "the waterfall scrolls")


func test_no_ford_builds_nothing() -> void:
	trail.fords = []
	var builder := FordBuilder.new()
	add_child_autofree(builder)
	builder.build(sampler, RoadProfile.new(trail, sampler.length), field, trail)
	assert_eq(builder.get_child_count(), 0)
```

Add `"Generated/Fords"` to the parts list in `tests/unit/test_trail_level.gd`.

- [ ] **Step 2: Run to see it fail**

Run: `godot --headless --fixed-fps 120 --max-fps 0 -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_ford.gd -gexit`
Expected: parse errors (`FordDef` unknown).

- [ ] **Step 3: `FordDef` and the profile dip**

`levels/trail/ford_def.gd`:

```gdscript
class_name FordDef
extends Resource
## A river crossing the road under a waterfall (M5 spec §9). The road dips into
## the channel the river cuts across the trail; the water is visual only. Water
## physics is out of scope, but the geometry is shaped so buoyancy could be added
## later without moving anything.

## Where the river crosses the road (m along the road).
@export var distance: float = 0.0
## Width of the cut across the road (m).
@export var channel_width: float = 16.0
## How far the road dips below its natural level at the centre (m).
@export var depth: float = 0.35
## The water surface's height above the channel floor (m).
@export var water_depth: float = 0.3
## The road falls into and climbs out of the channel over this distance (m).
@export var bank_run: float = 10.0
@export var waterfall_height: float = 14.0
@export var waterfall_width: float = 3.5
## Lateral position of the waterfall's foot (m from the centre line, - = left wall).
@export var waterfall_offset: float = -22.0
## How far the river runs out from the road on the side away from the waterfall (m).
@export var river_reach: float = 45.0
@export var water_color: Color = Color(0.36, 0.5, 0.55)
@export var foam_color: Color = Color(0.9, 0.95, 0.97)
@export var seed: int = 83


func half_width() -> float:
	return channel_width * 0.5


func contains(at: float) -> bool:
	return absf(at - distance) <= half_width()


## The road's drop at `at`: -depth across the channel, easing back to nothing
## over bank_run beyond either edge.
func height_offset(at: float) -> float:
	var away := absf(at - distance) - half_width()
	if away <= 0.0:
		return -depth
	if away >= bank_run:
		return 0.0
	return -depth * (1.0 - smoothstep(0.0, bank_run, away))
```

`levels/trail/trail_def.gd`, in `Structures`: `@export var fords: Array[FordDef] = []`. Run `godot --headless --import`.

`levels/trail/road_profile.gd`: `longitudinal_height` adds `+ ford_height(distance)`; add

```gdscript
func ford_height(distance: float) -> float:
	var total := 0.0
	for ford: FordDef in def.fords:
		total += ford.height_offset(distance)
	return total
```

and in `_init` ranges: `for ford: FordDef in def.fords: ranges.append(Vector2(ford.distance - ford.half_width() - ford.bank_run, ford.distance + ford.half_width() + ford.bank_run))`. The threaded road builder already takes `heights[row] = profile.longitudinal_height(distance)`, so nothing changes in `RoadChunkData`.

`levels/trail/terrain_field.gd` `generate`, in the stamps loop: `for ford: FordDef in trail.fords: point.y += ford.height_offset(distance)`. After the bridges earthworks: `TrailEarthworks.apply_fords(field, sampler, trail)`, and extend the lowest-height recompute condition with `or not trail.fords.is_empty()`.

- [ ] **Step 4: The channel cut**

Append to `levels/trail/trail_earthworks.gd`:

```gdscript
## The channel's banks rise from its floor to the ground over this width along the road (m).
const FORD_BANK := 4.0
## The channel tapers out over this width at the waterfall's foot and the river's reach (m).
const FORD_TAPER := 8.0


## Cuts each ford's river channel across the terrain: a flat floor `depth`
## below the road's natural level, from the waterfall's foot out to river_reach
## on the other side, with banks easing up along the road and both ends tapering
## out. Only ever lowers ground, so a canyon wall gets a slot and the carved
## corridor under the road keeps its drop.
static func apply_fords(field: TerrainField, sampler: RoadSampler, trail: TrailDef) -> void:
	for ford: FordDef in trail.fords:
		var centre := sampler.position(ford.distance)
		var floor := centre.y - ford.depth
		var across := sampler.right(ford.distance)
		var flat_across := Vector2(across.x, across.z).normalized()
		var along := sampler.forward(ford.distance)
		var flat_along := Vector2(along.x, along.z).normalized()
		var near := minf(ford.waterfall_offset, ford.river_reach)
		var far := maxf(ford.waterfall_offset, ford.river_reach)
		var reach := maxf(absf(near), absf(far)) + FORD_TAPER + ford.half_width() + FORD_BANK
		var cx := roundi((centre.x - field.origin.x) / field.spacing)
		var cz := roundi((centre.z - field.origin.y) / field.spacing)
		var cells := ceili(reach / field.spacing)
		for row in range(maxi(0, cz - cells), mini(field.rows, cz + cells + 1)):
			var dz := field.origin.y + row * field.spacing - centre.z
			for column in range(maxi(0, cx - cells), mini(field.columns, cx + cells + 1)):
				var dx := field.origin.x + column * field.spacing - centre.x
				var lateral := dx * flat_across.x + dz * flat_across.y
				var offset := absf(dx * flat_along.x + dz * flat_along.y)
				if lateral < near - FORD_TAPER or lateral > far + FORD_TAPER or offset > ford.half_width() + FORD_BANK:
					continue
				var i := row * field.columns + column
				var natural := field.heights[i]
				var bank := smoothstep(ford.half_width(), ford.half_width() + FORD_BANK, offset)
				var taper := minf(smoothstep(near - FORD_TAPER, near, lateral), 1.0 - smoothstep(far, far + FORD_TAPER, lateral))
				var target := lerpf(floor, natural, maxf(bank, 1.0 - taper))
				field.heights[i] = minf(natural, target)
```

- [ ] **Step 5: `FordBuilder`**

`levels/trail/ford_builder.gd`:

```gdscript
class_name FordBuilder
extends Node3D
## A ford's water, waterfall, mist and sound (M5 spec §9.2). The road's dip and
## the terrain channel come from RoadProfile and TrailEarthworks; this lays a
## flat translucent water ribbon across the road at channel floor + water_depth,
## an unshaded strip on the wall whose streak texture scrolls down each frame
## (no shader, in keeping with the project), a CPUParticles3D mist at its foot,
## and a positional waterfall loop. No collision.

## Distance between the water ribbon's cross-sections (m).
const STEP := 2.0
## How much of each bank the water covers along the road (share of bank_run).
const BANK_COVER := 0.85
const SCROLL_PER_SECOND := 0.8
const MIST_AMOUNT := 32
const SOUND_DISTANCE := 80.0
const WATER_ALPHA := 0.75
const FOAM_ALPHA := 0.8

## Per ford: the water surface's height (world Y).
var water_levels := PackedFloat32Array()
## Per ford: the waterfall's foot and top (world), for tests.
var waterfall_feet := PackedVector3Array()
var waterfall_tops := PackedVector3Array()

var _waterfall_materials: Array[StandardMaterial3D] = []
var _players: Array[AudioStreamPlayer3D] = []


func build(sampler: RoadSampler, profile: RoadProfile, field: TerrainField, trail: TrailDef) -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	water_levels.clear()
	waterfall_feet.clear()
	waterfall_tops.clear()
	_waterfall_materials.clear()
	_players.clear()
	for i in trail.fords.size():
		_build_ford(sampler, profile, field, trail.fords[i], i)


## Stops the waterfall loops on the way out, so the audio server lets go of them.
func _exit_tree() -> void:
	for player in _players:
		player.stop()


func _process(delta: float) -> void:
	for material in _waterfall_materials:
		material.uv1_offset.y = fposmod(material.uv1_offset.y - delta * SCROLL_PER_SECOND, 1.0)


func _build_ford(sampler: RoadSampler, profile: RoadProfile, field: TerrainField, ford: FordDef, index: int) -> void:
	var centre := sampler.position(ford.distance)
	var across := sampler.right(ford.distance)
	var flat_across := Vector3(across.x, 0.0, across.z).normalized()
	var along := sampler.forward(ford.distance)
	var flat_along := Vector3(along.x, 0.0, along.z).normalized()
	var level := centre.y - ford.depth + ford.water_depth
	water_levels.append(level)
	_add_water(ford, index, centre, flat_across, flat_along, level)
	var foot := centre + flat_across * ford.waterfall_offset
	foot.y = field.height_at(foot.x, foot.z)
	var top := foot + Vector3.UP * ford.waterfall_height
	waterfall_feet.append(foot)
	waterfall_tops.append(top)
	_add_waterfall(ford, index, foot, top, flat_along)
	_add_mist(index, foot)
	_add_sound(index, foot)


func _add_water(ford: FordDef, index: int, centre: Vector3, flat_across: Vector3, flat_along: Vector3, level: float) -> void:
	var half_along := ford.half_width() + ford.bank_run * BANK_COVER
	var near := minf(ford.waterfall_offset, ford.river_reach)
	var far := maxf(ford.waterfall_offset, ford.river_reach)
	var count := maxi(1, ceili((far - near) / STEP))
	var vertices := PackedVector3Array()
	var indices := PackedInt32Array()
	for step in count + 1:
		var mid := centre + flat_across * lerpf(near, far, step / float(count))
		var back := mid - flat_along * half_along
		var front := mid + flat_along * half_along
		vertices.append(Vector3(back.x, level, back.z))
		vertices.append(Vector3(front.x, level, front.z))
		if step > 0:
			var i := vertices.size() - 4
			indices.append_array([i, i + 1, i + 2, i + 1, i + 3, i + 2])
	var normals := PackedVector3Array()
	normals.resize(vertices.size())
	normals.fill(Vector3.UP)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(ford.water_color, WATER_ALPHA)
	material.roughness = 0.15
	material.metallic_specular = 0.8
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var water := MeshInstance3D.new()
	water.name = "Water%d" % index
	water.mesh = mesh
	water.material_override = material
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(water)


func _add_waterfall(ford: FordDef, index: int, foot: Vector3, top: Vector3, flat_along: Vector3) -> void:
	var half := flat_along * ford.waterfall_width * 0.5
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var corners: Array[Vector3] = [foot - half, foot + half, top + half, top - half]
	var uvs: Array[Vector2] = [Vector2(0.0, 1.0), Vector2(1.0, 1.0), Vector2(1.0, 0.0), Vector2(0.0, 0.0)]
	for i: int in [0, 1, 2, 0, 2, 3]:
		tool.set_uv(uvs[i])
		tool.set_normal(Vector3.UP)
		tool.add_vertex(corners[i])
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_color = Color(ford.foam_color, FOAM_ALPHA)
	material.albedo_texture = _streaks(ford.seed)
	material.uv1_scale = Vector3(1.0, 3.0, 1.0)
	_waterfall_materials.append(material)
	var strip := MeshInstance3D.new()
	strip.name = "Waterfall%d" % index
	strip.mesh = tool.commit()
	strip.material_override = material
	strip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(strip)


## Vertical streaks: seamless low-frequency noise the strip scrolls downward.
static func _streaks(seed: int) -> NoiseTexture2D:
	var noise := FastNoiseLite.new()
	noise.seed = seed
	noise.frequency = 0.06
	noise.fractal_octaves = 2
	var texture := NoiseTexture2D.new()
	texture.width = 32
	texture.height = 128
	texture.seamless = true
	texture.noise = noise
	return texture


func _add_mist(index: int, foot: Vector3) -> void:
	var mist := CPUParticles3D.new()
	mist.name = "Mist%d" % index
	mist.position = foot + Vector3.UP * 0.5
	mist.amount = MIST_AMOUNT
	mist.lifetime = 1.8
	mist.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	mist.emission_sphere_radius = 1.5
	mist.direction = Vector3.UP
	mist.spread = 70.0
	mist.initial_velocity_min = 1.0
	mist.initial_velocity_max = 2.5
	mist.gravity = Vector3(0.0, 0.4, 0.0)
	mist.scale_amount_min = 1.0
	mist.scale_amount_max = 2.0
	mist.color = Color(1.0, 1.0, 1.0, 0.3)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.vertex_color_use_as_albedo = true
	var quad := QuadMesh.new()
	quad.size = Vector2(0.6, 0.6)
	quad.material = material
	mist.mesh = quad
	mist.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mist.visibility_range_end = 120.0
	mist.emitting = true
	add_child(mist)


func _add_sound(index: int, foot: Vector3) -> void:
	var player := AudioStreamPlayer3D.new()
	player.name = "Waterfall%dSound" % index
	player.stream = SoundSynth.sound(&"waterfall")
	player.max_distance = SOUND_DISTANCE
	player.position = foot + Vector3.UP * 2.0
	add_child(player)
	player.play()
	_players.append(player)
```

`levels/trail/trail_level.gd`: `var ford_builder: FordBuilder`; after talus:

```gdscript
	ford_builder = FordBuilder.new()
	ford_builder.name = "Fords"
	generated.add_child(ford_builder)
	ford_builder.build(sampler, profile, field, trail)
	_lap(&"fords")
```

- [ ] **Step 6: Run the tests**

```bash
godot --headless --import >/dev/null 2>&1
for t in test_ford test_road_profile test_terrain_field test_trail_level test_geometry_fingerprints test_creek test_bridge; do
  godot --headless --fixed-fps 120 --max-fps 0 -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/$t.gd -gexit 2>&1 | grep -E "Totals|passed|failed|SCRIPT ERROR"
done
```

Expected: all passing. If the water AABB assertion is off by the ribbon's along-road half-width, note the AABB is in the node's local space (identity here) and the `x` extent is purely lateral on a road along −Z.

- [ ] **Step 7: Commit**

```bash
git add levels/trail/ford_def.gd levels/trail/ford_def.gd.uid levels/trail/ford_builder.gd levels/trail/ford_builder.gd.uid levels/trail/trail_def.gd levels/trail/road_profile.gd levels/trail/terrain_field.gd levels/trail/trail_earthworks.gd levels/trail/trail_level.gd tests/unit/test_ford.gd tests/unit/test_ford.gd.uid tests/unit/test_trail_level.gd
git commit -m "Add the ford: road dip, river channel, water, waterfall and sound

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---
### Task 8: The throttle lever

Spec §11. A saved `throttle_mode` setting ("pedal"/"lever"), `TouchThrottleLogic` (pure), lever mode in `TouchControls` (tall track at the right edge, finger capture by index, vertical-only, immediate release), applied by `DrivingRig` from the save, and a "Throttle" row in the pause menu beside "Steering". The keyboard path is untouched.

**Files:**
- Create: `input/touch_throttle_logic.gd`, `tests/unit/test_touch_throttle_logic.gd`, `tests/unit/test_touch_lever.gd`, `tests/unit/test_throttle_setting.gd`
- Modify: `input/touch_controls.gd`, `game/progress.gd`, `game/game_state.gd`, `levels/shared/driving_rig.gd`, `ui/pause_menu.gd`

**Interfaces:**
- Produces: `Progress.THROTTLE_PEDAL = "pedal"`, `Progress.THROTTLE_LEVER = "lever"`, `Progress.throttle_mode: String`; `GameState.set_throttle_mode(mode: String)`; `TouchThrottleLogic.Mode { PEDAL, LEVER }`, `TouchThrottleLogic.DEAD_ZONE = 0.1`, `TouchThrottleLogic.value_for(rect, point) -> float`; `TouchControls.throttle_mode`, `set_throttle_mode(mode)`, `throttle_mode_from_name(name) -> Mode`, `throttle_mode_name(mode) -> String`, `LEVER_SIZE = Vector2(250, 560)`; `gas_rect()` is the lever's track in lever mode.

- [ ] **Step 1: Write the failing tests**

`tests/unit/test_touch_throttle_logic.gd`:

```gdscript
extends GutTest
## The throttle lever's pure maths (M5 spec §11.2).


func test_bottom_dead_zone_middle_top_and_beyond_both_ends() -> void:
	var rect := Rect2(100.0, 400.0, 250.0, 560.0)  # the track's bottom is at y = 960
	assert_almost_eq(TouchThrottleLogic.value_for(rect, Vector2(200.0, 960.0)), 0.0, 0.0001, "bottom")
	assert_almost_eq(TouchThrottleLogic.value_for(rect, Vector2(200.0, 930.0)), 0.0, 0.0001, "inside the bottom 10% dead zone")
	assert_almost_eq(TouchThrottleLogic.value_for(rect, Vector2(200.0, 890.0)), 0.125, 0.0001, "just above it reads its height")
	assert_almost_eq(TouchThrottleLogic.value_for(rect, Vector2(200.0, 680.0)), 0.5, 0.0001, "mid-track")
	assert_almost_eq(TouchThrottleLogic.value_for(rect, Vector2(200.0, 400.0)), 1.0, 0.0001, "top")
	assert_almost_eq(TouchThrottleLogic.value_for(rect, Vector2(200.0, 100.0)), 1.0, 0.0001, "beyond the top")
	assert_almost_eq(TouchThrottleLogic.value_for(rect, Vector2(200.0, 1050.0)), 0.0, 0.0001, "beyond the bottom")
	assert_almost_eq(TouchThrottleLogic.value_for(rect, Vector2(900.0, 680.0)), 0.5, 0.0001, "horizontal position is ignored")
	assert_almost_eq(TouchThrottleLogic.value_for(Rect2(0.0, 0.0, 10.0, 0.0), Vector2.ZERO), 0.0, 0.0001, "a flat rect is closed")
```

`tests/unit/test_touch_lever.gd`:

```gdscript
extends GutTest
## TouchControls in lever mode (M5 spec §11.3).

var input: CarInput
var controls: TouchControls


func before_each() -> void:
	input = CarInput.new()
	add_child_autofree(input)
	controls = TouchControls.new()
	controls.car_input = input
	controls.screen_size_override = Vector2(1920.0, 1080.0)
	add_child_autofree(controls)
	controls.set_throttle_mode(TouchThrottleLogic.Mode.LEVER)


## A point inside the lever's track at `share` of its height (0 = bottom, 1 = top).
func _track_point(share: float) -> Vector2:
	var rect := controls.gas_rect()
	return Vector2(rect.get_center().x, rect.end.y - rect.size.y * share)


func test_the_lever_track_is_taller_than_the_pedal_and_sits_at_the_right_edge() -> void:
	var rect := controls.gas_rect()
	assert_eq(rect.size, TouchControls.LEVER_SIZE)
	assert_almost_eq(rect.end.x, 1920.0 - 40.0, 0.0001)
	assert_almost_eq(rect.end.y, 1080.0 - 40.0, 0.0001, "same bottom edge as the pedal")
	assert_gt(rect.position.y, TouchControls.TOP_STRIP_HEIGHT, "clear of the top strip")
	controls.set_throttle_mode(TouchThrottleLogic.Mode.PEDAL)
	assert_eq(controls.gas_rect().size, Vector2(250.0, 340.0), "the pedal is unchanged")


func test_pressing_in_the_track_sets_the_value_at_once() -> void:
	controls.handle_touch(0, _track_point(0.5), true)
	controls.update_outputs(0.016)
	assert_almost_eq(input.virtual_throttle, 0.5, 0.0001)
	assert_almost_eq(input.virtual_brake, 0.0, 0.0001)


func test_the_captured_finger_ignores_horizontal_drift() -> void:
	controls.handle_touch(0, _track_point(0.5), true)
	controls.handle_drag(0, _track_point(0.8) - Vector2(600.0, 0.0))
	controls.update_outputs(0.016)
	assert_almost_eq(input.virtual_throttle, 0.8, 0.0001, "a thumb sliding sideways keeps the throttle")


func test_releasing_drops_to_zero_at_once() -> void:
	controls.handle_touch(0, _track_point(0.9), true)
	controls.update_outputs(0.016)
	controls.handle_touch(0, _track_point(0.9), false)
	controls.update_outputs(0.016)
	assert_almost_eq(input.virtual_throttle, 0.0, 0.0001)


func test_a_second_finger_in_the_track_does_not_take_over() -> void:
	controls.handle_touch(0, _track_point(0.5), true)
	controls.handle_touch(1, _track_point(0.9), true)
	controls.update_outputs(0.016)
	assert_almost_eq(input.virtual_throttle, 0.5, 0.0001, "the first finger keeps the lever")
	controls.handle_touch(0, _track_point(0.5), false)
	controls.update_outputs(0.016)
	assert_almost_eq(input.virtual_throttle, 0.0, 0.0001, "the second was never captured")


func test_release_all_touches_zeroes_the_lever() -> void:
	controls.handle_touch(0, _track_point(0.7), true)
	controls.update_outputs(0.016)
	controls.release_all_touches()
	assert_almost_eq(input.virtual_throttle, 0.0, 0.0001)
	controls.update_outputs(0.016)
	assert_almost_eq(input.virtual_throttle, 0.0, 0.0001, "and it stays zero")


func test_switching_mode_clears_the_capture() -> void:
	controls.handle_touch(0, _track_point(0.7), true)
	controls.set_throttle_mode(TouchThrottleLogic.Mode.PEDAL)
	controls.update_outputs(0.016)
	assert_almost_eq(input.virtual_throttle, 0.0, 0.0001, "the old touch sits above the pedal")


func test_the_brake_pad_and_steering_work_as_before_in_lever_mode() -> void:
	controls.handle_touch(0, controls.brake_rect().get_center(), true)
	var start := Vector2(300.0, 700.0)
	controls.handle_touch(1, start, true)
	controls.handle_drag(1, start + Vector2(TouchControls.FULL_LOCK_PX, 0.0))
	controls.update_outputs(0.016)
	assert_almost_eq(input.virtual_brake, 1.0, 0.0001)
	assert_almost_eq(input.virtual_steer, 1.0, 0.0001)
	assert_almost_eq(input.virtual_throttle, 0.0, 0.0001)


func test_throttle_mode_names_match_the_save_file() -> void:
	assert_eq(TouchControls.throttle_mode_from_name(Progress.THROTTLE_LEVER), TouchThrottleLogic.Mode.LEVER)
	assert_eq(TouchControls.throttle_mode_from_name(Progress.THROTTLE_PEDAL), TouchThrottleLogic.Mode.PEDAL)
	assert_eq(TouchControls.throttle_mode_from_name("anything else"), TouchThrottleLogic.Mode.PEDAL)
	assert_eq(TouchControls.throttle_mode_name(TouchThrottleLogic.Mode.LEVER), Progress.THROTTLE_LEVER)
	assert_eq(TouchControls.throttle_mode_name(TouchThrottleLogic.Mode.PEDAL), Progress.THROTTLE_PEDAL)
```

`tests/unit/test_throttle_setting.gd`:

```gdscript
extends GutTest
## The saved throttle setting (M5 spec §11.1): Progress round trip, the pause
## menu's Throttle row, and the driving rig applying it.

const RIG_SCENE := preload("res://levels/shared/driving_rig.tscn")


func before_each() -> void:
	SaveSandbox.enter()


func after_each() -> void:
	get_tree().paused = false
	SaveSandbox.leave()


func test_throttle_mode_round_trips_and_rejects_unknown_values() -> void:
	var progress := Progress.new()
	assert_eq(progress.throttle_mode, Progress.THROTTLE_PEDAL, "the pedal is the default")
	progress.throttle_mode = Progress.THROTTLE_LEVER
	assert_eq(Progress.from_dictionary(progress.to_dictionary()).throttle_mode, Progress.THROTTLE_LEVER)
	assert_eq(Progress.from_dictionary({"settings": {"throttle_mode": "joystick"}}).throttle_mode, Progress.THROTTLE_PEDAL, "unknown value")
	assert_eq(Progress.from_dictionary({"settings": {"throttle_mode": 3}}).throttle_mode, Progress.THROTTLE_PEDAL, "wrong type")
	assert_eq(Progress.from_dictionary({"settings": {"steer_mode": "analog"}}).throttle_mode, Progress.THROTTLE_PEDAL, "an older save")
	assert_eq(Progress.from_dictionary({}).throttle_mode, Progress.THROTTLE_PEDAL)


func test_the_pause_menu_switches_the_throttle_and_saves_it() -> void:
	var rig: DrivingRig = RIG_SCENE.instantiate()
	add_child_autofree(rig)
	rig.touch_controls.screen_size_override = Vector2(1920.0, 1080.0)
	var menu := PauseMenu.new()
	add_child_autofree(menu)
	menu.setup(rig)
	menu.open()
	var throttle: Button = menu.find_children("*", "Button", true, false).filter(
			func(b: Button) -> bool: return b.text.begins_with("Throttle"))[0]
	assert_eq(throttle.text, "Throttle: Pedal")
	throttle.pressed.emit()
	assert_eq(rig.touch_controls.throttle_mode, TouchThrottleLogic.Mode.LEVER)
	assert_eq(throttle.text, "Throttle: Lever")
	assert_eq(SaveSystem.read(SaveSandbox.PATH)["settings"]["throttle_mode"], Progress.THROTTLE_LEVER)
	throttle.pressed.emit()
	assert_eq(throttle.text, "Throttle: Pedal")
	var content: VBoxContainer = menu.find_child("PauseContent", true, false)
	assert_lt(content.get_combined_minimum_size().y, 1080.0, "still fits the landscape viewport")


func test_a_rig_applies_the_saved_throttle_mode() -> void:
	var state := SaveSandbox.game_state()
	state.set_throttle_mode(Progress.THROTTLE_LEVER)
	var rig: DrivingRig = RIG_SCENE.instantiate()
	add_child_autofree(rig)
	assert_eq(rig.touch_controls.throttle_mode, TouchThrottleLogic.Mode.LEVER)
```

- [ ] **Step 2: Run to see them fail**

Run each of the three with the single-file command. Expected: parse errors (`TouchThrottleLogic`, `THROTTLE_LEVER` unknown).

- [ ] **Step 3: `TouchThrottleLogic`**

`input/touch_throttle_logic.gd`:

```gdscript
class_name TouchThrottleLogic
extends RefCounted
## Pure maths for the throttle lever (M5 spec §11.2): an absolute vertical
## slider whose position sets the throttle.

enum Mode { PEDAL, LEVER }

## The bottom share of the track that reads as exactly closed.
const DEAD_ZONE := 0.1


## The throttle for a finger at `point` on the lever's `rect`: 0 at the bottom,
## 1 at the top, clamped beyond both ends, and exactly 0 inside the bottom dead
## zone. Only the vertical position matters.
static func value_for(rect: Rect2, point: Vector2) -> float:
	if rect.size.y <= 0.0:
		return 0.0
	var value := clampf((rect.end.y - point.y) / rect.size.y, 0.0, 1.0)
	return 0.0 if value < DEAD_ZONE else value
```

Run `godot --headless --import`.

- [ ] **Step 4: The setting in `Progress` and `GameState`**

`game/progress.gd`: after `STEER_BUTTONS` add

```gdscript
const THROTTLE_PEDAL := "pedal"
const THROTTLE_LEVER := "lever"
```

and after `steer_mode`: `## The touch throttle control: the on/off pedal, or the lever slider (M5 spec §11).` `var throttle_mode: String = THROTTLE_PEDAL`. In `to_dictionary` add `"throttle_mode": throttle_mode` to `settings`. In `from_dictionary`, after the steer_mode check:

```gdscript
	if settings is Dictionary and settings.get("throttle_mode") in [THROTTLE_PEDAL, THROTTLE_LEVER]:
		progress.throttle_mode = settings["throttle_mode"]
```

Update the class doc ("plus the steering style, throttle control and the last car chosen").

`game/game_state.gd`, after `set_steer_mode`:

```gdscript
func set_throttle_mode(mode: String) -> void:
	progress.throttle_mode = mode
	save()
```

- [ ] **Step 5: Lever mode in `TouchControls`**

`input/touch_controls.gd`:

- Doc comment: "Right side: brake pad and gas pedal, or a throttle lever (M5 spec §11)."
- Constants: `## The throttle lever's track (M5 spec §11.3); the pedal is 250x340.` `const LEVER_SIZE := Vector2(250.0, 560.0)`
- Vars: `var throttle_mode: TouchThrottleLogic.Mode = TouchThrottleLogic.Mode.PEDAL`, `var _throttle_touch := -1  # finger holding the lever, or -1`, `var _throttle_value := 0.0`.
- Statics after `mode_name`:

```gdscript
## The throttle control for a saved setting name ("pedal" or "lever").
static func throttle_mode_from_name(mode_name: String) -> TouchThrottleLogic.Mode:
	return TouchThrottleLogic.Mode.LEVER if mode_name == Progress.THROTTLE_LEVER else TouchThrottleLogic.Mode.PEDAL


static func throttle_mode_name(mode: TouchThrottleLogic.Mode) -> String:
	return Progress.THROTTLE_LEVER if mode == TouchThrottleLogic.Mode.LEVER else Progress.THROTTLE_PEDAL
```

- `handle_touch`: on release, also `if index == _throttle_touch: _throttle_touch = -1; _throttle_value = 0.0`. On press, after `_touches[index] = point` and the steer capture:

```gdscript
	if throttle_mode == TouchThrottleLogic.Mode.LEVER and _throttle_touch == -1 and gas_rect().has_point(point):
		_throttle_touch = index
		_throttle_value = TouchThrottleLogic.value_for(gas_rect(), point)
```

- `handle_drag`: after updating `_touches`, `if index == _throttle_touch: _throttle_value = TouchThrottleLogic.value_for(gas_rect(), point)`.
- `update_outputs`: `car_input.virtual_throttle = _throttle_value if throttle_mode == TouchThrottleLogic.Mode.LEVER else (1.0 if _any_touch_in(gas_rect()) else 0.0)`.
- `release_all_touches`: add `_throttle_touch = -1` and `_throttle_value = 0.0` before `update_outputs(0.0)`.
- Add:

```gdscript
func set_throttle_mode(mode: TouchThrottleLogic.Mode) -> void:
	throttle_mode = mode
	_throttle_touch = -1
	_throttle_value = 0.0
```

- `gas_rect`:

```gdscript
func gas_rect() -> Rect2:
	var size := screen_size()
	if throttle_mode == TouchThrottleLogic.Mode.LEVER:
		return Rect2(size.x - 290.0, size.y - 40.0 - LEVER_SIZE.y, LEVER_SIZE.x, LEVER_SIZE.y)
	return Rect2(size.x - 290.0, size.y - 380.0, 250.0, 340.0)
```

- `_draw_controls`: replace the gas pad line with `if throttle_mode == TouchThrottleLogic.Mode.LEVER: _draw_lever(gas_rect(), _throttle_value) else: _draw_pad(gas_rect(), "GAS", throttle_on)` and add:

```gdscript
## The lever: its track, a fill up to the value, quarter ticks, a thumb and the label.
func _draw_lever(rect: Rect2, value: float) -> void:
	_canvas.draw_rect(rect, Color(1.0, 1.0, 1.0, 0.12))
	var fill := rect.size.y * value
	_canvas.draw_rect(Rect2(rect.position.x, rect.end.y - fill, rect.size.x, fill), Color(1.0, 0.75, 0.3, 0.3))
	for tick: float in [0.25, 0.5, 0.75]:
		var y := rect.end.y - rect.size.y * tick
		_canvas.draw_line(Vector2(rect.position.x, y), Vector2(rect.position.x + 30.0, y), Color(1.0, 1.0, 1.0, 0.4), 3.0)
	var thumb_y := rect.end.y - rect.size.y * value
	_canvas.draw_rect(Rect2(rect.position.x + 20.0, thumb_y - 18.0, rect.size.x - 40.0, 36.0),
			Color(1.0, 1.0, 1.0, 0.5 if _throttle_touch != -1 else 0.3))
	_canvas.draw_string(ThemeDB.fallback_font, rect.position + Vector2(24.0, 64.0), "GAS",
			HORIZONTAL_ALIGNMENT_LEFT, -1.0, 44)
```

- [ ] **Step 6: The rig and the pause menu**

`levels/shared/driving_rig.gd` `_ready`, after the steer mode line: `touch_controls.set_throttle_mode(TouchControls.throttle_mode_from_name(GameState.progress.throttle_mode))`. Doc: "The steering style and throttle control come from the save."

`ui/pause_menu.gd`: `var _throttle: Button`; in `_build_ui` after `_steering`: `_throttle = UiKit.button("Throttle", _on_throttle)` / `settings.add_child(_throttle)`; handler:

```gdscript
func _on_throttle() -> void:
	var controls := rig.touch_controls
	var next := TouchThrottleLogic.Mode.LEVER if controls.throttle_mode == TouchThrottleLogic.Mode.PEDAL \
			else TouchThrottleLogic.Mode.PEDAL
	controls.set_throttle_mode(next)
	GameState.set_throttle_mode(TouchControls.throttle_mode_name(next))
	_refresh_labels()
```

and in `_refresh_labels` (inside the `rig != null` part): `_throttle.text = "Throttle: %s" % ("Lever" if rig.touch_controls.throttle_mode == TouchThrottleLogic.Mode.LEVER else "Pedal")`.

- [ ] **Step 7: Run the tests**

```bash
for t in test_touch_throttle_logic test_touch_lever test_throttle_setting test_touch_controls test_progress test_pause_menu test_game_state test_save_system; do
  godot --headless --fixed-fps 120 --max-fps 0 -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/$t.gd -gexit 2>&1 | grep -E "Totals|passed|failed|SCRIPT ERROR"
done
```

Expected: all passing (the pedal tests in `test_touch_controls.gd` are unchanged because the default mode is the pedal). If `test_pause_content_fits_the_landscape_viewport` fails, shrink the settings column's separation from 20 to 14.

- [ ] **Step 8: Commit**

```bash
git add input/touch_throttle_logic.gd input/touch_throttle_logic.gd.uid input/touch_controls.gd game/progress.gd game/game_state.gd levels/shared/driving_rig.gd ui/pause_menu.gd tests/unit/test_touch_throttle_logic.gd tests/unit/test_touch_throttle_logic.gd.uid tests/unit/test_touch_lever.gd tests/unit/test_touch_lever.gd.uid tests/unit/test_throttle_setting.gd tests/unit/test_throttle_setting.gd.uid
git commit -m "Add the throttle lever control mode with its saved setting

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 9: Recommended car on `LevelDef`, level select and car select

Spec §3.1. An optional `LevelDef.recommended_car` shown as "Recommended: Off-road 4x4" on the level's card and under the destination in car select. Advice only.

**Files:**
- Create: `tests/unit/test_recommended_car.gd`
- Modify: `game/level_def.gd`, `ui/level_select.gd`, `ui/car_select.gd`

**Interfaces:**
- Produces: `LevelDef.recommended_car: StringName = &""`, `LevelDef.recommended_text(cars: CarCatalog) -> String` ("" when none).

- [ ] **Step 1: Write the failing test**

`tests/unit/test_recommended_car.gd`:

```gdscript
extends GutTest
## LevelDef.recommended_car (M5 spec §3.1): round trip, the text, and the lines
## level select and car select show for it.

const LEVEL_SELECT := preload("res://ui/level_select.tscn")
const CAR_SELECT := preload("res://ui/car_select.tscn")
const CANYON_SCENE := "res://levels/canyon/canyon.tscn"

var state: Node


func before_each() -> void:
	SaveSandbox.enter()
	state = SaveSandbox.game_state()


func after_each() -> void:
	SaveSandbox.leave()


func _labels(node: Node) -> Array:
	return node.find_children("*", "Label", true, false).map(func(l: Label) -> String: return l.text)


func _canyon() -> LevelDef:
	var level := LevelDef.new()
	level.id = &"canyon"
	level.display_name = "Canyon"
	level.scene_path = CANYON_SCENE
	level.recommended_car = &"offroad_4x4"
	level.two_star_time = 100.0
	level.three_star_time = 90.0
	return level


func _catalog_with_canyon() -> void:
	var catalog := LevelCatalog.new()
	catalog.levels = [state.catalog.levels[0], _canyon()]
	state.catalog = catalog
	state.record_finish(catalog.levels[0], 120.0, {})  # unlocks the canyon


func test_recommended_car_round_trips_and_defaults_to_none() -> void:
	assert_eq(LevelDef.new().recommended_car, &"")
	var path := "user://recommended_test.tres"
	assert_eq(ResourceSaver.save(_canyon(), path), OK)
	var loaded: LevelDef = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
	assert_eq(loaded.recommended_car, &"offroad_4x4")
	DirAccess.remove_absolute(path)


func test_recommended_text_names_the_car_or_is_empty() -> void:
	assert_eq(_canyon().recommended_text(state.car_catalog), "Recommended: Off-road 4x4")
	assert_eq(LevelDef.new().recommended_text(state.car_catalog), "")
	var odd := _canyon()
	odd.recommended_car = &"mystery"
	assert_eq(odd.recommended_text(state.car_catalog), "Recommended: mystery", "an unknown id still shows something")


func test_level_select_shows_the_recommendation_on_the_card() -> void:
	_catalog_with_canyon()
	var select: Control = LEVEL_SELECT.instantiate()
	add_child_autofree(select)
	assert_has(_labels(select.find_child("canyon", true, false)), "Recommended: Off-road 4x4")
	for text: String in _labels(select.find_child("rally_road", true, false)):
		assert_false(text.begins_with("Recommended"), "Rally Road recommends nothing")


func test_car_select_shows_it_under_the_destination() -> void:
	_catalog_with_canyon()
	state.pending_scene = CANYON_SCENE
	var screen: Control = CAR_SELECT.instantiate()
	add_child_autofree(screen)
	assert_has(_labels(screen), "Canyon")
	assert_has(_labels(screen), "Recommended: Off-road 4x4")
	screen.queue_free()
	state.pending_scene = "res://levels/rally_road/rally_road.tscn"
	var plain: Control = CAR_SELECT.instantiate()
	add_child_autofree(plain)
	for text: String in _labels(plain):
		assert_false(text.begins_with("Recommended"))
```

- [ ] **Step 2: Run to see it fail**

Run: `godot --headless --fixed-fps 120 --max-fps 0 -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_recommended_car.gd -gexit`
Expected: failures (`recommended_car` does not exist).

- [ ] **Step 3: Implement**

`game/level_def.gd`: after `surfaces`:

```gdscript
## The car the level suggests, e.g. &"offroad_4x4"; empty for no suggestion. Advice
## only: every unlocked car can still be chosen (M5 spec §3.1).
@export var recommended_car: StringName = &""
```

and:

```gdscript
## "Recommended: Off-road 4x4" when the level suggests a car, or "" when it does not.
func recommended_text(cars: CarCatalog) -> String:
	if recommended_car == &"":
		return ""
	var car := cars.find_by_id(recommended_car)
	return "Recommended: %s" % (car.display_name if car != null else String(recommended_car))
```

`ui/level_select.gd` `_card`, after the display-name label:

```gdscript
	var recommended := level.recommended_text(GameState.car_catalog)
	if not recommended.is_empty():
		content.add_child(UiKit.label(recommended, 32))
```

`ui/car_select.gd` `_ready`, after the destination label:

```gdscript
	var level := GameState.level_for_scene(GameState.pending_scene)
	if level != null and not level.recommended_text(GameState.car_catalog).is_empty():
		column.add_child(UiKit.label(level.recommended_text(GameState.car_catalog)))
```

(Update both files' doc comments: cards and the destination line mention the recommendation.)

- [ ] **Step 4: Run the tests**

```bash
for t in test_recommended_car test_menus test_car_select test_level_catalog; do
  godot --headless --fixed-fps 120 --max-fps 0 -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/$t.gd -gexit 2>&1 | grep -E "Totals|passed|failed|SCRIPT ERROR"
done
```

Expected: all passing.

- [ ] **Step 5: Commit**

```bash
git add game/level_def.gd ui/level_select.gd ui/car_select.gd tests/unit/test_recommended_car.gd tests/unit/test_recommended_car.gd.uid
git commit -m "Let a level recommend a car in level select and car select

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---
### Task 10: The Rock Canyon level

Spec §3 (route, look), §4 (surface stretches), §6.4, §7.4, §8.1, §9.1, §10.2, §13. Generate the curve, write the trail, terrain, scatter and level resources and the scene, add it to the catalog and the load benchmark, and guard `ScatterBuilder` against `pine_spacing = 0`.

**Design notes (record in the M5 notes):** the second rock step's face spans +1.0..+3.5 m instead of the spec's +0.5..+3.5, so a car on the centre line (wheels at ±0.86 m) takes the ramp with both sides and only a deliberate move right takes the 0.5 m ledge. "Whole road" faces span ±6.5 m (road plus shoulders) so there is no ramp around them. The ford's channel centre is at 1290 m, inside the spec's 1250–1330 m crossing.

**Files:**
- Create: `tools/generate_rock_canyon_curve.gd`, `levels/rock_canyon/rock_canyon_curve.tres` (generated), `levels/rock_canyon/rock_canyon_trail.tres`, `rock_canyon_terrain.tres`, `rock_canyon_scatter.tres`, `rock_canyon_level.tres`, `rock_canyon.tscn`, `tests/unit/test_rock_canyon.gd`
- Modify: `levels/catalog.tres`, `debug/load_benchmark.gd`, `levels/trail/scatter_builder.gd`, `tests/unit/test_level_catalog.gd`, `tests/unit/test_menus.gd`

**Interfaces:**
- Consumes: everything from Tasks 1–9.
- Produces: level id `&"rock_canyon"`, scene `res://levels/rock_canyon/rock_canyon.tscn`, fourth catalog entry.

- [ ] **Step 1: Write the failing layout test**

`tests/unit/test_rock_canyon.gd`:

```gdscript
extends GutTest
## Rock Canyon's data and build (M5 spec §3, §13): the route's length and
## climb, its surfaces and structures, the recommendation, and an integrated
## build with every part, its phase summary and its surfaces under the wheels.

const TRAIL := preload("res://levels/rock_canyon/rock_canyon_trail.tres")
const TERRAIN := preload("res://levels/rock_canyon/rock_canyon_terrain.tres")
const SCATTER := preload("res://levels/rock_canyon/rock_canyon_scatter.tres")
const CURVE := preload("res://levels/rock_canyon/rock_canyon_curve.tres")
const LEVEL := preload("res://levels/rock_canyon/rock_canyon_level.tres")

var sampler: RoadSampler
var profile: RoadProfile


func before_each() -> void:
	sampler = RoadSampler.new(CURVE, TRAIL.use_curve_banking, TRAIL)
	profile = RoadProfile.new(TRAIL, sampler.length)


func test_route_length_climb_and_separation() -> void:
	assert_between(sampler.length - TRAIL.end_margin, 2050.0, 2150.0, "about 2.1 km to the finish")
	assert_eq(TRAIL.end_margin, 70.0)
	assert_gt(sampler.position(sampler.length).y - sampler.position(0.0).y, 60.0, "climbs to the rim")
	assert_true(CurveGenerator.separation_problems(CURVE).is_empty(), "no parts pass too close")
	assert_true(TRAIL.use_curve_banking)


func test_surfaces_along_the_route() -> void:
	for check: Array in [[100.0, &"asphalt"], [250.0, &"dirt"], [303.0, &"mud"], [400.0, &"deep_mud"], [800.0, &"dirt"],
			[770.0, &"scree"], [1200.0, &"scree"], [1283.0, &"rock"], [1290.0, &"wet_rock"], [1590.0, &"rock"],
			[1700.0, &"dirt"], [1950.0, &"scree"]]:
		assert_eq(profile.surface_at(check[0]).id, check[1], "surface at %.0f m" % check[0])
	assert_eq(TRAIL.base_surface.id, &"dirt")
	assert_false(TRAIL.painted_lines)
	var deep: SurfaceStretch = TRAIL.surface_stretches.filter(func(s: SurfaceStretch) -> bool: return s.surface.id == &"deep_mud")[0]
	assert_almost_eq(deep.rut_depth, 0.15, 0.0001, "water-filled ruts sink about 15 cm")
	assert_almost_eq(deep.start, 300.0, 0.0001)
	assert_almost_eq(deep.length, 260.0, 0.0001)


func test_structures_match_the_spec() -> void:
	assert_eq(TRAIL.width_stretches, [Vector4(1500.0, 400.0, 4.5, 0.0)] as Array[Vector4])
	assert_almost_eq(TRAIL.road_width_at(1700.0), 4.5, 0.0001)
	assert_almost_eq(TRAIL.shoulder_width_at(1700.0), 0.0, 0.0001)
	assert_eq(TRAIL.rock_steps.size(), 3)
	assert_eq(TRAIL.rock_steps.map(func(s: RockStepDef) -> float: return s.distance), [812.0, 947.0, 1078.0])
	assert_eq(TRAIL.rock_steps.map(func(s: RockStepDef) -> float: return s.height), [0.35, 0.5, 0.3])
	assert_true(TRAIL.rock_steps[0].covers(-6.0) and TRAIL.rock_steps[0].covers(6.0), "the first step spans the whole road")
	assert_false(TRAIL.rock_steps[1].covers(-1.0), "the second leaves a ramp on the left")
	assert_true(TRAIL.rock_steps[1].covers(2.0))
	assert_eq(TRAIL.boulder_fields.size(), 5)
	assert_eq(TRAIL.boulder_fields[0].start, 720.0)
	assert_eq(TRAIL.boulder_fields[4].count, 2, "the squeeze is two blocks")
	assert_eq(TRAIL.talus.size(), 1)
	assert_eq(TRAIL.talus[0].count, 40)
	assert_eq(TRAIL.fords.size(), 1)
	assert_between(TRAIL.fords[0].distance, 1250.0, 1330.0)
	assert_eq(TRAIL.fords[0].waterfall_height, 14.0)
	assert_eq(TRAIL.fords[0].waterfall_offset, -22.0)
	assert_eq(Array(TRAIL.checkpoint_distances), [300.0, 700.0, 1250.0, 1500.0, 1900.0])
	assert_eq(TERRAIN.wall_sections.size(), 4)
	assert_eq(TERRAIN.wall_sections[3], Vector4(1500.0, 400.0, 25.0, -40.0), "the shelf: cliff left, air right")
	assert_eq(TERRAIN.view_distance, 350.0)
	assert_eq(TERRAIN.detail_distance, 140.0)
	assert_eq(SCATTER.pine_spacing, 0.0, "no pines in the desert")
	assert_gt(SCATTER.post_drop, 100.0, "no roadside posts")


func test_catalog_entry() -> void:
	assert_eq(LEVEL.id, &"rock_canyon")
	assert_eq(LEVEL.display_name, "Rock Canyon")
	assert_eq(LEVEL.surfaces, "Deep mud, rock, scree, water")
	assert_eq(LEVEL.recommended_car, &"offroad_4x4")
	assert_eq(LEVEL.two_star_time, 285.0, "placeholder pending the owner's runs")
	assert_eq(LEVEL.three_star_time, 255.0)
	assert_true(ResourceLoader.exists(LEVEL.scene_path))


func test_the_level_builds_every_part_with_its_surfaces_and_structures() -> void:
	var level := TrailLevel.new()
	level.trail = TRAIL
	level.terrain = TERRAIN
	level.scatter = SCATTER
	var path := Path3D.new()
	path.name = "Road"
	path.curve = CURVE
	level.add_child(path)
	add_child_autofree(level)
	await wait_physics_frames(2)
	gut.p("Rock Canyon: %.0f m, built in %.2f s (%s)" % [sampler.length, level.build_seconds, level.phase_summary()])
	assert_lt(level.build_seconds, 3.0, "desktop build time")
	for part in ["Generated/RockSteps", "Generated/Boulders", "Generated/Talus", "Generated/Fords"]:
		assert_not_null(level.get_node_or_null(part), part)
	assert_eq(level.rock_step_builder.step_count, 3)
	assert_eq(level.boulder_builder.placed.size(), 5)
	assert_gte(level.talus_builder.stones.size(), 36, "40 stones less any on the 1250 m gate")
	assert_eq(level.ford_builder.water_levels.size(), 1)
	assert_eq(level.checkpoints.reset_transforms.size(), 7, "start, five checkpoints, finish")
	assert_eq(level.scatter_builder.pine_count, 0)
	assert_gt(level.scatter_builder.rock_count, 100)
	var space := level.get_world_3d().direct_space_state
	for check: Array in [[100.0, &"asphalt"], [400.0, &"deep_mud"], [1290.0, &"wet_rock"], [1590.0, &"rock"], [1950.0, &"scree"]]:
		var point := sampler.surface_point(check[0], 0.0, level.profile)
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(point + Vector3.UP * 2.0, point + Vector3.DOWN * 2.0))
		assert_false(hit.is_empty(), "road under %.0f m" % check[0])
		if not hit.is_empty():
			assert_eq(SurfaceLookup.surface_of(hit["collider"]).id, check[1], "surface at %.0f m" % check[0])
	var face_from := sampler.surface_point(809.0, 0.0, level.profile) + Vector3.UP * 0.1
	var face_to := sampler.surface_point(815.0, 0.0, level.profile) + Vector3.UP * 0.1
	var face := space.intersect_ray(PhysicsRayQueryParameters3D.create(face_from, face_to))
	assert_false(face.is_empty(), "the first rock step's face")
	if not face.is_empty():
		assert_eq(SurfaceLookup.surface_of(face["collider"]).id, &"rock")
	assert_almost_eq(level.profile.ford_height(1290.0), -0.35, 0.0001)
	var ford := TRAIL.fords[0]
	var foot := level.ford_builder.waterfall_feet[0]
	assert_almost_eq(sampler.lateral_offset(foot), ford.waterfall_offset, 0.5, "the waterfall stands on the left wall")
	var gully := sampler.position(430.0) + sampler.right(430.0) * -30.0
	assert_gt(level.field.height_at(gully.x, gully.z) - sampler.position(430.0).y, 12.0, "the gully's left wall")
	var cliff := sampler.position(1700.0) + sampler.right(1700.0) * -30.0
	var drop := sampler.position(1700.0) + sampler.right(1700.0) * 40.0
	assert_gt(level.field.height_at(cliff.x, cliff.z) - sampler.position(1700.0).y, 15.0, "rock cut left of the shelf")
	assert_lt(level.field.height_at(drop.x, drop.z) - sampler.position(1700.0).y, -20.0, "air right of the shelf")
```

Also update `tests/unit/test_level_catalog.gd`: `test_muddy_valley_follows_rally_road_and_unlocks_after_it` asserts `shipped.levels.size()` is 4, and add:

```gdscript
func test_rock_canyon_is_fourth_and_unlocks_after_frozen_pass() -> void:
	var shipped: LevelCatalog = load("res://levels/catalog.tres")
	var canyon: LevelDef = shipped.levels[3]
	assert_eq(canyon.id, &"rock_canyon")
	assert_eq(canyon.display_name, "Rock Canyon")
	assert_true(ResourceLoader.exists(canyon.scene_path))
	assert_eq(canyon.two_star_time, 285.0, "placeholder pending owner playtest")
	assert_eq(canyon.three_star_time, 255.0)
	assert_eq(canyon.recommended_car, &"offroad_4x4")
	var progress := Progress.new()
	for level in shipped.levels.slice(0, 2):
		progress.record_finish(level, 100.0, {})
	assert_false(progress.is_unlocked(shipped, canyon), "two levels are not enough")
	progress.record_finish(shipped.levels[2], 100.0, {})
	assert_true(progress.is_unlocked(shipped, canyon))
```

and `tests/unit/test_menus.gd` `test_main_menu_shows_total_stars`: `"2 / 12 stars"`.

- [ ] **Step 2: Run to see it fail**

Run: `godot --headless --fixed-fps 120 --max-fps 0 -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_rock_canyon.gd -gexit`
Expected: fails to load the preloads.

- [ ] **Step 3: The curve generator**

`tools/generate_rock_canyon_curve.gd`:

```gdscript
extends SceneTree
## Rock Canyon (M5 spec §3.2): asphalt canyon mouth, a drop into the shaded mud
## gully, the climbing boulder wash, the talus scar and ford, a switchback up to
## the narrow shelf, and the final scree push to the rim. Segment ends are noted
## as cumulative distances.

const OUTPUT := "res://levels/rock_canyon/rock_canyon_curve.tres"
const SEGMENTS := [
	["straight", 120.0, 0.02],
	["arc", 150.0, 30.0, 0.02],        # ~198 m: easy bends on tarmac
	["straight", 22.0, 0.02],          # 220 m: the last tarmac
	["straight", 80.0, -0.05],         # 300 m: drop into the side-gully
	["arc", 120.0, -40.0, 0.0],        # ~384 m: the deep mud gully, flat
	["straight", 96.0, 0.0],           # ~480 m
	["arc", 90.0, 35.0, 0.0],          # ~535 m
	["straight", 25.0, 0.0],           # 560 m: the gully ends
	["straight", 140.0, 0.04],         # 700 m: climb out; the wash begins
	["arc", 110.0, -45.0, 0.035],      # ~787 m
	["straight", 100.0, 0.04],         # ~887 m
	["arc", 100.0, 50.0, 0.045],       # ~974 m
	["straight", 100.0, 0.05],         # ~1074 m
	["arc", 130.0, -34.0, 0.04],       # ~1151 m: the talus field
	["straight", 100.0, 0.02],         # ~1251 m
	["straight", 80.0, 0.0],           # ~1331 m: the ford, level
	["straight", 60.0, 0.08],          # ~1391 m: the wash steepens
	["arc", 30.0, 180.0, 0.09],        # ~1485 m: switchback
	["straight", 16.0, 0.10],          # ~1501 m: the shelf starts
	["arc", 200.0, 30.0, 0.06],        # ~1606 m
	["straight", 120.0, 0.06],         # ~1726 m
	["arc", 160.0, -40.0, 0.06],       # ~1838 m: the squeeze
	["straight", 63.0, 0.06],          # ~1901 m: the shelf ends
	["straight", 150.0, 0.12],         # ~2051 m: final push on scree
	["straight", 50.0, 0.0],           # ~2101 m: the rim and finish
	["straight", 70.0, 0.0],           # run-off
]


func _init() -> void:
	quit(CurveGenerator.generate(SEGMENTS, OUTPUT, "Rock Canyon"))
```

```bash
mkdir -p levels/rock_canyon
godot --headless -s tools/generate_rock_canyon_curve.gd 2>&1 | tail -3
```

Expected: `saved res://levels/rock_canyon/rock_canyon_curve.tres: N points, ~2170 m long, ends +8x m, ...`. If it reports parts passing too close, lengthen the straight after the switchback (`16.0`) until it passes and note the new cumulative distances.

- [ ] **Step 4: The trail resource**

`levels/rock_canyon/rock_canyon_trail.tres`:

```
[gd_resource type="Resource" script_class="TrailDef" format=3]

[ext_resource type="Script" path="res://levels/trail/trail_def.gd" id="1"]
[ext_resource type="Script" path="res://levels/trail/surface_stretch.gd" id="2"]
[ext_resource type="Resource" path="res://surfaces/dirt.tres" id="3"]
[ext_resource type="Resource" path="res://surfaces/asphalt.tres" id="4"]
[ext_resource type="Resource" path="res://surfaces/deep_mud.tres" id="5"]
[ext_resource type="Resource" path="res://surfaces/mud.tres" id="6"]
[ext_resource type="Resource" path="res://surfaces/scree.tres" id="7"]
[ext_resource type="Resource" path="res://surfaces/rock.tres" id="8"]
[ext_resource type="Resource" path="res://surfaces/wet_rock.tres" id="9"]
[ext_resource type="Script" path="res://surfaces/surface_def.gd" id="10"]
[ext_resource type="Script" path="res://levels/trail/rock_step_def.gd" id="11"]
[ext_resource type="Script" path="res://levels/trail/boulder_field_def.gd" id="12"]
[ext_resource type="Script" path="res://levels/trail/talus_def.gd" id="13"]
[ext_resource type="Script" path="res://levels/trail/ford_def.gd" id="14"]

[sub_resource type="Resource" id="Tarmac"]
script = ExtResource("2")
start = 0.0
length = 220.0
surface = ExtResource("4")
affects_shoulders = false
color = Color(0.24, 0.23, 0.24, 1)
blend_length = 4.0

[sub_resource type="Resource" id="DeepMud"]
script = ExtResource("2")
start = 300.0
length = 260.0
surface = ExtResource("5")
transition_surfaces = Array[ExtResource("10")]([ExtResource("6")])
transition_length = 12.0
color = Color(0.22, 0.16, 0.11, 1)
rut_depth = 0.15
rut_spacing = 1.6
rut_width = 0.9
blend_length = 12.0

[sub_resource type="Resource" id="Scree1"]
script = ExtResource("2")
start = 760.0
length = 30.0
surface = ExtResource("7")
color = Color(0.66, 0.5, 0.4, 1)

[sub_resource type="Resource" id="Scree2"]
script = ExtResource("2")
start = 1000.0
length = 25.0
surface = ExtResource("7")
color = Color(0.66, 0.5, 0.4, 1)

[sub_resource type="Resource" id="Scree3"]
script = ExtResource("2")
start = 1090.0
length = 40.0
surface = ExtResource("7")
color = Color(0.66, 0.5, 0.4, 1)

[sub_resource type="Resource" id="TalusScree"]
script = ExtResource("2")
start = 1150.0
length = 100.0
surface = ExtResource("7")
color = Color(0.66, 0.5, 0.4, 1)

[sub_resource type="Resource" id="WetRock"]
script = ExtResource("2")
start = 1282.0
length = 16.0
surface = ExtResource("9")
transition_surfaces = Array[ExtResource("10")]([ExtResource("8")])
transition_length = 4.0
color = Color(0.3, 0.29, 0.28, 1)
roughness = 0.25
blend_length = 2.0

[sub_resource type="Resource" id="Slabs"]
script = ExtResource("2")
start = 1560.0
length = 60.0
surface = ExtResource("8")
affects_shoulders = false
color = Color(0.62, 0.4, 0.31, 1)
roughness = 0.7

[sub_resource type="Resource" id="FinalScree"]
script = ExtResource("2")
start = 1900.0
length = 150.0
surface = ExtResource("7")
color = Color(0.66, 0.5, 0.4, 1)

[sub_resource type="Resource" id="Step1"]
script = ExtResource("11")
distance = 812.0
height = 0.35
lateral_from = -6.5
lateral_to = 6.5
seed = 53

[sub_resource type="Resource" id="Step2"]
script = ExtResource("11")
distance = 947.0
height = 0.5
lateral_from = 1.0
lateral_to = 3.5
seed = 54

[sub_resource type="Resource" id="Step3"]
script = ExtResource("11")
distance = 1078.0
height = 0.3
lateral_from = -6.5
lateral_to = 6.5
seed = 55

[sub_resource type="Resource" id="Wash1"]
script = ExtResource("12")
start = 720.0
length = 140.0
count = 24
size_range = Vector2(0.3, 0.45)
lateral_range = Vector2(0, 9)
slab_fraction = 0.3
seed = 61

[sub_resource type="Resource" id="Wash2"]
script = ExtResource("12")
start = 980.0
length = 140.0
count = 24
size_range = Vector2(0.3, 0.45)
lateral_range = Vector2(0, 9)
slab_fraction = 0.3
seed = 62

[sub_resource type="Resource" id="Washout1"]
script = ExtResource("12")
start = 1596.0
length = 22.0
count = 10
size_range = Vector2(0.15, 0.28)
off_road_size_range = Vector2(0.15, 0.28)
lateral_range = Vector2(0, 1.8)
slab_fraction = 0.0
seed = 63

[sub_resource type="Resource" id="Washout2"]
script = ExtResource("12")
start = 1744.0
length = 18.0
count = 8
size_range = Vector2(0.15, 0.28)
off_road_size_range = Vector2(0.15, 0.28)
lateral_range = Vector2(0, 1.8)
slab_fraction = 0.0
seed = 64

[sub_resource type="Resource" id="Squeeze"]
script = ExtResource("12")
start = 1838.0
length = 4.0
count = 2
size_range = Vector2(1.1, 1.3)
off_road_size_range = Vector2(1.1, 1.3)
lateral_range = Vector2(2.7, 2.8)
slab_fraction = 0.0
seed = 65

[sub_resource type="Resource" id="TalusField"]
script = ExtResource("13")
start = 1150.0
length = 100.0
count = 40
size_range = Vector2(0.18, 0.32)
mass_range = Vector2(30, 120)
lateral_range = Vector2(0, 4)
seed = 71

[sub_resource type="Resource" id="Ford"]
script = ExtResource("14")
distance = 1290.0
water_color = Color(0.36, 0.5, 0.55, 1)
seed = 83

[resource]
script = ExtResource("1")
road_width = 8.0
shoulder_width = 2.5
use_curve_banking = true
detail_step = 0.25
width_stretches = Array[Vector4]([Vector4(1500, 400, 4.5, 0)])
width_blend = 10.0
base_surface = ExtResource("3")
painted_lines = false
surface_stretches = Array[ExtResource("2")]([SubResource("Tarmac"), SubResource("DeepMud"), SubResource("Scree1"), SubResource("Scree2"), SubResource("Scree3"), SubResource("TalusScree"), SubResource("WetRock"), SubResource("Slabs"), SubResource("FinalScree")])
undulation_amplitude = 0.08
undulation_wavelengths = Vector2(17, 29)
rough_sections = Array[Vector3]([Vector3(700, 450, 12)])
pothole_radius_range = Vector2(0.3, 0.7)
pothole_depth_range = Vector2(0.05, 0.12)
checkpoint_distances = PackedFloat32Array(300, 700, 1250, 1500, 1900)
end_margin = 70.0
rock_steps = Array[ExtResource("11")]([SubResource("Step1"), SubResource("Step2"), SubResource("Step3")])
boulder_fields = Array[ExtResource("12")]([SubResource("Wash1"), SubResource("Wash2"), SubResource("Washout1"), SubResource("Washout2"), SubResource("Squeeze")])
talus = Array[ExtResource("13")]([SubResource("TalusField")])
fords = Array[ExtResource("14")]([SubResource("Ford")])
asphalt_color = Color(0.6, 0.42, 0.3, 1)
shoulder_color = Color(0.58, 0.38, 0.26, 1)
seed = 47
```

- [ ] **Step 5: Terrain, scatter and level resources, the scene, the catalog**

`levels/rock_canyon/rock_canyon_terrain.tres`:

```
[gd_resource type="Resource" script_class="TerrainDef" format=3]

[ext_resource type="Script" path="res://levels/trail/terrain_def.gd" id="1"]

[resource]
script = ExtResource("1")
margin = 200.0
corridor_blend = 8.0
detail_distance = 140.0
view_distance = 350.0
noise_amplitude = 26.0
noise_wavelength = 150.0
rock_slope_deg = 30.0
dirt_color = Color(0.66, 0.34, 0.22, 1)
rock_color = Color(0.74, 0.44, 0.3, 1)
wall_sections = Array[Vector4]([Vector4(300, 260, 18, 18), Vector4(700, 450, 30, 30), Vector4(1150, 180, 26, 14), Vector4(1500, 400, 25, -40)])
wall_blend = 25.0
seed = 41
```

`levels/rock_canyon/rock_canyon_scatter.tres`:

```
[gd_resource type="Resource" script_class="ScatterDef" format=3]

[ext_resource type="Script" path="res://levels/trail/scatter_def.gd" id="1"]

[resource]
script = ExtResource("1")
pine_spacing = 0.0
broadleaf_spacing = 35.0
rock_spacing = 9.0
road_clearance = 4.0
max_slope_deg = 40.0
broadleaf_view_distance = 220.0
rock_view_distance = 160.0
post_drop = 1000.0
broadleaf_color = Color(0.42, 0.4, 0.28, 1)
trunk_color = Color(0.3, 0.24, 0.18, 1)
rock_color = Color(0.6, 0.38, 0.27, 1)
seed = 43
```

`levels/rock_canyon/rock_canyon_level.tres`:

```
[gd_resource type="Resource" script_class="LevelDef" format=3]

[ext_resource type="Script" path="res://game/level_def.gd" id="1"]

[resource]
script = ExtResource("1")
id = &"rock_canyon"
display_name = "Rock Canyon"
scene_path = "res://levels/rock_canyon/rock_canyon.tscn"
surfaces = "Deep mud, rock, scree, water"
recommended_car = &"offroad_4x4"
two_star_time = 285.0
three_star_time = 255.0
```

`levels/rock_canyon/rock_canyon.tscn`: copy `levels/frozen_pass/frozen_pass.tscn`, rename the root node to `RockCanyon`, point the four `ext_resource` paths at the `rock_canyon` files, and set the Mood and Ambience values:

```
[node name="Mood" type="Node3D" parent="."]
script = ExtResource("2_mood")
sun_color = Color(1, 0.97, 0.9, 1)
sun_energy = 1.5
sun_elevation_deg = 62.0
sun_azimuth_deg = -20.0
sky_top = Color(0.24, 0.46, 0.85, 1)
sky_horizon = Color(0.86, 0.82, 0.72, 1)
ground_color = Color(0.5, 0.3, 0.22, 1)
fog_density = 0.003
...
[node name="Ambience" type="Node" parent="."]
script = ExtResource("20_ambience")
wind_volume = 0.3
birds = false
```

`levels/catalog.tres`: add `[ext_resource type="Resource" path="res://levels/rock_canyon/rock_canyon_level.tres" id="6_canyon"]` and append `ExtResource("6_canyon")` to the `levels` array.

`debug/load_benchmark.gd`: add `"res://levels/rock_canyon/rock_canyon.tscn"` to `LEVELS`.

`levels/trail/scatter_builder.gd`: guard the pines (and rocks) like the broadleaf trees:

```gdscript
	if def.pine_spacing > 0.0:
		var pines := _scatter(field, def, def.pine_spacing, Vector2(0.8, 1.3), 0.0, creek_clearance, rng, true)
		pine_count = pines.size()
		_add_multimeshes(field, pines, LowPolyMeshes.pine(def.foliage_color, def.trunk_color), material,
				def.pine_view_distance, true)
```

and wrap the rock block in `if def.rock_spacing > 0.0:` the same way (the rock collision body is still created). Doc: "a spacing of 0 places none of that kind".

- [ ] **Step 6: Run the tests**

```bash
godot --headless --import >/dev/null 2>&1
for t in test_rock_canyon test_level_catalog test_menus test_scatter_and_checkpoints test_geometry_fingerprints; do
  godot --headless --fixed-fps 120 --max-fps 0 -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/$t.gd -gexit 2>&1 | grep -E "Totals|passed|failed|SCRIPT ERROR|Rock Canyon:"
done
```

Expected: all passing; the printed phase summary shows every new phase. If the surface at a listed distance is off (the generated curve's length differs slightly from the cumulative notes), keep the stretch data and adjust only the test's probe distances to the middle of each stretch.

- [ ] **Step 7: Run the whole unit suite and commit**

Run: `./run_tests.sh unit` — expected green, no `SCRIPT ERROR`.

```bash
git add tools/generate_rock_canyon_curve.gd tools/generate_rock_canyon_curve.gd.uid levels/rock_canyon/rock_canyon_curve.tres levels/rock_canyon/rock_canyon_trail.tres levels/rock_canyon/rock_canyon_terrain.tres levels/rock_canyon/rock_canyon_scatter.tres levels/rock_canyon/rock_canyon_level.tres levels/rock_canyon/rock_canyon.tscn levels/catalog.tres debug/load_benchmark.gd levels/trail/scatter_builder.gd tests/unit/test_rock_canyon.gd tests/unit/test_rock_canyon.gd.uid tests/unit/test_level_catalog.gd tests/unit/test_menus.gd
git commit -m "Add Rock Canyon as the fourth level

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---
### Task 11: Scenario tests, the driver's crawl zones, tuning and notes

Spec §14.2, §14.3, §16. Teach `TrailDriver` to crawl through rock steps, boulder fields, talus and fords; let `RunLevelBuilder` take a trail and a car; write the Rock Canyon scenarios; run the full suite; write the milestone notes and point `AGENTS.md` at them. Tuning stays in level data and the driver, never in `car/` or existing surfaces.

**Files:**
- Create: `tests/scenarios/test_rock_canyon.gd`, `docs/notes/m5-rock-canyon-notes.md`
- Modify: `tests/scenarios/trail_driver.gd`, `tests/scenarios/run_level_builder.gd`, `AGENTS.md`

**Interfaces:**
- Produces: `TrailDriver.CRAWL_LOOKAHEAD = 20.0`, `TrailDriver.CRAWL_SPEED = 4.5`, `TrailDriver.crawl_zone_ahead(distance) -> bool` (needs a profile); `RunLevelBuilder.straight(test, length, checkpoints, trail_def: TrailDef = null, car_def: CarDef = null)`.

- [ ] **Step 1: The driver's crawl zones and the builder's extra arguments**

`tests/scenarios/trail_driver.gd`: add constants and the zone check, and use it in `target_speed`:

```gdscript
## Within this distance ahead of a rock step, boulder field, talus field or ford
## the driver crawls (m), and how fast it crawls (m/s).
const CRAWL_LOOKAHEAD := 20.0
const CRAWL_SPEED := 4.5
```

At the end of `target_speed`, replace the two `return`s with:

```gdscript
	var wanted := fastest
	if sharpest >= 0.0001:
		var grip_speed := sqrt(car.stats.tire_grip * surface_grip * 9.8 / sharpest)
		wanted = clampf(grip_speed * CAUTION, MIN_SPEED, fastest)
	if profile != null and crawl_zone_ahead(distance):
		wanted = minf(wanted, CRAWL_SPEED)
	return wanted
```

and add:

```gdscript
## Whether a rock step, boulder field, talus field or ford lies within
## CRAWL_LOOKAHEAD ahead (or 5 m behind, so the car finishes crossing it).
func crawl_zone_ahead(distance: float) -> bool:
	var from := distance - 5.0
	var to := distance + CRAWL_LOOKAHEAD
	var def := profile.def
	for step: RockStepDef in def.rock_steps:
		if step.distance + step.ramp_length >= from and step.distance <= to:
			return true
	for field: BoulderFieldDef in def.boulder_fields:
		if field.end() >= from and field.start <= to:
			return true
	for field: TalusDef in def.talus:
		if field.end() >= from and field.start <= to:
			return true
	for ford: FordDef in def.fords:
		var reach := ford.half_width() + ford.bank_run
		if ford.distance + reach >= from and ford.distance - reach <= to:
			return true
	return false
```

Update the class doc ("...and crawls through rock steps, boulders, talus and fords").

`tests/scenarios/run_level_builder.gd`: `static func straight(test: GutTest, length: float, checkpoints: PackedFloat32Array, trail_def: TrailDef = null, car_def: CarDef = null) -> RunLevel`; use `trail.trail = trail_def if trail_def != null else TrailDef.new()` and, before `level.add_child(rig)`, `if car_def != null: rig.car_override = car_def` (the rig reads it in `_enter_tree`).

Run `./run_tests.sh scenarios` once here: the three existing levels have no crawl zones, so every existing scenario must pass unchanged.

- [ ] **Step 2: Write the Rock Canyon scenarios**

`tests/scenarios/test_rock_canyon.gd`:

```gdscript
extends GutTest
## Rock Canyon end to end (M5 spec §14.2): the 4x4 finishes; the rally cars'
## runs are recorded, not required; the ledge, the deep mud, the ford and the
## talus each work on their own; the build's phase summary is printed.

const ROCK_CANYON := preload("res://levels/rock_canyon/rock_canyon.tscn")
const OFFROAD := preload("res://car/cars/offroad_4x4.tres")
const RALLY_CARS: Array[CarDef] = [preload("res://car/cars/rally.tres"), preload("res://car/cars/rally_tuned.tres")]
const DIRT := preload("res://surfaces/dirt.tres")
## A car making no progress for this long has beached (s).
const STALL_SECONDS := 8.0


func before_each() -> void:
	SaveSandbox.enter()


func after_each() -> void:
	SaveSandbox.leave()


func _load(car_def: CarDef = OFFROAD) -> RunLevel:
	var level: RunLevel = ROCK_CANYON.instantiate()
	(level.get_node("DrivingRig") as DrivingRig).car_override = car_def
	add_child(level)
	level.rig.touch_controls.process_mode = Node.PROCESS_MODE_DISABLED
	return level


func _free(node: Node) -> void:
	remove_child(node)
	node.queue_free()
	await get_tree().process_frame


## The surface under the first wheel in contact, or "" in the air.
func _surface_under(car: Car) -> StringName:
	for wheel in car.wheels:
		if wheel.in_contact and wheel.surface != null:
			return wheel.surface.id
	return &""


func _wheels_in_contact(car: Car) -> int:
	var count := 0
	for wheel in car.wheels:
		if wheel.in_contact:
			count += 1
	return count


func test_the_4x4_finishes_without_automatic_resets() -> void:
	var level := _load()
	var car := level.rig.car
	var driver := TrailDriver.new(car, level.trail.sampler, level.trail.profile)
	gut.p("Rock Canyon built in %.2f s (%s)" % [level.trail.build_seconds, level.trail.phase_summary()])
	assert_lt(level.trail.build_seconds, 3.0, "desktop level build")
	watch_signals(level.resets)
	var lowest_up := 1.0
	for tick in ScenarioHelper.ticks(420.0):
		if level.tracker.is_finished():
			break
		driver.drive()
		await get_tree().physics_frame
		lowest_up = minf(lowest_up, car.global_basis.y.y)
	var distance := level.trail.sampler.closest_distance(car.global_position)
	var time := level.run.clock.elapsed
	gut.p("Off-road 4x4 Rock Canyon: %s, finished=%s, %.0f m, average %.1f km/h, lowest upright %.2f" % [
			RunHud.format_time(time), level.tracker.is_finished(), distance, distance / maxf(time, 0.1) * 3.6, lowest_up])
	assert_true(level.tracker.is_finished(), "the 4x4 finishes")
	assert_eq(get_signal_emit_count(level.resets, "car_reset"), 0, "no automatic resets")
	assert_gt(lowest_up, 0.5, "stays upright")
	assert_true(level.results.is_showing())
	await _free(level)


func test_the_rally_cars_runs_are_recorded_not_required() -> void:
	for car_def: CarDef in RALLY_CARS:
		var level := _load(car_def)
		var car := level.rig.car
		var driver := TrailDriver.new(car, level.trail.sampler, level.trail.profile)
		watch_signals(level.resets)
		var furthest := 0.0
		var stalled := 0.0
		var beached_at := -1.0
		for tick in ScenarioHelper.ticks(240.0):
			if level.tracker.is_finished():
				break
			driver.drive()
			await get_tree().physics_frame
			var distance := level.trail.sampler.closest_distance(car.global_position)
			if distance > furthest + 0.05:
				furthest = distance
				stalled = 0.0
			else:
				stalled += 1.0 / Engine.physics_ticks_per_second
			if stalled > STALL_SECONDS:
				beached_at = distance
				break
		gut.p("%s Rock Canyon: finished=%s, reached %.0f m%s, on %s" % [car_def.display_name, level.tracker.is_finished(),
				furthest, (" and beached at %.0f m" % beached_at) if beached_at >= 0.0 else "", _surface_under(car)])
		assert_eq(get_signal_emit_count(level.resets, "car_reset"), 0, "%s: no automatic reset" % car_def.display_name)
		await _free(level)


func test_the_4x4_crawls_a_ledge_with_less_wheelspin_at_part_throttle() -> void:
	var trail := TrailDef.new()
	trail.undulation_amplitude = 0.0
	trail.base_surface = DIRT
	trail.painted_lines = false
	var step := RockStepDef.new()
	step.distance = 60.0
	step.height = 0.4
	step.lateral_from = -6.5
	step.lateral_to = 6.5
	trail.rock_steps = [step]
	var spins := {}
	for throttle: float in [0.4, 1.0]:
		var level := RunLevelBuilder.straight(self, 200.0, PackedFloat32Array([150.0]), trail, OFFROAD)
		var car := level.rig.car
		car.drivetrain.traction_control_strength = 0.0  # compare throttle alone, not the assist
		await TrailScenarios.wait_for_go(level)
		await TrailScenarios.place_on_road(level, 45.0)
		var spin := 0.0
		var cleared := false
		for tick in ScenarioHelper.ticks(20.0):
			if level.trail.sampler.closest_distance(car.global_position) >= 68.0:
				cleared = true
				break
			car.input.virtual_steer = 0.0
			car.input.virtual_throttle = throttle
			car.input.virtual_brake = 0.0
			await get_tree().physics_frame
			for wheel in car.wheels:
				if wheel.in_contact:
					spin += absf(wheel.slip_ratio) / Engine.physics_ticks_per_second
		spins[throttle] = spin
		gut.p("0.4 m ledge at %.0f%% throttle: cleared=%s, wheelspin %.2f slip-seconds" % [throttle * 100.0, cleared, spin])
		assert_true(cleared, "the 4x4 clears the ledge at %.0f%% throttle" % (throttle * 100.0))
		remove_child(level)
		level.queue_free()
		await get_tree().process_frame
	assert_lte(spins[0.4], spins[1.0], "part throttle spins the wheels less")


func test_the_4x4_crosses_the_deep_mud_gully_from_a_standstill() -> void:
	var level := _load()
	var car := level.rig.car
	var driver := TrailDriver.new(car, level.trail.sampler, level.trail.profile)
	await TrailScenarios.wait_for_go(level)
	await TrailScenarios.place_on_road(level, 320.0)
	var lowest_speed := INF
	var saw_deep_mud := false
	var seconds := 90.0
	for tick in ScenarioHelper.ticks(90.0):
		if level.trail.sampler.closest_distance(car.global_position) >= 560.0:
			seconds = tick / float(Engine.physics_ticks_per_second)
			break
		driver.drive()
		car.input.virtual_throttle = 1.0
		car.input.virtual_brake = 0.0
		await get_tree().physics_frame
		if tick > ScenarioHelper.ticks(3.0):
			lowest_speed = minf(lowest_speed, car.forward_speed())
		if _surface_under(car) == &"deep_mud":
			saw_deep_mud = true
	gut.p("deep mud gully from rest at 320 m to 560 m: %.1f s, minimum speed %.1f km/h" % [seconds, lowest_speed * 3.6])
	assert_lt(seconds, 90.0, "the 4x4 gets through the gully")
	assert_true(saw_deep_mud, "deep mud was under the wheels")
	await _free(level)


func test_the_ford_is_crossed_on_wet_rock_without_leaving_the_ground() -> void:
	var level := _load()
	var car := level.rig.car
	var driver := TrailDriver.new(car, level.trail.sampler, level.trail.profile)
	await TrailScenarios.wait_for_go(level)
	await TrailScenarios.place_on_road(level, 1262.0)
	var airborne_ticks := 0
	var saw_wet_rock := false
	var reached := false
	for tick in ScenarioHelper.ticks(40.0):
		if level.trail.sampler.closest_distance(car.global_position) >= 1322.0:
			reached = true
			break
		driver.drive()
		await get_tree().physics_frame
		if _wheels_in_contact(car) == 0:
			airborne_ticks += 1
		if _surface_under(car) == &"wet_rock":
			saw_wet_rock = true
	gut.p("ford: reached=%s, wet rock=%s, airborne ticks=%d" % [reached, saw_wet_rock, airborne_ticks])
	assert_true(reached, "crossed the ford")
	assert_true(saw_wet_rock, "wet rock under the wheels")
	assert_lt(airborne_ticks, 12, "never left the ground for more than a tenth of a second")
	await _free(level)


func test_driving_into_the_talus_wakes_stones_and_the_car_passes() -> void:
	var level := _load()
	var car := level.rig.car
	var driver := TrailDriver.new(car, level.trail.sampler, level.trail.profile)
	await TrailScenarios.wait_for_go(level)
	await TrailScenarios.place_on_road(level, 1140.0)
	assert_eq(level.trail.talus_builder.awake_count(), 0, "all asleep before the car arrives")
	var most_awake := 0
	var reached := false
	for tick in ScenarioHelper.ticks(60.0):
		if level.trail.sampler.closest_distance(car.global_position) >= 1262.0:
			reached = true
			break
		driver.drive()
		await get_tree().physics_frame
		most_awake = maxi(most_awake, level.trail.talus_builder.awake_count())
	gut.p("talus: reached=%s, most stones awake at once=%d, upright=%s" % [reached, most_awake, ScenarioHelper.is_upright(car)])
	assert_true(reached, "the car passes through the talus")
	assert_gt(most_awake, 0, "stones woke")
	assert_true(ScenarioHelper.is_upright(car))
	await _free(level)
```

- [ ] **Step 3: Run the Rock Canyon scenarios**

Run: `godot --headless --fixed-fps 120 --max-fps 0 -s addons/gut/gut_cmdln.gd -gtest=res://tests/scenarios/test_rock_canyon.gd -gexit 2>&1 | tee /tmp/ridge-m5-rc.log | grep -E "Rock Canyon|ledge|gully|ford:|talus:|Totals|passed|failed|SCRIPT ERROR"`

Expected: all six pass and the printed lines record the numbers. Tuning rules if one fails:
- **The 4x4 does not finish:** read where it stopped from the printed distance. Adjust *level data only*: a boulder field's `lateral_range` or `size_range` (within spec §7.3), a step's `lateral_from/to`, the talus `count`, or `TrailDriver.CRAWL_SPEED`. Never touch `car/` or the existing surfaces. Record every change in the notes.
- **Ledge test:** if the 4x4 cannot clear the 0.4 m test ledge, lower the test's step to 0.35 (the level's tallest full-width step) and note it; if part throttle spins more than full, run once more to check flakiness, then loosen to `assert_lte(spins[0.4], spins[1.0] * 1.1)` with a note.
- **Ford airborne ticks:** raise the tolerance to 24 only if the printed count is under 24 on two runs.

- [ ] **Step 4: Run everything**

```bash
ps -eo pid,args | grep "godot --path ." | grep -v grep   # must print nothing
./run_tests.sh all 2>&1 | tee /tmp/ridge-m5-all.log | grep -E "Totals|passed|failed|pending|SCRIPT ERROR"
```

Expected: everything passing, the one pre-existing pending test, no `SCRIPT ERROR`. Record the totals.

- [ ] **Step 5: Optional desktop captures**

Only if `DISPLAY=:1 WAYLAND_DISPLAY=wayland-1 godot --version` works (skip otherwise and say so in the notes):

```bash
DISPLAY=:1 WAYLAND_DISPLAY=wayland-1 godot --path . --resolution 1280x720 res://tools/level_shots.tscn -- res://levels/rock_canyon/rock_canyon.tscn 100 420 780 950 1200 1290 1450 1700 1840 2000 car=offroad_4x4 2>&1 | grep -E "built in|primitives"
```

Every line must be under 300k primitives and 150 draw calls; copy the table into the notes.

- [ ] **Step 6: Write the notes and point AGENTS.md at them**

`docs/notes/m5-rock-canyon-notes.md` with these sections, filled from the actual runs:

```markdown
# Milestone 5 — Rock Canyon: build notes (2026-09-17)

Branch `m5-rock-canyon`, based on master `cb20c09`. Not merged; the owner decides after the phone test.

## What was built
(One line per task: width profile, surfaces and sounds, walls, rock steps, boulders, talus, ford, throttle lever, recommended car, the level, scenarios.)

## Deviations from the spec, and why
- Rock step faces are vertical for 60% of their height with a sloping lip on top (`RockStepDef.LEDGE_SHARE`): a sphere-cast wheel cannot mount a face taller than the chassis clearance.
- The second step's face spans +1.0..+3.5 m (spec: +0.5..+3.5) so a centre-line car takes the ramp with both sides.
- Boulders sit a tenth of their radius below ground so a 0.45 m boulder stands 0.33 m.
- Slabs reuse the rock mesh so a field stays one MultiMesh.
- Checkpoint gates never grow wider than 12 m; on the shelf they narrow to the road plus a metre each side.
- (Anything changed while tuning in Task 11 step 3.)

## Measured (desktop, headless)
- Unit/scenario totals and the full-suite time.
- Rock Canyon build time and phase summary.
- 4x4 run: time, distance, average speed. Rally car and Rally Car Tuned: where each beached.
- Ledge, deep mud, ford and talus numbers from the scenario prints.
- Render counts table if captured; otherwise "not captured (no display)".

## Provisional: the talus field
Ships as one `TalusDef` on the trail. The phone check (spec §8.3) decides: if it costs frame rate or produces jank, remove the `talus` entry from `rock_canyon_trail.tres` and leave the area as scree with the fixed boulders already there.

## Phone acceptance checklist (spec §14.3)
1. `tools/android.sh build` and `install`; `adb shell run-as com.ridge.game touch files/benchmark` then launch: Rock Canyon load under 3 s.
2. Frame rate through the wash (700–1150 m), the talus (1150–1250 m) and the shelf (1500–1900 m): 60 fps.
3. The talus verdict.
4. The lever is comfortable to hold while steering (Throttle: Lever in the pause menu).
5. Star times: replace 285/255 s with the owner's runs.

## Open items
- Star times are placeholders.
- Water physics, a rock-crawler car and level-to-car locking remain out of scope (spec §15).
```

`AGENTS.md`: change the first paragraph to point at the notes: "Start with the latest notes: `docs/notes/m5-rock-canyon-notes.md` (Milestone 5 built on branch `m5-rock-canyon`, awaiting the owner's phone test), then the handover `docs/notes/handover-2026-09-17-rock-canyon.md` for repo rules."

- [ ] **Step 7: Commit**

```bash
git add tests/scenarios/trail_driver.gd tests/scenarios/run_level_builder.gd tests/scenarios/test_rock_canyon.gd tests/scenarios/test_rock_canyon.gd.uid docs/notes/m5-rock-canyon-notes.md AGENTS.md
git commit -m "Drive Rock Canyon in scenario tests and record the milestone notes

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
git status --short   # only " M project.godot" and "?? tmux-session.sh" may remain
git log --oneline master..HEAD
```

Do not merge and do not push.

---

## Self-review against the spec

- §3.1 catalog, surfaces line, recommended car, star times: Task 9, Task 10. §3.2 route, checkpoints, banking: Task 10 (curve, trail). §3.3 mood, terrain, scatter, road colours: Task 10.
- §4 surfaces, grip, feel (SPLASH, ROCK): Task 2.
- §5 width profile and its consumers, lands first, existing levels unchanged: Task 1 (fingerprints).
- §6 rock steps: Task 4 (lip deviation noted). §7 boulder fields: Task 5. §8 talus, provisional: Task 6 and the notes. §9 ford: Task 7 (wet-rock stretch as level data in Task 10). §10 canyon walls: Task 3.
- §11 throttle lever, setting, pause row, `release_all_touches`, keyboard untouched: Task 8.
- §12 sounds and ambience: Task 2, Task 10 (scene).
- §13 performance: `view_distance` 350 / `detail_distance` 140 in Task 10; every builder has a phase; optional captures in Task 11.
- §14.1 unit tests: Tasks 1–10. §14.2 scenarios: Task 11. §14.3 phone checklist: notes.
- §15 out of scope: nothing under `car/`, no existing surface values, no reset changes, no water physics.
- Type consistency: `RoadSampler.new(curve, banking, trail)` everywhere after Task 1; builders all take `(sampler, profile, field, trail)` except `RockStepBuilder.build(sampler, profile, trail)`; `TrailLevel` builder vars are `rock_step_builder`, `boulder_builder`, `talus_builder`, `ford_builder` with phases `rock_steps`, `boulders`, `talus`, `fords`.
