package hollie

import "renderer"

Collider :: struct {
	size:            Vec2,
	offset:          Vec2, // Planar offset from transform position
	height:          f32,
	vertical_offset: f32,
	solid:           bool,
}

collision_door_contains_point :: proc(position: Vec2) -> bool {
	for &entity in entities {
		if door, ok := &entity.(Door); ok {
			collider_position := door.position + door.collider.offset
			if position.x >= collider_position.x &&
			   position.x <= collider_position.x + door.collider.size.x &&
			   position.y >= collider_position.y &&
			   position.y <= collider_position.y + door.collider.size.y {
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
		door_pos := collision_entity_world_position(&door_entity)
		door_size := collision_entity_size(&door_entity)

		player_rect := collision_rect_at(player.position, player.collider)
		door_rect := renderer.Rect{door_pos.x, door_pos.y, door_size.x, door_size.y}

		if rects_intersect(player_rect, door_rect) {
			return door
		}
	}
	return nil
}


// Collision helpers
collision_rect_at :: proc(position: Vec2, collider: Collider) -> renderer.Rect {
	return {
		position.x + collider.offset.x,
		position.y + collider.offset.y,
		collider.size.x,
		collider.size.y,
	}
}

collision_entity_world_position :: proc(entity: ^Entity) -> Vec2 {
	switch e in entity {
	case Player: return e.position + e.collider.offset
	case Enemy: return e.position + e.collider.offset
	case Npc: return e.position + e.collider.offset
	case Pressure_Plate: return e.position + e.collider.offset
	case Gate: return e.position + e.collider.offset
	case Holdable:
		position := e.position
		if e.held_by != nil do position = e.held_by.position
		return position + e.collider.offset
	case Door: return e.position + e.collider.offset
	}
	return {0, 0}
}

collision_entity_size :: proc(entity: ^Entity) -> Vec2 {
	switch e in entity {
	case Player: return e.collider.size
	case Enemy: return e.collider.size
	case Npc: return e.collider.size
	case Pressure_Plate: return e.collider.size
	case Gate: return e.collider.size
	case Holdable: return e.collider.size
	case Door: return e.collider.size
	}
	return {0, 0}
}

collision_entity_height :: proc(entity: ^Entity) -> f32 {
	switch e in entity {
	case Player: return e.collider.height
	case Enemy: return e.collider.height
	case Npc: return e.collider.height
	case Pressure_Plate: return e.collider.height
	case Gate: return e.collider.height
	case Holdable: return e.collider.height
	case Door: return e.collider.height
	}
	return 0
}

collision_entity_vertical_offset :: proc(entity: ^Entity) -> f32 {
	switch e in entity {
	case Player: return e.collider.vertical_offset
	case Enemy: return e.collider.vertical_offset
	case Npc: return e.collider.vertical_offset
	case Pressure_Plate: return e.collider.vertical_offset
	case Gate: return e.collider.vertical_offset
	case Holdable:
		base_height := e.held_by != nil ? RENDERING_CARRIED_ITEM_HEIGHT : f32(0)
		return e.collider.vertical_offset + base_height
	case Door: return e.collider.vertical_offset
	}
	return 0
}

collision_entities_intersect :: proc(a, b: ^Entity) -> bool {
	pos_a := collision_entity_world_position(a)
	size_a := collision_entity_size(a)
	pos_b := collision_entity_world_position(b)
	size_b := collision_entity_size(b)

	return(
		pos_a.x < pos_b.x + size_b.x &&
		pos_a.x + size_a.x > pos_b.x &&
		pos_a.y < pos_b.y + size_b.y &&
		pos_a.y + size_a.y > pos_b.y \
	)
}

collision_contains_point :: proc(entity: ^Entity, point: Vec2) -> bool {
	pos := collision_entity_world_position(entity)
	size := collision_entity_size(entity)

	return(
		point.x >= pos.x &&
		point.x <= pos.x + size.x &&
		point.y >= pos.y &&
		point.y <= pos.y + size.y \
	)
}

collision_check_solid :: proc(position: Vec2, size: Vec2, exclude: ^Entity = nil) -> bool {
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
			if collision_entity_intersects_rect(entity_ptr, position, size) {
				return true
			}
		}
	}
	return false
}

holdable_blocks_character :: proc(holdable: Holdable) -> bool {
	return holdable.collider.solid && holdable.held_by == nil
}

collision_entity_intersects_rect :: proc(
	entity: ^Entity,
	rect_pos: Vec2,
	rect_size: Vec2,
) -> bool {
	entity_pos := collision_entity_world_position(entity)
	entity_size := collision_entity_size(entity)

	// Convert position to collision box position (assuming center-based positioning)
	char_pos := rect_pos + Vec2{-rect_size.x / 2, -rect_size.y / 2}

	return(
		char_pos.x < entity_pos.x + entity_size.x &&
		char_pos.x + rect_size.x > entity_pos.x &&
		char_pos.y < entity_pos.y + entity_size.y &&
		char_pos.y + rect_size.y > entity_pos.y \
	)
}

// Update systems
