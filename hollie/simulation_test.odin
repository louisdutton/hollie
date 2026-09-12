package hollie

import "core:testing"

@(test)
test_simulation_clamps_stalls_once_at_the_boundary :: proc(t: ^testing.T) {
	testing.expect_value(t, simulation_delta_time(-1), f32(0))
	testing.expect_value(t, simulation_delta_time(1.0 / 60), f32(1.0 / 60))
	testing.expect_value(t, simulation_delta_time(2), MAX_SIMULATION_DELTA)
}

@(test)
test_timers_and_damping_agree_across_frame_rates :: proc(t: ^testing.T) {
	rates := [3]int{30, 60, 120}
	for rate in rates {
		dt := f32(1) / f32(rate)
		health := Health {
			is_dying        = true,
			hit_flash_timer = 0.2,
			knockback_timer = 0.3,
		}
		velocity := Vec2{100, -50}
		camera_remaining := f32(1)
		for frame in 0 ..< rate {
			health_update_timers(&health, dt)
			velocity = movement_apply_knockback_drag(velocity, dt)
			camera_remaining *= 1 - camera_follow_blend(dt)
		}
		testing.expect(t, abs(health.death_timer - 1) < 0.00001)
		testing.expect_value(t, health.hit_flash_timer, f32(0))
		testing.expect_value(t, health.knockback_timer, f32(0))
		expected := movement_apply_knockback_drag({100, -50}, 1)
		testing.expect(t, abs(velocity.x - expected.x) < 0.00001)
		testing.expect(t, abs(camera_remaining - (1 - camera_follow_blend(1))) < 0.00001)
	}
}
