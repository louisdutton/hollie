package hollie

import "core:testing"
import "graphics"

@(test)
test_animal_collider_preserves_width_and_rotates_with_facing :: proc(t: ^testing.T) {
	bounds := graphics.Bounding_Box {
		min = {-0.5, 0, -0.125},
		max = {0.5, 0.5, 0.125},
	}
	forward := animal_collider_from_bounds(bounds, {0, 1})
	sideways := animal_collider_from_bounds(bounds, {1, 0})
	testing.expect(t, abs(forward.size.x - 8) < 0.001)
	testing.expect(t, abs(forward.size.z - 32) < 0.001)
	testing.expect(t, abs(sideways.size.x - 32) < 0.001)
	testing.expect(t, abs(sideways.size.z - 8) < 0.001)
	testing.expect_value(t, forward.size.y, f32(16))
}

@(test)
test_animal_gait_blends_through_standing_walk_and_run :: proc(t: ^testing.T) {
	speeds := [5]f32{0, 25, 50, 105, 160}
	blends := [5]f32{0, 0.5, 1, 0.5, 1}
	for speed, i in speeds {
		walking, blend := animal_gait_blend(speed)
		testing.expect_value(t, walking, i <= 2)
		testing.expect_value(t, blend, blends[i])
	}
	_, blend := animal_gait_blend(200)
	testing.expect_value(t, blend, f32(1))
}

@(test)
test_animal_stride_is_time_based_and_pauses_when_idle_or_airborne :: proc(t: ^testing.T) {
	a := Enemy {
		transform = {grounded = true, velocity = {105, 0}},
	}
	b := a
	for frame in 0 ..< 6 do animal_update_gait(&a, 1.0 / 60)
	for frame in 0 ..< 12 do animal_update_gait(&b, 1.0 / 120)
	testing.expect(t, abs(a.gait_phase - b.gait_phase) < 0.0001)
	phase := a.gait_phase
	a.grounded = false
	animal_update_gait(&a, 0.1)
	testing.expect_value(t, a.gait_phase, phase)
	a.grounded = true
	a.velocity = {}
	animal_update_gait(&a, 0.1)
	testing.expect_value(t, a.gait_phase, phase)
}
