extends GutTest
## Cheap, static, depth-tested presentation; no old scenery defaults change.


func test_rainbow_is_one_small_soft_depth_tested_static_mesh() -> void:
	assert_false(ScatterDef.new().coastal)
	var rainbow := CoastalRainbow.new()
	add_child_autofree(rainbow)
	assert_eq(rainbow.mesh.get_surface_count(), 1)
	assert_eq(rainbow.mesh.get_faces().size() / 3, 1536)
	assert_eq(rainbow.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
	assert_eq(rainbow.get_child_count(), 0, "no collision/light nodes")
	var shader: Shader = (rainbow.material_override as ShaderMaterial).shader
	assert_false(shader.code.contains("depth_test_disabled"))
	assert_true(shader.code.contains("depth_draw_never"))
	var colors: PackedColorArray = rainbow.mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
	var maximum := 0.0
	for color: Color in colors:
		maximum = maxf(maximum, color.a)
	assert_almost_eq(maximum, rainbow.opacity, 0.004, "compressed vertex alpha")
	assert_eq(colors[0].a, 0.0)
	assert_eq(colors[-1].a, 0.0)
