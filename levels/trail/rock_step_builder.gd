class_name RockStepBuilder
extends Node3D
## The rock faces of a trail's steps (M5 spec §6.3): for each RockStepDef a
## near-vertical face across its span, its top edge seeded-rough (leaning back up
## the road, never down it, so it stays in front of the road mesh's own step
## quad), with a lip on top sloping up to the raised road, and outward-facing end
## caps where the face covers only part of the road.
## Every step is merged into one mesh (one draw call) with concave collision tagged rock.

const ROCK := preload("res://surfaces/rock.tres")
## Spacing of the face's vertical strips across the road (m).
const LATERAL_STEP := 0.5
## The face's bottom is buried this far below the lower road, so no seam shows (m).
const BURY := 0.15
## The lip is drawn this far above the road it covers, so its rock colour shows (m).
const LIP_LIFT := 0.01
## The face's top edge is pulled back up the road by up to this much, per strip,
## so the rock reads as broken rather than sawn (m).
const JITTER := 0.05

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
		# Never positive: the road mesh has its own near-vertical quad over
		# RoadProfile.FACE_ROW_GAP, so a top pushed down the road would hide behind
		# it. Pulling it back toward the approaching car keeps the rock in front.
		var jitter: float = rng.randf_range(-JITTER, 0.0) if i > 0 and i < count else 0.0
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
		mesh.triangle(bottoms[0], lips[0], tops[0], step.color.darkened(0.1))
	if step.lateral_to < half - 0.01:
		mesh.triangle(bottoms[count], tops[count], lips[count], step.color.darkened(0.1))
