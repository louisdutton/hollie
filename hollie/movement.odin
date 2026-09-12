package hollie

import "core:math"
import "graphics"

Movement_Profile :: struct {
	min_speed, max_speed:       f32,
	acceleration, deceleration: f32,
}

PLAYER_MOVEMENT_PROFILE :: Movement_Profile{20, 80, 640, 960}
RIDING_MOVEMENT_PROFILE :: Movement_Profile{40, 160, 240, 360}

movement_steer_air :: proc(velocity, direction: Vec2, dt: f32) -> Vec2 {
	speed := math.sqrt(velocity.x * velocity.x + velocity.y * velocity.y)
	if speed == 0 || direction == (Vec2{}) do return velocity
	angle := math.atan2(velocity.x, velocity.y)
	target := math.atan2(direction.x, direction.y)
	delta := math.atan2(math.sin(target - angle), math.cos(target - angle))
	input_strength := min(math.sqrt(direction.x * direction.x + direction.y * direction.y), 1)
	max_turn := PLAYER_MOVEMENT_PROFILE.acceleration / speed * input_strength * max(dt, 0)
	angle += clamp(delta, -max_turn, max_turn)
	return Vec2{math.sin(angle), math.cos(angle)} * speed
}

movement_accelerate :: proc(
	velocity, direction: Vec2,
	profile: Movement_Profile,
	dt: f32,
) -> Vec2 {
	magnitude := math.sqrt(direction.x * direction.x + direction.y * direction.y)
	target: Vec2
	if magnitude > 0 {
		speed := profile.min_speed + (profile.max_speed - profile.min_speed) * min(magnitude, 1)
		target = direction / magnitude * speed
	}
	delta := target - velocity
	distance := math.sqrt(delta.x * delta.x + delta.y * delta.y)
	if distance == 0 do return target
	current_speed_squared := velocity.x * velocity.x + velocity.y * velocity.y
	target_speed_squared := target.x * target.x + target.y * target.y
	reversing := velocity.x * target.x + velocity.y * target.y < 0
	rate :=
		target_speed_squared < current_speed_squared || reversing ? profile.deceleration : profile.acceleration
	return velocity + delta / distance * min(distance, rate * max(dt, 0))
}

Transform :: struct {
	position:          Vec2,
	velocity:          Vec2,
	height:            f32,
	vertical_velocity: f32,
	grounded:          bool,
	dust_distance:     f32,
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
	previous, previous_height, was_grounded :=
		transform.position, transform.height, transform.grounded
	obstacles := physics_obstacles(moving_entity)
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
	remaining := min(graphics.get_frame_time(), 0.1)
	for remaining > 0 {
		dt := min(remaining, PHYSICS_STEP)
		if animal, ok := &moving_entity^.(Enemy); ok {
			bison_try_ram(animal, collider^, dt, &obstacles)
		}
		fall_speed := -transform.vertical_velocity
		airborne := !transform.grounded
		physics_step(transform, collider^, obstacles[:], dt, true, ground_friction)
		if crate, ok := moving_entity^.(Holdable);
		   ok && crate.held_by == nil && airborne && transform.grounded && fall_speed > 20 {
			particle_crate_landing(transform, collider^, fall_speed)
		}
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
	#partial switch e in moving_entity^ {
	case Player: particle_emit_trail(transform, previous, previous_height, was_grounded, false)
	case Enemy:
		if e.mounted || e.coasting do particle_emit_trail(transform, previous, previous_height, was_grounded, true)
	case Holdable:
		if e.held_by == nil do particle_emit_trail(transform, previous, previous_height, was_grounded, false, 0.65)
	}
}

movement_update_positions :: proc() {
	// Facing changes with steering and AI; keep physics and debug bounds aligned.
	for &entity in entities {
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
	for &entity in entities {
		if crate, ok := &entity.(Holdable); ok && crate.held_by == nil {
			movement_move(&entity, &crate.transform, &crate.collider, CRATE_GROUND_FRICTION)
		}
	}
	for &entity in entities {
		switch &e in entity {
		case Player:
			if riding_animal_for_player(e.index) != nil do continue
			movement_move(&entity, &e.transform, &e.collider)
		case Enemy:
			collider := riding_movement_collider(&e)
			movement_move(&entity, &e.transform, &collider)
		case Npc: movement_move(&entity, &e.transform, &e.collider)
		case Pressure_Plate, Gate, Holdable, Door: continue
		}
	}
}
