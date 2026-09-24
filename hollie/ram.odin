package hollie

import "tilemap"

BISON_RAM_SPEED :: f32(100)
BISON_CHARGE_TIME :: f32(0.75)
BISON_CHARGE_SPEED :: f32(180)
BISON_CHARGE_TURN_RATE :: f32(1.1)

bison_update_ram_state :: proc(animal: ^Enemy, dt: f32) {
	// Build charge at top speed, but keep it through ordinary steering losses.
	threshold_ratio := animal.ram_ready ? f32(0.75) : f32(0.95)
	if !animal.ram_ready && animal.ram_charge_time > 0 do threshold_ratio = 0.9
	threshold := animal_riding_profile(.Bison).max_speed * threshold_ratio
	fast :=
		animal.velocity.x * animal.velocity.x + animal.velocity.y * animal.velocity.y >=
		threshold * threshold
	if animal.kind != .Bison || !animal.mounted || !animal.grounded || animal.is_busy || !fast {
		animal.ram_charge_time = 0
		animal.ram_ready = false
		return
	}
	animal.ram_charge_time += dt
	animal.ram_ready = animal.ram_charge_time >= BISON_CHARGE_TIME
}

// Swept contact time and speed into the struck face, rather than total speed.
ram_contact :: proc(body, wall: Aabb, velocity: Vec2, dt: f32) -> (f32, f32, bool) {
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

bison_try_ram :: proc(animal: ^Enemy, collider: Collider, dt: f32, obstacles: ^[dynamic]Aabb) {
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
	for &entity in world.entities {
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
		particle_impact_dust(&body, gate.collider, impact_speed)
		return
	}
}
