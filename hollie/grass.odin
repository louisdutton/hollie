package hollie

import "core:c"
import "core:math"
import "graphics"
import "tilemap"

GRASS_TRAIL_COUNT :: 64
GRASS_CONTACT_COUNT :: 32
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

// Shared eligibility and footprint for both live bending and recovery trails.
grass_entity_imprint :: proc(
	entity: ^Entity,
	trail: bool,
) -> (
	imprint: Grass_Imprint,
	valid: bool,
) {
	body: ^Transform
	collider: Collider
	switch &e in entity^ {
	case Player:
		if riding_animal_for_player(e.index) != nil do return
		body, collider = &e.transform, e.collider
	case Enemy: body, collider = &e.transform, e.collider
	case Npc: body, collider = &e.transform, e.collider
	case Holdable:
		if e.held_by != 0 do return
		body, collider = &e.transform, e.collider
	case Pressure_Plate, Gate, Door: return
	}
	bottom := body.height + collider.offset.y
	if bottom >= 8 || bottom + collider.size.y <= 0 || body.swimming do return
	speed := math.sqrt(body.velocity.x * body.velocity.x + body.velocity.y * body.velocity.y)
	if speed <= 3 do return
	strength := trail ? clamp(speed / 30, 0, 1) : clamp((speed - 3) / 65, 0, 1)
	strength = strength * strength * (3 - 2 * strength)
	imprint = {
		position  = {
			body.position.x + collider.offset.x + collider.size.x * 0.5,
			body.position.y + collider.offset.z + collider.size.z * 0.5,
		},
		direction = body.velocity / speed,
		radius    = max(collider.size.x, collider.size.z) * 0.5 + 3,
		strength  = strength * clamp(1 - max(bottom, 0) / 8, 0, 1),
	}
	return imprint, true
}

grass_imprint_overlaps_chunk :: proc(imprint: Grass_Imprint, chunk_min, chunk_max: Vec2) -> bool {
	nearest := Vec2 {
		clamp(imprint.position.x, chunk_min.x, chunk_max.x),
		clamp(imprint.position.y, chunk_min.y, chunk_max.y),
	}
	delta := imprint.position - nearest
	return delta.x * delta.x + delta.y * delta.y < imprint.radius * imprint.radius
}

grass_update_trail :: proc(dt: f32) {
	if !grass_is_enabled() do return
	for &imprint in grass_trail do imprint.age += dt
	grass_trail_timer -= dt
	if grass_trail_timer > 0 do return
	grass_trail_timer = 0.1
	for &entity in world.entities {
		imprint, valid := grass_entity_imprint(&entity, true)
		if !valid do continue
		grass_trail[grass_trail_next] = imprint
		grass_trail_next = (grass_trail_next + 1) % GRASS_TRAIL_COUNT
	}
}

grass_upload_trail :: proc(shader: graphics.Shader, chunk_min, chunk_max: Vec2) {
	positions, directions: [GRASS_TRAIL_COUNT][4]f32
	count := 0
	for imprint in grass_trail {
		if imprint.strength <= 0 || imprint.age >= GRASS_TRAIL_LIFETIME do continue
		if !grass_imprint_overlaps_chunk(imprint, chunk_min, chunk_max) do continue
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

grass_is_enabled :: proc() -> bool {
	for y in 0 ..< tilemap.get_tilemap_height() {
		for x in 0 ..< tilemap.get_tilemap_width() {
			if tilemap.get_grass_density(x, y) > 0 do return true
		}
	}
	return false
}

grass_tile :: proc(x, y: int) -> bool {
	return grass_ground_tile(x, y) || tilemap.get_grass_density(x, y) > 0
}

grass_ground_tile :: proc(x, y: int) -> bool {
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

// Smooth, world-space height groups rather than unrelated tall/short blades.
grass_clump :: proc(position: Vec2) -> f32 {
	p := position * 0.035
	x, y := int(math.floor(p.x)), int(math.floor(p.y))
	f := p - Vec2{f32(x), f32(y)}
	f = f * f * (Vec2{3, 3} - 2 * f)
	a, b := grass_random(x * 137 + y * 311), grass_random((x + 1) * 137 + y * 311)
	c, d := grass_random(x * 137 + (y + 1) * 311), grass_random((x + 1) * 137 + (y + 1) * 311)
	return (a + (b - a) * f.x) * (1 - f.y) + (c + (d - c) * f.x) * f.y
}

grass_upload_contacts :: proc(shader: graphics.Shader, chunk_min, chunk_max: Vec2) {
	contacts, motion: [GRASS_CONTACT_COUNT][4]f32
	count := 0
	for &entity in world.entities {
		imprint, valid := grass_entity_imprint(&entity, false)
		if !valid || !grass_imprint_overlaps_chunk(imprint, chunk_min, chunk_max) do continue
		if count >= len(contacts) do break
		motion[count] = {imprint.direction.x, imprint.direction.y, 0, 0}
		contacts[count] = {
			imprint.position.x,
			imprint.position.y,
			imprint.radius,
			imprint.strength,
		}
		count += 1
	}
	contact_count := c.int(count)
	graphics.set_shader_int(
		shader,
		graphics.get_shader_location(shader, "grass_contact_count"),
		&contact_count,
	)
	if count == 0 do return
	graphics.set_shader_vec4_array(
		shader,
		graphics.get_shader_location(shader, "grass_contacts[0]"),
		contacts[:count],
	)
	graphics.set_shader_vec4_array(
		shader,
		graphics.get_shader_location(shader, "grass_motion[0]"),
		motion[:count],
	)
}

grass_build_tile :: proc(builder: ^Grass_Mesh_Builder, x, y: int) {
	density := f32(tilemap.get_grass_density(x, y)) / 255
	size := f32(tilemap.get_tile_size())
	left, top := f32(x) * size, f32(y) * size
	if grass_ground_tile(x, y) {
		// Alpha encodes blade height; zero marks the continuous ground wash.
		a, b := Vec3{left, 0.03, top}, Vec3{left, 0.03, top + size}
		c, d := Vec3{left + size, 0.03, top + size}, Vec3{left + size, 0.03, top}
		ground := graphics.Colour{255, 255, 255, 0}
		grass_mesh_append(builder, []Vec3{a, b, c, d}, []u16{0, 1, 2, 0, 2, 3}, ground)
	}
	for blade in 0 ..< 36 {
		seed := (y * tilemap.get_tilemap_width() + x) * 251 + blade * 7
		if grass_random(seed + 5) > density do continue
		root := Vec3 {
			left + (f32(blade % 6) + 0.2 + grass_random(seed) * 0.6) * size / 6,
			0.04,
			top + (f32(blade / 6) + 0.2 + grass_random(seed + 1) * 0.6) * size / 6,
		}
		height := 6.4 + grass_clump({root.x, root.z}) * 2.4 + grass_random(seed + 2) * 0.8
		// Tall, overlapping ribbons keep the meadow full at the same density.
		angle := -math.PI / 4 + (grass_random(seed + 3) - 0.5) * 1.1
		width := Vec3{math.cos(angle), 0, math.sin(angle)} * (0.85 + grass_random(seed + 4) * 0.3)
		// Store an upright ribbon. The shader bends its centreline as an arc
		// using the same root and height for every vertex of the blade.
		shoulder := root + Vec3{0, height * 0.58, 0}
		tip := root + Vec3{0, height, 0}
		// Alpha stores height over a 12-unit range (shared with grass.vs).
		color := graphics.Colour{255, 255, 255, u8(height / 12 * 255)}
		// Shared vertices retain both windings without running the vertex
		// shader separately for every triangle corner.
		grass_mesh_append(
			builder,
			[]Vec3 {
				root - width,
				root + width,
				shoulder + width * 0.62,
				shoulder - width * 0.62,
				tip,
			},
			[]u16{0, 1, 2, 0, 2, 3, 3, 2, 4, 2, 1, 0, 3, 2, 0, 4, 2, 3},
			color,
			{root.x, root.z},
		)
	}
}
