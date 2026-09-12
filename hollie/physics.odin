package hollie

import "core:math"

import "graphics"
import "tilemap"

PHYSICS_GRAVITY :: f32(800)
PHYSICS_JUMP_SPEED :: f32(220)
PHYSICS_STEP :: f32(1.0 / 120.0)
PHYSICS_STEP_HEIGHT :: f32(6)
PHYSICS_CONTACT_EPSILON :: f32(0.01)

physics_overlap_horizontal :: proc(a, b: AABB) -> bool {
	return a.min.x < b.max.x && a.max.x > b.min.x && a.min.z < b.max.z && a.max.z > b.min.z
}

physics_obstacles :: proc(exclude: ^Entity) -> [dynamic]AABB {
	obstacles := make([dynamic]AABB)
	if tm := room_get_current(); tm != nil {
		for structure in tm.structures {
			for wall in house_wall_aabbs(structure.position, structure.size) do append(&obstacles, wall)
			append(&obstacles, house_roof_aabb(structure.position, structure.size))
		}
	}
	for &entity in entities {
		if &entity == exclude do continue
		solid := false
		switch e in entity {
		case Pressure_Plate: solid = true
		case Gate: solid = e.collider.solid && !e.open
		case Holdable: solid = holdable_blocks_character(e)
		case Player, Enemy, Npc, Door: continue
		}
		if solid do append(&obstacles, collision_entity_aabb(&entity))
	}
	return obstacles
}

physics_blocked :: proc(aabb: AABB, obstacles: []AABB, collide_tiles: bool) -> bool {
	for obstacle in obstacles {
		if aabbs_intersect(aabb, obstacle) do return true
	}
	return collide_tiles && tilemap.check_collision(aabb)
}

physics_move_axis :: proc(
	body: ^Transform,
	collider: Collider,
	position: Vec2,
	obstacles: []AABB,
	collide_tiles: bool,
) {
	aabb := collision_aabb_at(position, collider, body.height)
	if !physics_blocked(aabb, obstacles, collide_tiles) {
		body.position = position
		return
	}
	if !body.grounded || body.vertical_velocity > 0 do return
	// Walk onto low platforms, but require clearance for the entire body.
	step_height := body.height
	for obstacle in obstacles {
		if aabbs_intersect(aabb, obstacle) {
			step_height = max(step_height, obstacle.max.y - collider.offset.y)
		}
	}
	if step_height - body.height > PHYSICS_STEP_HEIGHT do return
	raised := collision_aabb_at(position, collider, step_height)
	clearance := collision_aabb_at(body.position, collider, step_height)
	if !physics_blocked(raised, obstacles, collide_tiles) &&
	   !physics_blocked(clearance, obstacles, collide_tiles) {
		body.position = position
		body.height = step_height
	}
}

physics_step :: proc(
	body: ^Transform,
	collider: Collider,
	obstacles: []AABB,
	dt: f32,
	collide_tiles: bool = false,
	ground_friction: f32 = 0,
) {
	physics_move_axis(
		body,
		collider,
		body.position + Vec2{body.velocity.x * dt, 0},
		obstacles,
		collide_tiles,
	)
	physics_move_axis(
		body,
		collider,
		body.position + Vec2{0, body.velocity.y * dt},
		obstacles,
		collide_tiles,
	)
	previous := collision_aabb_at(body.position, collider, body.height)
	body.vertical_velocity -= PHYSICS_GRAVITY * dt
	next_height := body.height + body.vertical_velocity * dt
	next := collision_aabb_at(body.position, collider, next_height)
	body.grounded = false
	if body.vertical_velocity <= 0 {
		floor_height: f32 = 0
		for obstacle in obstacles {
			if physics_overlap_horizontal(next, obstacle) &&
			   previous.min.y >= obstacle.max.y - PHYSICS_CONTACT_EPSILON &&
			   next.min.y <= obstacle.max.y {
				floor_height = max(floor_height, obstacle.max.y)
			}
		}
		if next.min.y <= floor_height {
			next_height = floor_height - collider.offset.y
			body.vertical_velocity = 0
			body.grounded = true
		}
	} else {
		for obstacle in obstacles {
			if physics_overlap_horizontal(next, obstacle) &&
			   previous.max.y <= obstacle.min.y + PHYSICS_CONTACT_EPSILON &&
			   next.max.y >= obstacle.min.y {
				next_height = min(
					next_height,
					obstacle.min.y - collider.offset.y - collider.size.y,
				)
				body.vertical_velocity = 0
			}
		}
	}
	body.height = next_height
	if body.grounded && ground_friction > 0 {
		speed := math.sqrt(body.velocity.x * body.velocity.x + body.velocity.y * body.velocity.y)
		if speed > 0 {
			remaining_speed := max(speed - ground_friction * dt, 0)
			body.velocity *= remaining_speed / speed
		}
	}
}

physics_jump :: proc(body: ^Transform) {
	if !body.grounded do return
	body.vertical_velocity = PHYSICS_JUMP_SPEED
	body.grounded = false
}

// Resolve a newly enabled solid without moving the body through another wall.
physics_eject :: proc(
	body: ^Transform,
	collider: Collider,
	solid: AABB,
	obstacles: []AABB,
	bounds: graphics.Rect,
	collide_tiles: bool = false,
) -> bool {
	start := collision_aabb_at(body.position, collider, body.height)
	if !aabbs_intersect(start, solid) do return true
	gap := PHYSICS_CONTACT_EPSILON
	offsets := [5]Vec3 {
		{solid.min.x - start.max.x - gap, 0, 0},
		{solid.max.x - start.min.x + gap, 0, 0},
		{0, 0, solid.min.z - start.max.z - gap},
		{0, 0, solid.max.z - start.min.z + gap},
		{0, solid.max.y - start.min.y + gap, 0},
	}
	best: Vec3
	best_distance := f32(1e9)
	for offset, index in offsets {
		// Prefer a clear side; lifting onto the gate is a fallback.
		if index == 4 && best_distance < 1e9 do break
		candidate := AABB {
			min = start.min + offset,
			max = start.max + offset,
		}
		if candidate.min.x < bounds.x ||
		   candidate.max.x > bounds.x + bounds.width ||
		   candidate.min.z < bounds.y ||
		   candidate.max.z > bounds.y + bounds.height {
			continue
		}
		if physics_blocked(candidate, obstacles, collide_tiles) do continue
		swept := AABB {
			min = {
				min(start.min.x, candidate.min.x),
				min(start.min.y, candidate.min.y),
				min(start.min.z, candidate.min.z),
			},
			max = {
				max(start.max.x, candidate.max.x),
				max(start.max.y, candidate.max.y),
				max(start.max.z, candidate.max.z),
			},
		}
		blocked := collide_tiles && tilemap.check_collision(swept)
		for obstacle in obstacles {
			if obstacle.min == solid.min && obstacle.max == solid.max do continue
			if aabbs_intersect(swept, obstacle) do blocked = true
		}
		if blocked do continue
		distance := offset.x * offset.x + offset.y * offset.y + offset.z * offset.z
		if distance < best_distance do best, best_distance = offset, distance
	}
	if best_distance == 1e9 do return false
	body.position += Vec2{best.x, best.z}
	body.height += best.y
	if best.x != 0 do body.velocity.x = 0
	if best.z != 0 do body.velocity.y = 0
	if best.y != 0 do body.vertical_velocity = 0
	body.grounded = false
	return true
}

Physics_Body_Snapshot :: struct {
	body:   ^Transform,
	before: Transform,
}

physics_close_gate :: proc(gate_entity: ^Entity) -> bool {
	gate := &gate_entity.(Gate)
	gate.open = false
	solid := collision_entity_aabb(gate_entity)
	snapshots := make([dynamic]Physics_Body_Snapshot)
	defer delete(snapshots)
	// Move crates first, so actors can avoid their final positions.
	for pass in 0 ..< 2 {
		for &entity in entities {
			body: ^Transform
			collider: Collider
			switch &e in entity {
			case Holdable:
				if pass != 0 || e.held_by != nil do continue
				body, collider = &e.transform, e.collider
			case Player:
				if pass != 1 do continue
				if riding_animal_for_player(e.index) != nil do continue
				body, collider = &e.transform, e.collider
			case Enemy:
				if pass != 1 do continue
				body, collider = &e.transform, riding_movement_collider(&e)
			case Npc:
				if pass != 1 do continue
				body, collider = &e.transform, e.collider
			case Pressure_Plate, Gate, Door: continue
			}
			if !aabbs_intersect(collision_aabb_at(body.position, collider, body.height), solid) do continue
			append(&snapshots, Physics_Body_Snapshot{body, body^})
			obstacles := physics_obstacles(&entity)
			resolved := physics_eject(
				body,
				collider,
				solid,
				obstacles[:],
				room_get_collision_bounds(),
				true,
			)
			delete(obstacles)
			if !resolved {
				// No safe placement: keep the gate open and retry next update.
				for snapshot in snapshots do snapshot.body^ = snapshot.before
				gate.open = true
				return false
			}
		}
	}
	return true
}
