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
	case Player: position, collider = e.position, e.collider
	case Enemy: position, collider = e.position, e.collider
	case Npc: position, collider = e.position, e.collider
	case Pressure_Plate: position, collider = e.position, e.collider
	case Gate: position, collider = e.position, e.collider
	case Holdable:
		position, collider = e.position, e.collider
		if e.held_by != nil {
			position = e.held_by.position
			base_height = RENDERING_CARRIED_ITEM_HEIGHT
		}
	case Door: position, collider = e.position, e.collider
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

collision_check_solid :: proc(position: Vec2, collider: Collider, exclude: ^Entity = nil) -> bool {
	aabb := collision_aabb_at(position, collider)
	if tm := room_get_current(); tm != nil {
		for structure in tm.structures {
			for wall in house_wall_aabbs(structure.position, structure.size) {
				if aabbs_intersect(aabb, wall) do return true
			}
		}
	}
	for &entity in entities {
		if exclude != nil && &entity == exclude do continue

		is_solid := false
		switch e in entity {
		case Player, Enemy, Npc, Pressure_Plate: is_solid = false
		case Gate: is_solid = e.collider.solid && !e.open
		case Holdable: is_solid = holdable_blocks_character(e)
		case Door: is_solid = false // Doors are triggers, not solid barriers
		}

		if is_solid {
			entity_ptr := &entity
			if aabbs_intersect(collision_entity_aabb(entity_ptr), aabb) {
				return true
			}
		}
	}
	return false
}

holdable_blocks_character :: proc(holdable: Holdable) -> bool {
	return holdable.collider.solid && holdable.held_by == nil
}

// Update systems
