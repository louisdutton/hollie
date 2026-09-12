package hollie

import "graphics"

Transform :: struct {
	position:          Vec2,
	velocity:          Vec2,
	height:            f32,
	vertical_velocity: f32,
	grounded:          bool,
}

Movement :: struct {
	move_speed:       f32,
	facing_direction: Vec2,
	is_busy:          bool,
}

movement_move :: proc(
	moving_entity: ^Entity,
	transform: ^Transform,
	collider: ^Collider,
	ground_friction: f32 = 0,
) {
	obstacles := physics_obstacles(moving_entity)
	defer delete(obstacles)
	remaining := min(graphics.get_frame_time(), 0.1)
	for remaining > 0 {
		dt := min(remaining, PHYSICS_STEP)
		physics_step(transform, collider^, obstacles[:], dt, true, ground_friction)
		remaining -= dt
	}

	room_bounds := room_get_collision_bounds()
	transform.position.x = clamp(
		transform.position.x,
		room_bounds.x - collider.offset.x,
		room_bounds.x + room_bounds.width - collider.offset.x - collider.size.x,
	)
	transform.position.y = clamp(
		transform.position.y,
		room_bounds.y - collider.offset.z,
		room_bounds.y + room_bounds.height - collider.offset.z - collider.size.z,
	)
}

movement_update_positions :: proc() {
	// Settle crates before characters so their support surfaces are current.
	for &entity in entities {
		if crate, ok := &entity.(Holdable); ok && crate.held_by == nil {
			movement_move(&entity, &crate.transform, &crate.collider, CRATE_GROUND_FRICTION)
		}
	}
	for &entity in entities {
		switch &e in entity {
		case Player: movement_move(&entity, &e.transform, &e.collider)
		case Enemy: movement_move(&entity, &e.transform, &e.collider)
		case Npc: movement_move(&entity, &e.transform, &e.collider)
		case Pressure_Plate, Gate, Holdable, Door: continue
		}
	}
}
