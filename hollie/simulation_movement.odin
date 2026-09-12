package hollie

// Coordinates physics substeps with gameplay abilities and their visual effects.
simulation_move_body :: proc(
	moving_entity: ^Entity,
	transform: ^Transform,
	collider: ^Collider,
	dt: f32,
	ground_friction: f32 = 0,
) {
	previous, previous_height, was_grounded :=
		transform.position, transform.height, transform.grounded
	obstacles := physics_obstacles(moving_entity, &world)
	defer delete(obstacles)
	// Recover overlaps from spawning, collider rotation, or moved solids using
	// the same safe ejection routine used when puzzle gates close.
	for obstacle in obstacles {
		if aabbs_intersect(
			collision_aabb_at(transform.position, collider^, transform.height),
			obstacle,
		) {
			physics_eject(
				transform,
				collider^,
				obstacle,
				obstacles[:],
				room_get_collision_bounds(),
				true,
			)
		}
	}
	remaining := dt
	for remaining > 0 {
		step_dt := min(remaining, PHYSICS_STEP)
		if animal, ok := &moving_entity^.(Enemy); ok {
			was_ready := animal.ram_ready
			bison_update_ram_state(animal, step_dt)
			if animal.ram_ready && !was_ready do particle_crate_landing(&animal.transform, animal.collider, 180)
			bison_try_ram(animal, collider^, step_dt, &obstacles)
		}
		fall_speed := -transform.vertical_velocity
		airborne := !transform.grounded
		physics_step(transform, collider^, obstacles[:], step_dt, true, ground_friction)
		if animal, ok := &moving_entity^.(Enemy); ok do bison_update_ram_state(animal, 0)
		if crate, ok := moving_entity^.(Holdable);
		   ok && crate.held_by == 0 && airborne && transform.grounded && fall_speed > 20 {
			particle_crate_landing(transform, collider^, fall_speed)
		}
		remaining -= step_dt
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
	#partial switch e in moving_entity^ {
	case Player: particle_emit_trail(transform, previous, previous_height, was_grounded, false)
	case Enemy: if e.kind == .Turtle {
				particle_emit_trail(
					transform,
					previous,
					previous_height,
					was_grounded,
					false,
					0.6,
					{174, 231, 240, 110},
				)
			} else if e.mounted || e.coasting {
				particle_emit_trail(
					transform,
					previous,
					previous_height,
					was_grounded,
					true,
					e.ram_ready ? 1.6 : 1,
				)
			}
	case Holdable:
		if e.held_by == 0 do particle_emit_trail(transform, previous, previous_height, was_grounded, false, 0.65)
	}
}

simulation_update_positions :: proc(dt: f32) {
	// Facing changes with steering and AI; keep physics and debug bounds aligned.
	for &entity in world.entities {
		if animal, ok := &entity.(Enemy); ok {
			if model := animal_model_for_kind(animal.kind); model != nil {
				animal.collider = animal_collider_from_bounds(
					model.bounds,
					animal.facing_direction,
				)
			}
		}
	}
	// Settle crates before characters so their support surfaces are current.
	for &entity in world.entities {
		if crate, ok := &entity.(Holdable); ok && crate.held_by == 0 {
			simulation_move_body(
				&entity,
				&crate.transform,
				&crate.collider,
				dt,
				CRATE_GROUND_FRICTION,
			)
		}
	}
	for &entity in world.entities {
		switch &e in entity {
		case Player:
			if riding_animal_for_player(e.index) != nil do continue
			simulation_move_body(&entity, &e.transform, &e.collider, dt)
		case Enemy:
			collider := riding_movement_collider(&e)
			simulation_move_body(&entity, &e.transform, &collider, dt)
		case Npc: simulation_move_body(&entity, &e.transform, &e.collider, dt)
		case Pressure_Plate, Gate, Holdable, Door: continue
		}
	}
}
