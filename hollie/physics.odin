package hollie

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
}

physics_jump :: proc(body: ^Transform) {
	if !body.grounded do return
	body.vertical_velocity = PHYSICS_JUMP_SPEED
	body.grounded = false
}
