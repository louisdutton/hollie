package hollie

import "core:c"
import "core:math"
import "graphics"
import "tilemap"

GRASS_TRAIL_COUNT :: 64
GRASS_TRAIL_LIFETIME :: f32(2.6)

Grass_Imprint :: struct {
	position, direction:   Vec2,
	radius, strength, age: f32,
}

grass_trail: [GRASS_TRAIL_COUNT]Grass_Imprint
grass_trail_next: int
grass_trail_timer: f32

grass_reset_trail :: proc() {
	grass_trail = {}
	grass_trail_next = 0
	grass_trail_timer = 0
}

grass_update_trail :: proc(dt: f32) {
	if !grass_is_enabled() do return
	for &imprint in grass_trail do imprint.age += dt
	grass_trail_timer -= dt
	if grass_trail_timer > 0 do return
	grass_trail_timer = 0.1
	for &entity in world.entities {
		player, ok := &entity.(Player)
		if !ok do continue
		speed := math.sqrt(
			player.velocity.x * player.velocity.x + player.velocity.y * player.velocity.y,
		)
		bottom := player.height + player.collider.offset.y
		if speed <= 3 || bottom >= 8 do continue
		// Even a walking stride should leave a legible imprint.
		strength := clamp(speed / 30, 0, 1)
		strength = strength * strength * (3 - 2 * strength)
		grass_trail[grass_trail_next] = {
			position  = {
				player.position.x + player.collider.offset.x + player.collider.size.x * 0.5,
				player.position.y + player.collider.offset.z + player.collider.size.z * 0.5,
			},
			direction = player.velocity / speed,
			radius    = max(player.collider.size.x, player.collider.size.z) * 0.5 + 3,
			strength  = strength * clamp(1 - max(bottom, 0) / 8, 0, 1),
		}
		grass_trail_next = (grass_trail_next + 1) % GRASS_TRAIL_COUNT
	}
}

grass_upload_trail :: proc(shader: graphics.Shader, chunk_min, chunk_max: Vec2) {
	positions, directions: [GRASS_TRAIL_COUNT][4]f32
	count := 0
	for imprint in grass_trail {
		if imprint.strength <= 0 || imprint.age >= GRASS_TRAIL_LIFETIME do continue
		nearest := Vec2 {
			clamp(imprint.position.x, chunk_min.x, chunk_max.x),
			clamp(imprint.position.y, chunk_min.y, chunk_max.y),
		}
		delta := imprint.position - nearest
		if delta.x * delta.x + delta.y * delta.y >= imprint.radius * imprint.radius do continue
		remaining := 1 - imprint.age / GRASS_TRAIL_LIFETIME
		fade := remaining * remaining * (3 - 2 * remaining)
		positions[count] = {
			imprint.position.x,
			imprint.position.y,
			imprint.radius,
			imprint.strength * fade,
		}
		directions[count] = {imprint.direction.x, imprint.direction.y, 0, 0}
		count += 1
	}
	trail_count := c.int(count)
	graphics.set_shader_int(
		shader,
		graphics.get_shader_location(shader, "grass_trail_count"),
		&trail_count,
	)
	if count == 0 do return
	graphics.set_shader_vec4_array(
		shader,
		graphics.get_shader_location(shader, "grass_trail[0]"),
		positions[:count],
	)
	graphics.set_shader_vec4_array(
		shader,
		graphics.get_shader_location(shader, "grass_trail_motion[0]"),
		directions[:count],
	)
}

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
	motion: [2][4]f32
	count := 0
	for &entity in world.entities {
		player, ok := &entity.(Player)
		if !ok do continue
		if count >= len(players) do break
		bottom := player.height + player.collider.offset.y
		speed := math.sqrt(
			player.velocity.x * player.velocity.x + player.velocity.y * player.velocity.y,
		)
		strength := clamp((speed - 3) / 65, 0, 1)
		strength = strength * strength * (3 - 2 * strength)
		motion[count] = {
			player.velocity.x / max(speed, 1),
			player.velocity.y / max(speed, 1),
			0,
			0,
		}
		players[count] = {
			player.position.x + player.collider.offset.x + player.collider.size.x * 0.5,
			player.position.y + player.collider.offset.z + player.collider.size.z * 0.5,
			max(player.collider.size.x, player.collider.size.z) * 0.5 + 3,
			clamp(1 - max(bottom, 0) / 8, 0, 1) * strength,
		}
		count += 1
	}
	graphics.set_shader_vec4_array(
		shader,
		graphics.get_shader_location(shader, "grass_players[0]"),
		players[:],
	)
	graphics.set_shader_vec4_array(
		shader,
		graphics.get_shader_location(shader, "grass_motion[0]"),
		motion[:],
	)
}

grass_build_tile :: proc(builder: ^Grass_Mesh_Builder, x, y: int) {
	size := f32(tilemap.get_tile_size())
	left, top := f32(x) * size, f32(y) * size
	// Alpha encodes blade height; zero marks the continuous ground wash.
	a, b := Vec3{left, 0.03, top}, Vec3{left, 0.03, top + size}
	c, d := Vec3{left + size, 0.03, top + size}, Vec3{left + size, 0.03, top}
	ground := graphics.Colour{255, 255, 255, 0}
	grass_mesh_append(builder, []Vec3{a, b, c, d}, []u16{0, 1, 2, 0, 2, 3}, ground)
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
		width := Vec3{math.cos(angle), 0, math.sin(angle)} * (1.25 + grass_random(seed + 4) * 0.55)
		// Carry the leaf's width almost to the top, then close with a
		// short, gently leaning cap instead of a long needle-like taper.
		shoulder := root + Vec3{0.45, height * 0.82, 0.2}
		tip := root + Vec3{0.85, height, 0.35}
		color := graphics.Colour{255, 255, 255, u8(height / 8 * 255)}
		// Shared vertices retain both windings without running the vertex
		// shader separately for every triangle corner.
		grass_mesh_append(
			builder,
			[]Vec3 {
				root - width,
				root + width,
				shoulder + width * 0.7,
				shoulder - width * 0.7,
				tip,
			},
			[]u16{0, 1, 2, 0, 2, 3, 3, 2, 4, 2, 1, 0, 3, 2, 0, 4, 2, 3},
			color,
		)
	}
}
