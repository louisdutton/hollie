package hollie

import "core:math"
import "graphics"
import "tilemap"

// Keep this first art study isolated from the existing rooms.
grass_is_enabled :: proc() -> bool {
	return gameplay_get_current_room() == "demo"
}

grass_tile :: proc(x, y: int) -> bool {
	tile := tilemap.get_base_tile(x, y)
	if tile == nil do return false
	#partial switch tile^ {
	case .Grass_1, .Grass_2, .Grass_3, .Grass_4, .Grass_5, .Grass_6, .Grass_7, .Grass_8:
		return true
	case: return false
	}
}

// Stable placement: editing or revisiting a room never reshuffles the meadow.
grass_random :: proc(seed: int) -> f32 {
	value := math.sin(f32(seed) * 12.9898) * 43758.5453
	return value - math.floor(value)
}

rendering_draw_grass :: proc() {
	if !grass_is_enabled() do return
	shader := rendering_state.grass_shader
	if !graphics.shader_is_loaded(shader) || rendering_state.grass_time_location < 0 do return
	graphics.set_shader_float(shader, rendering_state.grass_time_location, &water_time)
	graphics.begin_shader(shader)
	defer graphics.end_shader()

	size := f32(tilemap.get_tile_size())
	for y in 0 ..< tilemap.get_tilemap_height() {
		for x in 0 ..< tilemap.get_tilemap_width() {
			if !grass_tile(x, y) do continue
			left, top := f32(x) * size, f32(y) * size
			// Alpha encodes blade height; zero marks the continuous ground wash.
			a, b := Vec3{left, 0.03, top}, Vec3{left, 0.03, top + size}
			c, d := Vec3{left + size, 0.03, top + size}, Vec3{left + size, 0.03, top}
			ground := graphics.Colour{255, 255, 255, 0}
			graphics.draw_triangle_3d(a, b, c, ground)
			graphics.draw_triangle_3d(a, c, d, ground)
			// Leave most of the painted surface uninterrupted. Occasional
			// three-leaf tufts suggest grass without covering it in detail.
			patch_seed := (y * tilemap.get_tilemap_width() + x) * 251
			if grass_random(patch_seed + 5) > 0.38 do continue
			cluster := Vec3 {
				left + (0.25 + grass_random(patch_seed) * 0.5) * size,
				0.04,
				top + (0.25 + grass_random(patch_seed + 1) * 0.5) * size,
			}
			for blade in 0 ..< 3 {
				seed := patch_seed + blade * 7
				root := Vec3 {
					cluster.x + (f32(blade) - 1) * 1.3,
					cluster.y,
					cluster.z - (f32(blade) - 1) * 0.8,
				}
				height := 2.6 + grass_random(seed + 2) * 1.8
				// Present the broad face to the isometric camera.
				angle := -math.PI / 4 + (grass_random(seed + 3) - 0.5) * 1.1
				width :=
					Vec3{math.cos(angle), 0, math.sin(angle)} *
					(1.25 + grass_random(seed + 4) * 0.55)
				// Carry the leaf's width almost to the top, then close with a
				// short, gently leaning cap instead of a long needle-like taper.
				shoulder := root + Vec3{0.45, height * 0.82, 0.2}
				tip := root + Vec3{0.85, height, 0.35}
				color := graphics.Colour{255, 255, 255, u8(height / 8 * 255)}
				// Both windings keep these opaque ribbons visible from either side.
				for side in 0 ..< 2 {
					w := side == 0 ? width : -width
					graphics.draw_triangle_3d(root - w, root + w, shoulder + w * 0.7, color)
					graphics.draw_triangle_3d(
						root - w,
						shoulder + w * 0.7,
						shoulder - w * 0.7,
						color,
					)
					graphics.draw_triangle_3d(shoulder - w * 0.7, shoulder + w * 0.7, tip, color)
				}
			}
		}
	}
}
