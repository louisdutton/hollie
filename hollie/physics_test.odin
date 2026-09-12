package hollie

import "core:testing"

@(test)
test_ground_friction_stops_crate_on_platform :: proc(t: ^testing.T) {
	body := Transform {
		position = {5, 5},
		height   = 3,
		grounded = true,
		velocity = {60, 80},
	}
	collider := Collider {
		size   = {2, 4, 2},
		offset = {-1, 0, -1},
	}
	platform := [1]AABB{{min = {-100, 0, -100}, max = {100, 3, 100}}}
	for frame in 0 ..< 120 {
		physics_step(
			&body,
			collider,
			platform[:],
			PHYSICS_STEP,
			ground_friction = CRATE_GROUND_FRICTION,
		)
	}
	testing.expect_value(t, body.velocity, Vec2{})
	testing.expect_value(t, body.height, f32(3))
	stopped_position := body.position
	physics_step(
		&body,
		collider,
		platform[:],
		PHYSICS_STEP,
		ground_friction = CRATE_GROUND_FRICTION,
	)
	testing.expect_value(t, body.position, stopped_position)
}

@(test)
test_ground_friction_preserves_airborne_momentum :: proc(t: ^testing.T) {
	body := Transform {
		height   = 20,
		velocity = {60, -80},
	}
	collider := Collider {
		size = {2, 4, 2},
	}
	physics_step(&body, collider, nil, PHYSICS_STEP, ground_friction = CRATE_GROUND_FRICTION)
	testing.expect(t, !body.grounded)
	testing.expect_value(t, body.velocity, Vec2{60, -80})
}

@(test)
test_ground_friction_deceleration_is_independent_of_step_size :: proc(t: ^testing.T) {
	a := Transform {
		grounded = true,
		velocity = {60, 80},
	}
	b := a
	collider := Collider {
		size = {2, 4, 2},
	}
	for frame in 0 ..< 12 do physics_step(&a, collider, nil, 1.0 / 120, ground_friction = CRATE_GROUND_FRICTION)
	for frame in 0 ..< 6 do physics_step(&b, collider, nil, 1.0 / 60, ground_friction = CRATE_GROUND_FRICTION)
	testing.expect(t, abs(a.velocity.x - b.velocity.x) < 0.001)
	testing.expect(t, abs(a.velocity.y - b.velocity.y) < 0.001)
	testing.expect(t, abs(a.velocity.x - 38.4) < 0.001)
	testing.expect(t, abs(a.velocity.y - 51.2) < 0.001)
}

@(test)
test_physics_lands_on_platform_without_falling_through :: proc(t: ^testing.T) {
	body := Transform {
		position          = {5, 5},
		height            = 30,
		vertical_velocity = -500,
	}
	collider := Collider {
		size   = {2, 4, 2},
		offset = {-1, 0, -1},
	}
	obstacles := [1]AABB{{min = {0, 0, 0}, max = {10, 3, 10}}}
	physics_step(&body, collider, obstacles[:], 0.1)
	testing.expect_value(t, body.height, f32(3))
	testing.expect(t, body.grounded)
	testing.expect_value(t, body.vertical_velocity, f32(0))
	physics_step(&body, collider, obstacles[:], PHYSICS_STEP)
	testing.expect_value(t, body.height, f32(3))
}

@(test)
test_physics_jump_requires_ground_and_returns_to_platform :: proc(t: ^testing.T) {
	body := Transform {
		position = {5, 5},
		height   = 3,
		grounded = true,
	}
	collider := Collider {
		size   = {2, 4, 2},
		offset = {-1, 0, -1},
	}
	obstacles := [1]AABB{{min = {0, 0, 0}, max = {10, 3, 10}}}
	physics_jump(&body)
	testing.expect(t, !body.grounded)
	physics_step(&body, collider, obstacles[:], PHYSICS_STEP)
	testing.expect(t, body.height > 3)
	speed := body.vertical_velocity
	physics_jump(&body)
	testing.expect_value(t, body.vertical_velocity, speed)
	for frame in 0 ..< 120 do physics_step(&body, collider, obstacles[:], PHYSICS_STEP)
	testing.expect(t, body.grounded)
	testing.expect_value(t, body.height, f32(3))
}

@(test)
test_physics_steps_onto_low_platform_but_blocks_tall_wall :: proc(t: ^testing.T) {
	collider := Collider {
		size   = {2, 4, 2},
		offset = {-1, 0, -1},
	}
	low := [1]AABB{{min = {2, 0, -5}, max = {10, 4, 5}}}
	body := Transform {
		grounded = true,
		velocity = {120, 0},
	}
	physics_step(&body, collider, low[:], PHYSICS_STEP)
	physics_step(&body, collider, low[:], PHYSICS_STEP)
	testing.expect_value(t, body.position.x, f32(2))
	testing.expect_value(t, body.height, f32(4))
	testing.expect(t, body.grounded)
	tall := [1]AABB{{min = {2, 0, -5}, max = {10, 20, 5}}}
	body = {
		grounded = true,
		velocity = {120, 0},
	}
	physics_step(&body, collider, tall[:], PHYSICS_STEP)
	physics_step(&body, collider, tall[:], PHYSICS_STEP)
	testing.expect_value(t, body.position.x, f32(1))
	testing.expect_value(t, body.height, f32(0))
}

@(test)
test_physics_falls_off_edges_and_hits_ceiling :: proc(t: ^testing.T) {
	collider := Collider {
		size   = {2, 4, 2},
		offset = {-1, 0, -1},
	}
	body := Transform {
		position = {20, 20},
		height   = 6,
		grounded = true,
	}
	physics_step(&body, collider, nil, PHYSICS_STEP)
	testing.expect(t, !body.grounded && body.height < 6)
	body = {
		grounded = true,
	}
	ceiling := [1]AABB{{min = {-10, 6, -10}, max = {10, 8, 10}}}
	physics_jump(&body)
	physics_step(&body, collider, ceiling[:], 0.05)
	testing.expect_value(t, body.height, f32(2))
	testing.expect_value(t, body.vertical_velocity, f32(0))
}
