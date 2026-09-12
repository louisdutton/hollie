package hollie

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
				e.velocity = movement_accelerate(e.velocity, {}, RIDING_MOVEMENT_PROFILE, dt)
				e.turn_lean = riding_turn_lean(e.turn_lean, {}, {}, dt)
				e.head_turn = riding_head_turn(e.head_turn, e.facing_direction, {}, dt)
				if e.velocity == (Vec2{}) {
					e.coasting = false
					e.wait_timer = 0.5
				}
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
