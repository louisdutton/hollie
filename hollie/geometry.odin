package hollie

import "core:math"
import "renderer"
import rl "vendor:raylib"

// Check collision between two rectangles
rects_intersect :: proc(a, b: renderer.Rect) -> bool {
	return(
		a.x < b.x + b.width &&
		a.x + a.width > b.x &&
		a.y < b.y + b.height &&
		a.y + a.height > b.y \
	)
}

// TODO: this shouldnt be here
// this is for accurate distance and shouldn't be used in performance-critical contexts
get_distance :: proc(a, b: Vec2) -> f32 {
	return math.sqrt((a.x - b.x) * (a.x - b.x) + (a.y - b.y) * (a.y - b.y))
}

geometry_position :: proc(position: Vec2, height: f32 = 0) -> rl.Vector3 {
	return {position.x, height, position.y}
}

geometry_collider_from_bounds :: proc(
	bounds: rl.BoundingBox,
	scale: f32,
	rotation_invariant: bool,
	solid: bool,
) -> Collider {
	min_x := bounds.min.x * scale
	max_x := bounds.max.x * scale
	min_z := bounds.min.z * scale
	max_z := bounds.max.z * scale
	if rotation_invariant {
		radius := max(max(abs(min_x), abs(max_x)), max(abs(min_z), abs(max_z)))
		min_x, max_x = -radius, radius
		min_z, max_z = -radius, radius
	}
	return {
		size = {max_x - min_x, max_z - min_z},
		offset = {min_x, min_z},
		height = (bounds.max.y - bounds.min.y) * scale,
		vertical_offset = bounds.min.y * scale,
		solid = solid,
	}
}

model_character_collider :: proc(solid: bool) -> Collider {
	return geometry_collider_from_bounds(
		model_assets.character_bounds,
		MODEL_CHARACTER_SCALE,
		true,
		solid,
	)
}

model_crate_collider :: proc(solid: bool) -> Collider {
	return geometry_collider_from_bounds(
		model_assets.crate_bounds,
		MODEL_CRATE_SCALE,
		false,
		solid,
	)
}

model_pressure_pad_collider :: proc(solid: bool) -> Collider {
	return geometry_collider_from_bounds(
		model_assets.pressure_pad_bounds,
		MODEL_PRESSURE_PAD_SCALE,
		false,
		solid,
	)
}

geometry_grounded_position :: proc(
	position: Vec2,
	bounds: rl.BoundingBox,
	scale: f32,
	base_height: f32 = 0,
) -> rl.Vector3 {
	return geometry_position(position, base_height - bounds.min.y * scale)
}
