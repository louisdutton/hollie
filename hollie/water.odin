package hollie

import "core:math"
import "graphics"
import "tilemap"

water_tile :: proc(x, y: int) -> bool {
	tile := tilemap.get_base_tile(x, y)
	return tile != nil && tile^ == .Water
}

water_at :: proc(position: Vec2) -> bool {
	size := f32(tilemap.get_tile_size())
	return water_tile(int(math.floor(position.x / size)), int(math.floor(position.y / size)))
}

water_add_obstacles :: proc(entity: ^Entity, obstacles: ^[dynamic]AABB) {
	if entity == nil do return
	if player, ok := entity^.(Player); ok && player.dismount_air_control do return
	aquatic := false
	if animal, ok := entity^.(Enemy); ok do aquatic = animal.kind == .Turtle
	size := f32(tilemap.get_tile_size())
	for y in 0 ..< tilemap.get_tilemap_height() {
		for x in 0 ..< tilemap.get_tilemap_width() {
			water := water_tile(x, y)
			blocked := water && !aquatic
			if aquatic && !water {
				blocked =
					water_tile(x - 1, y) ||
					water_tile(x + 1, y) ||
					water_tile(x, y - 1) ||
					water_tile(x, y + 1)
			}
			if !blocked do continue
			append(
				obstacles,
				AABB {
					min = {f32(x) * size, -100, f32(y) * size},
					max = {f32(x + 1) * size, 1000, f32(y + 1) * size},
				},
			)
		}
	}
}

water_time: f32

rendering_draw_water :: proc() {
	size := f32(tilemap.get_tile_size())
	for y in 0 ..< tilemap.get_tilemap_height() {
		for x in 0 ..< tilemap.get_tilemap_width() {
			if !water_tile(x, y) do continue
			if (x + y) % 3 == 0 {
				wave := math.sin(water_time * 1.5 + f32(x + y))
				graphics.draw_cube(
					{(f32(x) + 0.5) * size + wave * 2, 0.15, (f32(y) + 0.5) * size},
					{5 + wave, 0.08, 0.4},
					{116, 203, 211, 200},
				)
			}
			// Thin pale edges mark the shore without obscuring the water.
			if !water_tile(x, y - 1) do graphics.draw_cube({(f32(x) + 0.5) * size, 0.12, f32(y) * size + 0.5}, {size, 0.08, 1}, {180, 217, 196, 255})
			if !water_tile(x, y + 1) do graphics.draw_cube({(f32(x) + 0.5) * size, 0.12, f32(y + 1) * size - 0.5}, {size, 0.08, 1}, {180, 217, 196, 255})
			if !water_tile(x - 1, y) do graphics.draw_cube({f32(x) * size + 0.5, 0.12, (f32(y) + 0.5) * size}, {1, 0.08, size}, {180, 217, 196, 255})
			if !water_tile(x + 1, y) do graphics.draw_cube({f32(x + 1) * size - 0.5, 0.12, (f32(y) + 0.5) * size}, {1, 0.08, size}, {180, 217, 196, 255})
		}
	}
}
