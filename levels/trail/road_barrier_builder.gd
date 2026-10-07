class_name RoadBarrierBuilder
extends Node3D
## One visual mesh and matching static triangle collider per short span.
## No individual stone bodies, hidden continuous collision or inward rail ends.

const ROCK := preload("res://surfaces/rock.tres")


func build(sampler: RoadSampler, profile: RoadProfile, trail: TrailDef) -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	for span: RoadBarrierDef in trail.barriers:
		assert(span.validation_error(trail, sampler.length).is_empty(), span.validation_error(trail, sampler.length))
		var mesh := StructureMesh.new()
		var count := ceili(span.length / 2.0)
		for i in count:
			var a := lerpf(span.start, span.end(), float(i) / count)
			var b := lerpf(span.start, span.end(), float(i + 1) / count)
			var p := sampler.surface_point(a, span.lateral(trail, a), profile)
			var q := sampler.surface_point(b, span.lateral(trail, b), profile)
			var ah := span.height * lerpf(0.35, 1.0, span.end_weight(a))
			var bh := span.height * lerpf(0.35, 1.0, span.end_weight(b))
			var stone := span.kind == RoadBarrierDef.Kind.STONE
			var ab := -0.35 if stone else ah - 0.25
			var bb := -0.35 if stone else bh - 0.25
			var r := sampler.right(a) * span.width * 0.5
			var s := sampler.right(b) * span.width * 0.5
			var shade := 0.95 if stone and i % 2 == 0 else 1.0
			var color := span.color * Color(shade, shade, shade, 1)
			mesh.quad(p-r+Vector3.UP*ab, q-s+Vector3.UP*bb, q-s+Vector3.UP*bh, p-r+Vector3.UP*ah, color)
			mesh.quad(p+r+Vector3.UP*ab, q+s+Vector3.UP*bb, q+s+Vector3.UP*bh, p+r+Vector3.UP*ah, color)
			mesh.quad(p-r+Vector3.UP*ah, q-s+Vector3.UP*bh, q+s+Vector3.UP*bh, p+r+Vector3.UP*ah, color.lightened(0.1))
			mesh.quad(p-r+Vector3.UP*ab, q-s+Vector3.UP*bb, q+s+Vector3.UP*bb, p+r+Vector3.UP*ab, color)
			if i == 0:
				mesh.quad(p-r+Vector3.UP*ab, p+r+Vector3.UP*ab, p+r+Vector3.UP*ah, p-r+Vector3.UP*ah, color)
			if i == count - 1:
				mesh.quad(q-s+Vector3.UP*bb, q+s+Vector3.UP*bb, q+s+Vector3.UP*bh, q-s+Vector3.UP*bh, color)
			if not stone and i % 2 == 0:
				mesh.box(Transform3D(Basis.IDENTITY, p + Vector3.UP * (ah * 0.5 - 0.1)),
					Vector3(0.12, ah + 0.2, 0.12), color.darkened(0.2))
		var node := mesh.add_to(self, "Barrier%d" % roundi(span.start), ROCK, false)
		node.visibility_range_end = 240.0
