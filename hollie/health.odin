package hollie


// Preserve the previous 26-update death delay at the default 60 Hz.
DEATH_DURATION :: f32(26.0 / 60.0)

Health :: struct {
	current:         i32,
	max:             i32,
	is_dying:        bool,
	death_timer:     f32,
	hit_flash_timer: f32,
	knockback_timer: f32,
}

health_update :: proc(dt: f32) {

	for &entity in world.entities {
		switch &e in entity {
		case Player: health_update_timers(&e.health, dt)
		case Enemy: health_update_timers(&e.health, dt)
		case Npc: health_update_timers(&e.health, dt)
		case Pressure_Plate, Gate, Holdable, Door: continue
		}
	}
}

@(private)
health_update_timers :: proc(health: ^Health, dt: f32) {
	if health.is_dying do health.death_timer += dt
	if health.hit_flash_timer > 0 do health.hit_flash_timer = max(health.hit_flash_timer - dt, 0)
	if health.knockback_timer > 0 do health.knockback_timer = max(health.knockback_timer - dt, 0)
}
