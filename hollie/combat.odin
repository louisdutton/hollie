package hollie

import "audio"
import "core:math"
import "graphics"

Health :: struct {
	current:         i32,
	max:             i32,
	is_dying:        bool,
	death_timer:     u32,
	hit_flash_timer: f32,
	knockback_timer: f32,
}

Combat :: struct {
	damage:           i32,
	range:            f32,
	attack_width:     f32,
	attack_height:    f32,
	is_attacking:     bool,
	attack_timer:     u32,
	attack_hit:       bool,
	attack_direction: Vec2,
}

combat_update_timers :: proc() {
	delta_time := graphics.get_frame_time()
	for &entity in entities {
		switch &e in entity {
		case Player:
			if e.is_attacking {
				e.attack_timer += 1
				if e.attack_timer >= 10 * INTERVAL {
					e.is_attacking = false
					e.attack_timer = 0
					e.attack_hit = false
				}
			}
			health_update_timers(&e.health, delta_time)
		case Enemy: health_update_timers(&e.health, delta_time)
		case Npc: health_update_timers(&e.health, delta_time)
		case Pressure_Plate, Gate, Holdable, Door: continue
		}
	}
}

@(private)
health_update_timers :: proc(health: ^Health, delta_time: f32) {
	if health.is_dying do health.death_timer += 1
	if health.hit_flash_timer > 0 do health.hit_flash_timer = max(health.hit_flash_timer - delta_time, 0)
	if health.knockback_timer > 0 do health.knockback_timer = max(health.knockback_timer - delta_time, 0)
}

combat_update :: proc() {
	for &attacker in entities {
		switch &a in attacker {
		case Player:
			if !a.is_attacking || a.attack_hit do continue

			attack_offset := a.attack_direction * a.range
			attack_pos := a.position + attack_offset
			attacker_box := collision_box_at(a.position, a.collider)
			attack_box := graphics.Bounding_Box {
				min = {
					attack_pos.x - a.attack_width / 2,
					attacker_box.min.y,
					attack_pos.y - a.attack_height / 2,
				},
				max = {
					attack_pos.x + a.attack_width / 2,
					attacker_box.max.y,
					attack_pos.y + a.attack_height / 2,
				},
			}

			for &target in entities {
				switch &t in target {
				case Enemy:
					if t.is_dying do continue
					if !boxes_intersect(attack_box, collision_box_at(t.position, t.collider)) do continue

					t.current -= a.damage
					a.attack_hit = true
					audio.sound_play(&game.sounds, audio.Sound_Kind.AttackHit)
					audio.sound_play(&game.sounds, audio.Sound_Kind.EnemyHit)
					t.hit_flash_timer = 0.2

					knockback_dir := t.position - a.position
					if abs(knockback_dir.x) > 0 || abs(knockback_dir.y) > 0 {
						length := math.sqrt(
							knockback_dir.x * knockback_dir.x + knockback_dir.y * knockback_dir.y,
						)
						t.velocity = knockback_dir / length * 200
						t.knockback_timer = 0.3
					}

					if t.current <= 0 {
						audio.sound_play(&game.sounds, audio.Sound_Kind.EnemyDeath)
						t.is_dying = true
						t.death_timer = 0
					}
				case Player, Npc, Pressure_Plate, Gate, Holdable, Door: continue
				}
			}
		case Enemy, Npc, Pressure_Plate, Gate, Holdable, Door: continue
		}
	}
}
