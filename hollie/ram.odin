package hollie

import "graphics"
import "tilemap"

BISON_RAM_SPEED :: f32(100)

bison_update_ram_state :: proc(animal: ^Enemy, dt: f32) {
	threshold := animal_riding_profile(.Bison).max_speed * 0.98
	fast :=
		animal.velocity.x * animal.velocity.x + animal.velocity.y * animal.velocity.y >=
		threshold * threshold
	if animal.kind != .Bison || !animal.mounted || !animal.grounded || animal.is_busy || !fast {
		animal.ram_charge_time = 0
		animal.ram_ready = false
		return
	}
	animal.ram_charge_time += dt
	animal.ram_ready = animal.ram_charge_time >= 0.15
}

// Swept contact time and speed into the struck face, rather than total speed.
ram_contact :: proc(body, wall: AABB, velocity: Vec2, dt: f32) -> (f32, f32, bool) {
	if body.max.y <= wall.min.y || body.min.y >= wall.max.y do return 0, 0, false
	if aabbs_intersect(body, wall) do return 0, 0, false
	entry, leave := f32(-1e9), f32(1e9)
	impact_speed: f32
	axes := [2]int{0, 2}
	for axis in axes {
		speed := axis == 0 ? velocity.x : velocity.y
		if abs(speed) < 0.0001 {
			if body.max[axis] <= wall.min[axis] || body.min[axis] >= wall.max[axis] do return 0, 0, false
			continue
		}
		a := (wall.min[axis] - body.max[axis]) / speed
		b := (wall.max[axis] - body.min[axis]) / speed
		near, far := min(a, b), max(a, b)
		if near > entry do entry, impact_speed = near, abs(speed)
		leave = min(leave, far)
	}
	return entry, impact_speed, entry >= 0 && entry <= dt && entry <= leave
}

bison_try_ram :: proc(animal: ^Enemy, collider: Collider, dt: f32, obstacles: ^[dynamic]AABB) {
	if animal.kind != .Bison || !animal.mounted || !animal.grounded || !animal.ram_ready do return
	body := collision_aabb_at(animal.position, collider, animal.height)
	nearest := -1
	nearest_time := dt + 1
	impact_speed: f32
	for obstacle, index in obstacles^ {
		time, speed, hit := ram_contact(body, obstacle, animal.velocity, dt)
		if hit && time < nearest_time do nearest, nearest_time, impact_speed = index, time, speed
	}
	if nearest < 0 || impact_speed < BISON_RAM_SPEED do return
	wall := obstacles^[nearest]
	swept := body
	travel := Vec3{animal.velocity.x * nearest_time, 0, animal.velocity.y * nearest_time}
	for axis in 0 ..< 3 {
		swept.min[axis] += min(travel[axis], 0)
		swept.max[axis] += max(travel[axis], 0)
	}
	if tilemap.check_collision(swept) do return
	for &entity in entities {
		gate, ok := &entity.(Gate)
		if !ok || !gate.breakable || gate.open do continue
		bounds := collision_entity_aabb(&entity)
		if bounds != wall do continue
		gate.open = true
		gate.collider.solid = false
		unordered_remove(obstacles, nearest)
		center := (wall.min + wall.max) / 2
		particle_create_explosion({center.x, center.z})
		body := Transform {
			position = gate.position,
			height   = gate.height,
		}
		particle_crate_landing(&body, gate.collider, impact_speed)
		animal.velocity *= 0.8
		animal.ram_ready = false
		animal.ram_charge_time = 0
		return
	}
}

rendering_draw_weak_wall :: proc(wall: ^Gate) {
	// Irregular sandstone courses and dark gaps distinguish weak masonry.
	long_x := wall.collider.size.x >= wall.collider.size.z
	length := long_x ? wall.collider.size.x : wall.collider.size.z
	thickness := long_x ? wall.collider.size.z : wall.collider.size.x
	bounds := graphics.get_model_bounding_box(model_assets.cube)
	for row in 0 ..< 3 {
		cursor := f32(0)
		for column := 0; cursor < length; column += 1 {
			width := min(length - cursor, row % 2 == 1 && column == 0 ? f32(6) : f32(12))
			position := geometry_position(wall.position, wall.height)
			position.y += (f32(row) + 0.5) * wall.collider.size.y / 3
			position.x += long_x ? cursor + width / 2 : thickness / 2
			position.z += long_x ? thickness / 2 : cursor + width / 2
			size := Vec3{width - 0.7, wall.collider.size.y / 3 - 0.6, thickness - 0.5}
			if !long_x do size.x, size.z = size.z, size.x
			shade := u8(165 + (row + column) % 3 * 12)
			scale := size / (bounds.max - bounds.min)
			graphics.draw_model(
				model_assets.cube,
				position - (bounds.min + bounds.max) * 0.5 * scale,
				{0, 1, 0},
				0,
				scale,
				{shade, shade - 25, shade - 55, 255},
			)
			cursor += width
		}
	}
}
