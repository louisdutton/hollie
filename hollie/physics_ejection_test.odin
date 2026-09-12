package hollie

import "core:testing"
import "graphics"

@(test)
test_closing_gate_pushes_body_to_nearest_clear_side :: proc(t: ^testing.T) {
	body := Transform {
		position = {4.5, 5},
		velocity = {20, 10},
		grounded = true,
	}
	collider := Collider {
		size   = {2, 4, 2},
		offset = {-1, 0, -1},
	}
	gate := AABB {
		min = {4, 0, 2},
		max = {6, 10, 8},
	}
	obstacles := [1]AABB{gate}
	testing.expect(
		t,
		physics_eject(&body, collider, gate, obstacles[:], graphics.Rect{0, 0, 10, 10}),
	)
	testing.expect(t, body.position.x < 3)
	testing.expect_value(t, body.position.y, f32(5))
	testing.expect_value(t, body.velocity.x, f32(0))
	testing.expect_value(t, body.velocity.y, f32(10))
	testing.expect(
		t,
		!aabbs_intersect(collision_aabb_at(body.position, collider, body.height), gate),
	)
}

@(test)
test_closing_gate_avoids_blocked_side :: proc(t: ^testing.T) {
	body := Transform {
		position = {4.5, 5},
	}
	collider := Collider {
		size   = {2, 4, 2},
		offset = {-1, 0, -1},
	}
	gate := AABB {
		min = {4, 0, 2},
		max = {6, 10, 8},
	}
	obstacles := [2]AABB{gate, {min = {0, 0, 0}, max = {3.5, 20, 10}}}
	testing.expect(
		t,
		physics_eject(&body, collider, gate, obstacles[:], graphics.Rect{0, 0, 10, 10}),
	)
	testing.expect(t, body.position.x > 7)
	for obstacle in obstacles {
		testing.expect(
			t,
			!aabbs_intersect(collision_aabb_at(body.position, collider, body.height), obstacle),
		)
	}
}

@(test)
test_closing_gate_lifts_body_only_with_headroom :: proc(t: ^testing.T) {
	body := Transform {
		position = {5, 5},
	}
	collider := Collider {
		size   = {2, 4, 2},
		offset = {-1, 0, -1},
	}
	gate := AABB {
		min = {4, 0, 4},
		max = {6, 10, 6},
	}
	obstacles := [2]AABB{gate, {min = {4, 10, 4}, max = {6, 20, 6}}}
	bounds := graphics.Rect{4, 4, 2, 2}
	before := body
	testing.expect(t, !physics_eject(&body, collider, gate, obstacles[:], bounds))
	testing.expect_value(t, body.position, before.position)
	testing.expect_value(t, body.height, before.height)
	testing.expect(t, physics_eject(&body, collider, gate, obstacles[:1], bounds))
	testing.expect(t, body.height > 10)
}

@(test)
test_closing_gate_does_not_move_body_above_it :: proc(t: ^testing.T) {
	body := Transform {
		position          = {5, 5},
		height            = 12,
		vertical_velocity = -20,
	}
	collider := Collider {
		size   = {2, 4, 2},
		offset = {-1, 0, -1},
	}
	gate := AABB {
		min = {4, 0, 4},
		max = {6, 10, 6},
	}
	obstacles := [1]AABB{gate}
	testing.expect(
		t,
		physics_eject(&body, collider, gate, obstacles[:], graphics.Rect{0, 0, 10, 10}),
	)
	testing.expect_value(t, body.position, Vec2{5, 5})
	testing.expect_value(t, body.height, f32(12))
	testing.expect_value(t, body.vertical_velocity, f32(-20))
}
