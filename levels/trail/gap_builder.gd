class_name GapBuilder
extends Node3D
## Closes the raised takeoff/landing sides and the faces exposed by the ravine.
## These meshes only support visible land; nothing bridges the missing span.

const ROCK := preload("res://surfaces/rock.tres")


func build(sampler: RoadSampler, profile: RoadProfile, field: TerrainField, trail: TrailDef) -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	if trail.road_gaps.is_empty():
		return
	var rows := RoadBuilder.row_distances(sampler.length, profile, trail)
	var joins := RoadBlendBuilder.new()
	joins._appearance_field = field
	for gap: RoadGapDef in trail.road_gaps:
		var faces := StructureMesh.new()
		var floor_y := gap.floor_height(sampler, profile) - 0.1
		for at: float in [gap.takeoff_end, gap.landing_start]:
			var width := sampler.half_width_at(at)
			var count := ceili(width * 2.0 / trail.lateral_step)
			for i in count:
				var a := sampler.surface_point(at, lerpf(-width, width, float(i) / count), profile)
				var b := sampler.surface_point(at, lerpf(-width, width, float(i + 1) / count), profile)
				_wall(faces, a, b, floor_y, gap.face_color)
			if trail.terrain_blend_width > 0.0:
				for side: float in [-1.0, 1.0]:
					var ring: Dictionary = joins._ring(sampler, profile, field, trail, at, side)
					var vertices: PackedVector3Array = ring["vertices"]
					for i in vertices.size() - 1:
						_wall(faces, vertices[i], vertices[i + 1], floor_y, gap.face_color)
		for i in rows.size() - 1:
			var a := rows[i]
			var b := rows[i + 1]
			if a < gap.takeoff_start or b > gap.recovery_end or gap.contains((a + b) * 0.5):
				continue
			for side: float in [-1.0, 1.0]:
				var p := sampler.surface_point(a, side * sampler.half_width_at(a), profile)
				var q := sampler.surface_point(b, side * sampler.half_width_at(b), profile)
				var bottom_p := Vector3(p.x, minf(p.y - 0.1, field.height_at(p.x, p.z) - 0.1), p.z)
				var bottom_q := Vector3(q.x, minf(q.y - 0.1, field.height_at(q.x, q.z) - 0.1), q.z)
				faces.quad(p, q, bottom_q, bottom_p, gap.face_color)
		faces.add_to(self, "GapFaces%d" % roundi(gap.takeoff_end), ROCK)
	joins.free()


static func _wall(mesh: StructureMesh, a: Vector3, b: Vector3, floor_y: float, color: Color) -> void:
	mesh.quad(a, b, Vector3(b.x, floor_y, b.z), Vector3(a.x, floor_y, a.z), color)
