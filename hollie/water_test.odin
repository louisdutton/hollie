package hollie

import "core:testing"

@(test)
test_water_entry_sinks_then_settles_without_ground_contact :: proc(t: ^testing.T) {
	body := Transform {
		vertical_velocity = -120,
	}
	collider := Collider {
		size = {2, 8, 2},
	}
	deepest := body.height
	for _ in 0 ..< 360 {
		body.vertical_velocity -= PHYSICS_GRAVITY * PHYSICS_STEP
		water_apply_buoyancy(&body, collider, PHYSICS_STEP)
		body.height += body.vertical_velocity * PHYSICS_STEP
		deepest = min(deepest, body.height)
	}
	equilibrium := WATER_SURFACE - min(WATER_DRAFT, collider.size.y * 0.55)
	testing.expect(t, abs(body.height - equilibrium) < 0.1)
	testing.expect(t, deepest < equilibrium - 1)
	testing.expect(t, !body.grounded && body.swimming)
	testing.expect(t, abs(body.vertical_velocity) < 0.1)
}

@(test)
test_buoyancy_changes_velocity_without_snapping_height :: proc(t: ^testing.T) {
	collider := Collider {
		size = {8, 20, 8},
	}
	body := Transform {
		height = WATER_SURFACE - 14,
	}
	before := body.height
	body.vertical_velocity -= PHYSICS_GRAVITY * PHYSICS_STEP
	water_apply_buoyancy(&body, collider, PHYSICS_STEP)
	testing.expect_value(t, body.height, before)
	testing.expect(t, body.vertical_velocity > 0 && body.swimming)
	body = Transform {
		height            = WATER_SURFACE + 1,
		vertical_velocity = -100,
	}
	water_apply_buoyancy(&body, collider, PHYSICS_STEP)
	testing.expect_value(t, body.vertical_velocity, f32(-100))
	testing.expect(t, !body.swimming)
}

@(test)
test_turtle_provides_water_speed_advantage :: proc(t: ^testing.T) {
	turtle := water_movement_profile(animal_riding_profile(.Turtle), true, true)
	player := water_movement_profile(PLAYER_MOVEMENT_PROFILE, true)
	horse := water_movement_profile(animal_riding_profile(.Horse), true)
	testing.expect(t, turtle.max_speed > player.max_speed)
	testing.expect(t, turtle.max_speed > horse.max_speed)
	testing.expect_value(
		t,
		water_movement_profile(PLAYER_MOVEMENT_PROFILE, false),
		PLAYER_MOVEMENT_PROFILE,
	)
}

@(test)
test_floating_crate_has_less_friction_and_eventually_stops :: proc(t: ^testing.T) {
	body := Transform {
		swimming = true,
		velocity = {100, 0},
	}
	land := Transform {
		grounded = true,
		velocity = {100, 0},
	}
	air := Transform {
		velocity = {100, 0},
	}
	for _ in 0 ..< 12 {
		physics_apply_friction(&body, CRATE_GROUND_FRICTION, PHYSICS_STEP)
		physics_apply_friction(&land, CRATE_GROUND_FRICTION, PHYSICS_STEP)
		physics_apply_friction(&air, CRATE_GROUND_FRICTION, PHYSICS_STEP)
	}
	testing.expect(t, body.velocity.x < 100 && body.velocity.x > land.velocity.x)
	testing.expect_value(t, air.velocity.x, f32(100))
	for _ in 0 ..< 360 do physics_apply_friction(&body, CRATE_GROUND_FRICTION, PHYSICS_STEP)
	testing.expect_value(t, body.velocity, Vec2{})
}
