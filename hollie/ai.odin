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
