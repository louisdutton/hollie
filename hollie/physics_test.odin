package hollie

import "core:testing"

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
