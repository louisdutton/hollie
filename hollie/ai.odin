package hollie

import "core:math"
import "core:math/rand"
import "graphics"

Ai :: struct {
	wait_timer:     f32,
	move_timer:     f32,
	move_direction: Vec2,
}

ai_update_movement :: proc() {
	for &entity in entities {
		switch &e in entity {
		case Enemy:
			if e.mounted do continue
			if e.coasting {
				dt := min(graphics.get_frame_time(), 0.1)
				animal_update_movement(&e, {}, RIDING_MOVEMENT_PROFILE, dt)
				if e.velocity == (Vec2{}) {
					e.coasting = false
					e.wait_timer = 0.5
				}
				continue
			}
			if animal_model_for_kind(e.kind) != nil {
				ai_update_animal(&e)
				continue
			}
			if e.wait_timer > 0 {
				e.wait_timer -= graphics.get_frame_time()
				continue
			}
			ai_update_velocity(&e.transform, &e.movement, &e.health, &e.ai)
		case Npc: ai_update_velocity(&e.transform, &e.movement, &e.health, &e.ai)
		case Player, Pressure_Plate, Gate, Holdable, Door: continue
		}
	}
}

// Check along the route so a probe cannot skip over a narrow shoreline.
ai_animal_terrain_clear :: proc(animal: ^Enemy, direction: Vec2, distance: f32) -> bool {
	wants_water := animal.kind == .Turtle
	started_home := water_at(animal.position) == wants_water
	for step := f32(4); step <= distance + 4; step += 4 {
		home := water_at(animal.position + direction * min(step, distance)) == wants_water
		if started_home && !home do return false
		if home do started_home = true
	}
	// Animals dismounted on unsuitable terrain can move out of it.
	return true
}

ai_update_animal :: proc(animal: ^Enemy) {
	dt := min(graphics.get_frame_time(), 0.1)
	direction: Vec2
	if animal.wait_timer > 0 {
		animal.wait_timer -= dt
	} else if !animal.is_busy && !animal.is_dying && animal.knockback_timer <= 0 {
		animal.move_timer -= dt
		if animal.move_timer <= 0 {
			animal.move_direction = {rand.float32_range(-1, 1), rand.float32_range(-1, 1)}
			animal.move_timer = rand.float32_range(1, 3)
			if rand.float32() < 0.25 do animal.wait_timer = rand.float32_range(0.5, 1.5)
		}
		if animal.wait_timer <= 0 do direction = animal.move_direction
	}
	speed := math.sqrt(
		animal.velocity.x * animal.velocity.x + animal.velocity.y * animal.velocity.y,
	)
	look_ahead := max(f32(24), speed / 1.5 + 12)
	if direction != (Vec2{}) && (animal.grounded || animal.swimming) {
		actor := Entity(animal^)
		obstacles := physics_obstacles(&actor)
		defer delete(obstacles)
		probe := animal.position + animal.facing_direction * 18
		requested := direction / math.sqrt(direction.x * direction.x + direction.y * direction.y)
		if !ai_animal_terrain_clear(animal, animal.facing_direction, look_ahead) ||
		   !ai_animal_terrain_clear(animal, requested, look_ahead) ||
		   physics_blocked(
			   collision_aabb_at(probe, animal.collider, animal.height + PHYSICS_STEP_HEIGHT),
			   obstacles[:],
			   true,
		   ) {
			// Pick a clear side before reaching a wall, rather than pushing at it
			// until the wandering timer happens to select another heading.
			right := Vec2{animal.facing_direction.y, -animal.facing_direction.x}
			direction = {}
			sides := [3]Vec2{right, -right, -animal.facing_direction}
			for side in sides {
				probe = animal.position + side * 18
				if ai_animal_terrain_clear(animal, side, look_ahead) &&
				   !physics_blocked(
						   collision_aabb_at(
							   probe,
							   animal.collider,
							   animal.height + PHYSICS_STEP_HEIGHT,
						   ),
						   obstacles[:],
						   true,
					   ) {
					direction = side
					break
				}
			}
			animal.move_direction = direction
			animal.move_timer = 1
		}
	}
	animal_update_movement(animal, direction, ANIMAL_WANDER_PROFILE, dt)
	// Brake before the bank while the normal steering turns the animal away.
	// This is an AI decision, not a terrain collider or mounted restriction.
	stopping_distance := speed * speed / (2 * ANIMAL_WANDER_PROFILE.deceleration) + 8
	if !ai_animal_terrain_clear(animal, animal.facing_direction, stopping_distance) {
		next_speed := max(speed - ANIMAL_WANDER_PROFILE.deceleration * dt, 0)
		animal.velocity = animal.facing_direction * next_speed
	}
}

@(private)
ai_update_velocity :: proc(transform: ^Transform, movement: ^Movement, health: ^Health, ai: ^Ai) {
	if health.is_dying || health.knockback_timer > 0 || movement.is_busy {
		if health.knockback_timer > 0 {
			transform.velocity *= 0.85
		} else {
			transform.velocity = {0, 0}
		}
		return
	}

	ai.move_timer -= graphics.get_frame_time()
	if ai.move_timer <= 0 {
		ai.move_direction = {rand.float32_range(-1.0, 1.0), rand.float32_range(-1.0, 1.0)}
		ai.move_timer = rand.float32_range(1.0, 3.0)
	}
	transform.velocity = ai.move_direction * movement.move_speed
	if abs(ai.move_direction.x) > 0 || abs(ai.move_direction.y) > 0 {
		movement.facing_direction = ai.move_direction
	}
}
