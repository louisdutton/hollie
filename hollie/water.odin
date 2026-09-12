package hollie

import "core:math"
import "graphics"
import "tilemap"

WATER_SURFACE :: f32(-1.5)
WATER_BED :: f32(-32)
WATER_FLOAT_HEIGHT :: WATER_SURFACE - 8

water_tile :: proc(x, y: int) -> bool {
	tile := tilemap.get_base_tile(x, y)
	return tile != nil && tile^ == .Water
}

water_bed_height :: proc(position: Vec2) -> f32 {
	return water_at(position) ? WATER_BED : 0
}

water_floor_height :: proc(position: Vec2) -> f32 {
	return water_at(position) ? WATER_FLOAT_HEIGHT : 0
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
	size := f32(tilemap.get_tile_size())
	return water_tile(int(math.floor(position.x / size)), int(math.floor(position.y / size)))
}


water_time: f32

rendering_water_quad :: proc(a, b, c, d: Vec3, color: graphics.Colour) {
	graphics.draw_triangle_3d(a, b, c, color)
	graphics.draw_triangle_3d(a, c, d, color)
}

rendering_draw_water_banks :: proc(x, y: int, bed: f32) {
	size := f32(tilemap.get_tile_size())
	directions := [4]Vec2{{-1, 0}, {1, 0}, {0, -1}, {0, 1}}
	bounds := graphics.get_model_bounding_box(model_assets.cube)
	for direction in directions {
		neighbor := Vec2{(f32(x) + 0.5 + direction.x) * size, (f32(y) + 0.5 + direction.y) * size}
		top := water_bed_height(neighbor)
		if top <= bed do continue
		position := Vec3 {
			(f32(x) + 0.5 + direction.x * 0.5) * size,
			(bed + top) * 0.5,
			(f32(y) + 0.5 + direction.y * 0.5) * size,
		}
		dimensions := direction.x != 0 ? Vec3{0.3, top - bed, size} : Vec3{size, top - bed, 0.3}
		scale := dimensions / (bounds.max - bounds.min)
		graphics.draw_model(
			model_assets.cube,
			position - (bounds.min + bounds.max) * 0.5 * scale,
			{0, 1, 0},
			0,
			scale,
			{130, 116, 83, 255},
		)
	}
}

rendering_draw_water :: proc() {
	size := f32(tilemap.get_tile_size())
	for y in 0 ..< tilemap.get_tilemap_height() {
		for x in 0 ..< tilemap.get_tilemap_width() {
			if !water_tile(x, y) do continue
			left, right := f32(x) * size, f32(x + 1) * size
			top, bottom := f32(y) * size, f32(y + 1) * size
			color := graphics.Colour{55, 163, 180, 150}
			rendering_water_quad(
				{left, WATER_SURFACE, top},
				{left, WATER_SURFACE, bottom},
				{right, WATER_SURFACE, bottom},
				{right, WATER_SURFACE, top},
				color,
			)
			// Close the outer faces of the water volume; adjacent water cells
			// share a surface and have no internal transparent walls.
			bed := WATER_BED
			if !water_tile(x - 1, y) do rendering_water_quad({left, bed, top}, {left, bed, bottom}, {left, WATER_SURFACE, bottom}, {left, WATER_SURFACE, top}, color)
			if !water_tile(x + 1, y) do rendering_water_quad({right, bed, bottom}, {right, bed, top}, {right, WATER_SURFACE, top}, {right, WATER_SURFACE, bottom}, color)
			if !water_tile(x, y - 1) do rendering_water_quad({right, bed, top}, {left, bed, top}, {left, WATER_SURFACE, top}, {right, WATER_SURFACE, top}, color)
			if !water_tile(x, y + 1) do rendering_water_quad({left, bed, bottom}, {right, bed, bottom}, {right, WATER_SURFACE, bottom}, {left, WATER_SURFACE, bottom}, color)
			if (x + y) % 3 == 0 {
				wave := math.sin(water_time * 1.5 + f32(x + y))
				graphics.draw_cube(
					{(f32(x) + 0.5) * size + wave * 2, WATER_SURFACE + 0.1, (f32(y) + 0.5) * size},
					{5 + wave, 0.08, 0.4},
					{116, 203, 211, 200},
				)
			}
			// Thin pale edges mark the shore without obscuring the water.
			if !water_tile(x, y - 1) do graphics.draw_cube({(f32(x) + 0.5) * size, WATER_SURFACE + 0.08, f32(y) * size + 0.5}, {size, 0.08, 1}, {180, 217, 196, 255})
			if !water_tile(x, y + 1) do graphics.draw_cube({(f32(x) + 0.5) * size, WATER_SURFACE + 0.08, f32(y + 1) * size - 0.5}, {size, 0.08, 1}, {180, 217, 196, 255})
			if !water_tile(x - 1, y) do graphics.draw_cube({f32(x) * size + 0.5, WATER_SURFACE + 0.08, (f32(y) + 0.5) * size}, {1, 0.08, size}, {180, 217, 196, 255})
			if !water_tile(x + 1, y) do graphics.draw_cube({f32(x + 1) * size - 0.5, WATER_SURFACE + 0.08, (f32(y) + 0.5) * size}, {1, 0.08, size}, {180, 217, 196, 255})
		}
	}
}
