package hollie

import "graphics"

Health :: struct {
	current:         i32,
	max:             i32,
	is_dying:        bool,
	death_timer:     u32,
	hit_flash_timer: f32,
	knockback_timer: f32,
}

health_update :: proc() {
	delta_time := graphics.get_frame_time()
	for &entity in entities {
		switch &e in entity {
		case Player: health_update_timers(&e.health, delta_time)
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
