package hollie

Collider :: struct {
	size:   Vec3,
	offset: Vec3,
	solid:  bool,
}

collision_door_contains_point :: proc(position: Vec3) -> bool {
	for &entity in entities {
		if door, ok := &entity.(Door); ok {
			box := collision_box_at(door.position, door.collider)
			if position.x >= box.min.x &&
			   position.x <= box.max.x &&
			   position.y >= box.min.y &&
			   position.y <= box.max.y &&
			   position.z >= box.min.z &&
			   position.z <= box.max.z {
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
collision_box_at :: proc(
	position: Vec2,
	collider: Collider,
	base_height: f32 = 0,
) -> Collision_Box {
	min := Vec3{position.x, base_height, position.y} + collider.offset
	return {min = min, max = min + collider.size}
}

collision_entity_box :: proc(entity: ^Entity) -> Collision_Box {
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
	return collision_box_at(position, collider, base_height)
}

collision_entities_intersect :: proc(a, b: ^Entity) -> bool {
	return boxes_intersect(collision_entity_box(a), collision_entity_box(b))
}

collision_contains_point :: proc(entity: ^Entity, point: Vec3) -> bool {
	box := collision_entity_box(entity)
	return(
		point.x >= box.min.x &&
		point.x <= box.max.x &&
		point.y >= box.min.y &&
		point.y <= box.max.y &&
		point.z >= box.min.z &&
		point.z <= box.max.z \
	)
}

collision_check_solid :: proc(position: Vec2, collider: Collider, exclude: ^Entity = nil) -> bool {
	box := collision_box_at(position, collider)
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
			if boxes_intersect(collision_entity_box(entity_ptr), box) {
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
