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

grass_upload_players :: proc(shader: graphics.Shader) {
	// Always upload both slots so leaving a room or removing player two
	// cannot leave an invisible influence behind.
	players: [2][4]f32
	count := 0
	for &entity in entities {
		player, ok := &entity.(Player)
		if !ok do continue
		if count >= len(players) do break
		bottom := player.height + player.collider.offset.y
		players[count] = {
			player.position.x + player.collider.offset.x + player.collider.size.x * 0.5,
			player.position.y + player.collider.offset.z + player.collider.size.z * 0.5,
			max(player.collider.size.x, player.collider.size.z) * 0.5 + 7,
			clamp(1 - max(bottom, 0) / 8, 0, 1),
		}
		count += 1
	}
	graphics.set_shader_vec4_array(
		shader,
		graphics.get_shader_location(shader, "grass_players[0]"),
		players[:],
	)
}

rendering_draw_grass :: proc() {
	if !grass_is_enabled() do return
	shader := rendering_state.grass_shader
	if !graphics.shader_is_loaded(shader) || rendering_state.grass_time_location < 0 do return
	grass_upload_players(shader)
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
			for blade in 0 ..< 36 {
				seed := (y * tilemap.get_tilemap_width() + x) * 251 + blade * 7
				root := Vec3 {
					left + (f32(blade % 6) + 0.2 + grass_random(seed) * 0.6) * size / 6,
					0.04,
					top + (f32(blade / 6) + 0.2 + grass_random(seed + 1) * 0.6) * size / 6,
				}
				height := 4.2 + grass_random(seed + 2) * 3.4
				// Overlap the 2.67-unit planting cells and present the broad face
				// to the isometric camera instead of losing random blades edge-on.
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
