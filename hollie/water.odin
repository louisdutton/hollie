package hollie

import "core:math"
import "graphics"
import "tilemap"

WATER_SURFACE :: f32(-1.5)
WATER_BED :: f32(-32)
WATER_DRAFT :: f32(8)
WATER_FRICTION_SCALE :: f32(0.4)

water_tile :: proc(x, y: int) -> bool {
	tile := tilemap.get_base_tile(x, y)
	return tile != nil && tile^ == .Water
}

water_bed_height :: proc(position: Vec2) -> f32 {
	return water_at(position) ? WATER_BED : 0
}

water_apply_buoyancy :: proc(body: ^Transform, collider: Collider, dt: f32) {
	bottom := body.height + collider.offset.y
	submerged := clamp(WATER_SURFACE - bottom, 0, collider.size.y)
	if submerged <= 0 || bottom >= WATER_SURFACE || bottom + collider.size.y <= WATER_BED do return
	body.swimming = true
	// Displaced volume supplies lift; partial immersion also damps vertical motion.
	draft := max(min(WATER_DRAFT, collider.size.y * 0.55), 0.1)
	lift := PHYSICS_GRAVITY * submerged / draft
	drag := f32(10) * min(submerged / draft, 1)
	body.vertical_velocity = (body.vertical_velocity + lift * dt) / (1 + drag * dt)
}

water_movement_profile :: proc(
	profile: Movement_Profile,
	in_water: bool,
	turtle: bool = false,
) -> Movement_Profile {
	result := profile
	if in_water && !turtle do result.max_speed = min(result.max_speed, 60)
	if !in_water && turtle do result.max_speed = min(result.max_speed, 50)
	result.min_speed = min(result.min_speed, result.max_speed)
	return result
}

water_at :: proc(position: Vec2) -> bool {
	if len(shoreline.field.values) > 0 do return shoreline_field_at(&shoreline.field, position) > 0
	size := f32(tilemap.get_tile_size())
	return water_tile(int(math.floor(position.x / size)), int(math.floor(position.y / size)))
}


water_time: f32

rendering_draw_water :: proc() {
	if len(shoreline.meshes) == 0 || water_shore.texture.id == 0 do return
	size := f32(tilemap.get_tile_size())
	shader := rendering_state.water_shader
	if !graphics.shader_is_loaded(shader) do return
	graphics.set_shader_float(shader, rendering_state.water_time_location, &water_time)
	graphics.set_shader_float(shader, graphics.get_shader_location(shader, "tile_size"), &size)
	water_bind_shore(shader)
	water_bind_interactions(shader)
	view := rendering_camera()
	rendering_set_shader_vec3(shader, "view_direction", view.position - view.target)
	shoreline_draw(.Water, shader)
}
