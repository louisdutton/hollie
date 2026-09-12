package hollie

import "core:testing"

@(test)
test_movement_accelerates_caps_speed_and_stops :: proc(t: ^testing.T) {
	profiles := [2]Movement_Profile{PLAYER_MOVEMENT_PROFILE, RIDING_MOVEMENT_PROFILE}
	for profile in profiles {
		velocity := movement_accelerate({}, {1, 0}, profile, 0.1)
		testing.expect(t, velocity.x > 0 && velocity.x < profile.max_speed)
		for frame in 0 ..< 120 do velocity = movement_accelerate(velocity, {1, 0}, profile, 1.0 / 60)
		testing.expect_value(t, velocity.x, profile.max_speed)
		for frame in 0 ..< 120 do velocity = movement_accelerate(velocity, {}, profile, 1.0 / 60)
		testing.expect_value(t, velocity, Vec2{})
	}
}

@(test)
test_movement_analog_target_and_direction_reversal :: proc(t: ^testing.T) {
	profile := PLAYER_MOVEMENT_PROFILE
	velocity := movement_accelerate({}, {0.5, 0}, profile, 1)
	testing.expect_value(t, velocity.x, f32(50))
	velocity = movement_accelerate({80, 0}, {-1, 0}, profile, 0.1)
	testing.expect(t, velocity.x > 0 && velocity.x < 80)
	velocity = movement_accelerate(velocity, {-1, 0}, profile, 1)
	testing.expect_value(t, velocity, Vec2{-80, 0})
}

@(test)
test_movement_acceleration_is_time_based :: proc(t: ^testing.T) {
	a, b: Vec2
	for frame in 0 ..< 6 do a = movement_accelerate(a, {1, 0}, RIDING_MOVEMENT_PROFILE, 1.0 / 60)
	for frame in 0 ..< 12 do b = movement_accelerate(b, {1, 0}, RIDING_MOVEMENT_PROFILE, 1.0 / 120)
	testing.expect(t, abs(a.x - b.x) < 0.001)
	testing.expect(t, abs(a.x - 24) < 0.001)
}
