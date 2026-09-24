package hollie

import "core:math"

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
	entity_id:               Entity_Id,
	position:                Vec2,
	velocity:                Vec2,
	height:                  f32,
	vertical_velocity:       f32,
	grounded:                bool,
	swimming:                bool,
	water_previous_position: Vec2,
	water_previous_depth:    f32,
	water_contact_valid:     bool,
	dust_distance:           f32,
}

Movement :: struct {
	move_speed:       f32,
	facing_direction: Vec2,
	is_busy:          bool,
}

// Equivalent to retaining 85% of knockback velocity per update at 60 Hz.
movement_apply_knockback_drag :: proc(velocity: Vec2, dt: f32) -> Vec2 {
	return velocity * math.pow(f32(0.85), max(dt, 0) * 60)
}
