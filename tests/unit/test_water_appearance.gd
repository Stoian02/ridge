extends GutTest


func test_shared_material_contract_keeps_vertex_fades_and_uses_alpha_transparency() -> void:
	var color := Color(0.30, 0.40, 0.42, 0.55)
	var material := WaterAppearance.make_material(color, true, true)
	assert_eq(material.albedo_color, color)
	assert_true(material.vertex_color_use_as_albedo)
	assert_true(material.uv1_triplanar)
	assert_true(material.uv1_world_triplanar)
	assert_eq(material.transparency, BaseMaterial3D.TRANSPARENCY_ALPHA)
	assert_eq(material.cull_mode, BaseMaterial3D.CULL_DISABLED)
	assert_almost_eq(material.roughness, 0.18, 0.000001)
	assert_almost_eq(material.metallic, 0.0, 0.000001)
	assert_almost_eq(material.metallic_specular, 0.65, 0.000001)
	assert_not_null(material.albedo_texture)


func test_pool_palette_deep_opacity_and_short_shore_fade() -> void:
	assert_eq(WaterAppearance.pool_color(-1.0).a, 0.0)
	assert_eq(WaterAppearance.pool_color(0.0).a, 0.0)
	assert_almost_eq(WaterAppearance.pool_color(0.025).a, 0.15, 0.000001)
	assert_eq(WaterAppearance.pool_color(0.05), WaterAppearance.SHALLOW)
	assert_eq(WaterAppearance.pool_color(0.2), WaterAppearance.SHALLOW)
	assert_eq(WaterAppearance.pool_color(2.0), WaterAppearance.DEEP)
	assert_eq(WaterAppearance.pool_color(2.8), WaterAppearance.DEEP)
	var previous := 0.0
	for index: int in 281:
		var color := WaterAppearance.pool_color(index * 0.01)
		assert_gte(color.a, previous)
		assert_lte(color.a, WaterAppearance.DEEP.a)
		previous = color.a


func test_animation_tracks_current_and_still_water_without_moving_geometry() -> void:
	var still := WaterAppearance.make_material(Color.WHITE)
	var moving := WaterAppearance.make_material(Color.WHITE)
	WaterAppearance.advance(still, Vector3.ZERO, 1.0)
	WaterAppearance.advance(moving, Vector3(0.75, 0.0, 0.0), 1.0)
	assert_ne(still.uv1_offset, Vector3.ZERO)
	assert_almost_eq(moving.uv1_offset.x, 0.8125, 0.000001)
	assert_eq(moving.uv1_offset.y, 0.0)
	var triplanar := WaterAppearance.make_material(Color.WHITE, false, true)
	WaterAppearance.advance(triplanar, Vector3(0.0, 0.0, 0.5), 1.0)
	assert_almost_eq(triplanar.uv1_offset.z, 0.875, 0.000001)
	assert_eq(triplanar.uv1_offset.y, 0.0)
	var saved := still.uv1_offset
	WaterAppearance.advance(still, Vector3.ZERO, 0.0)
	assert_eq(still.uv1_offset, saved)
