package hollie

Collider :: struct {
	size:   Vec3,
	offset: Vec3,
	solid:  bool,
}

collision_door_contains_point :: proc(position: Vec3) -> bool {
	for &entity in entities {
		if door, ok := &entity.(Door); ok {
			aabb := collision_aabb_at(door.position, door.collider)
			if position.x >= aabb.min.x &&
			   position.x <= aabb.max.x &&
			   position.y >= aabb.min.y &&
			   position.y <= aabb.max.y &&
			   position.z >= aabb.min.z &&
			   position.z <= aabb.max.z {
				return true
			}
		}
	}
	return false
}

collision_door_for_player :: proc(player: ^Player) -> ^Door {
	for &entity in entities {
		door, ok := &entity.(Door)
		if !ok do continue
		door_entity := Entity(door^)
		player_entity := Entity(player^)
		if collision_entities_intersect(&player_entity, &door_entity) {
			return door
		}
	}
	return nil
}


// Gameplay positions use X/Z map coordinates. Collision volumes are always 3D.
collision_aabb_at :: proc(position: Vec2, collider: Collider, base_height: f32 = 0) -> AABB {
	min := Vec3{position.x, base_height, position.y} + collider.offset
	return {min = min, max = min + collider.size}
}

collision_entity_aabb :: proc(entity: ^Entity) -> AABB {
	position: Vec2
	collider: Collider
	base_height: f32
	switch e in entity {
	case Player: position, collider, base_height = e.position, e.collider, e.height
	case Enemy: position, collider, base_height = e.position, e.collider, e.height
	case Npc: position, collider, base_height = e.position, e.collider, e.height
	case Pressure_Plate: position, collider, base_height = e.position, e.collider, e.height
	case Gate: position, collider, base_height = e.position, e.collider, e.height
	case Holdable:
		position, collider, base_height = e.position, e.collider, e.height
		if e.held_by != nil {
			position = e.held_by.position
			base_height = e.held_by.height + RENDERING_CARRIED_ITEM_HEIGHT
		}
	case Door: position, collider, base_height = e.position, e.collider, e.height
	}
	return collision_aabb_at(position, collider, base_height)
}

collision_entities_intersect :: proc(a, b: ^Entity) -> bool {
	return aabbs_intersect(collision_entity_aabb(a), collision_entity_aabb(b))
}

collision_contains_point :: proc(entity: ^Entity, point: Vec3) -> bool {
	aabb := collision_entity_aabb(entity)
	return(
		point.x >= aabb.min.x &&
		point.x <= aabb.max.x &&
		point.y >= aabb.min.y &&
		point.y <= aabb.max.y &&
		point.z >= aabb.min.z &&
		point.z <= aabb.max.z \
	)
}

collision_check_solid :: proc(
	position: Vec2,
	collider: Collider,
	exclude: ^Entity = nil,
	height: f32 = 0,
) -> bool {
	obstacles := physics_obstacles(exclude)
	defer delete(obstacles)
	return physics_blocked(collision_aabb_at(position, collider, height), obstacles[:], false)
}

holdable_blocks_character :: proc(holdable: Holdable) -> bool {
	return holdable.collider.solid && holdable.held_by == nil
}

// Update systems
