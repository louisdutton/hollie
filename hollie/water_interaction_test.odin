package hollie

import "core:testing"

water_test_foam_bounds :: proc(position: Vec2) -> Aabb {
	return {
		min = {position.x - 5, WATER_SURFACE - 8, position.y - 5},
		max = {position.x + 5, WATER_SURFACE + 8, position.y + 5},
	}
}

@(test)
test_water_foam_tracks_connected_turns_and_keeps_idle_contact :: proc(t: ^testing.T) {
	state: Water_Foam_State
	body := Transform {
		position = {20, 20},
		velocity = {60, 0},
	}
	water_foam_track(&state, &body, water_test_foam_bounds(body.position), true)
	testing.expect_value(t, state.next, 0)
	body.position.x += 8
	water_foam_track(&state, &body, water_test_foam_bounds(body.position), true)
	testing.expect_value(t, state.next, 4)
	for i in 1 ..< state.next do testing.expect_value(t, state.trails[i].start, state.trails[i - 1].end)
	body.position.y += 6
	body.velocity = {0, 60}
	water_foam_track(&state, &body, water_test_foam_bounds(body.position), true)
	testing.expect_value(t, state.trails[4].start, Vec2{28, 20})
	testing.expect_value(t, state.trails[6].end, Vec2{28, 26})
	body.velocity = {}
	state.contact_count = 0
	water_foam_track(&state, &body, water_test_foam_bounds(body.position), true)
	testing.expect_value(t, state.next, 7)
	testing.expect_value(t, state.contact_count, 1)
	testing.expect_value(t, state.contacts[0].speed, f32(0))
}

@(test)
test_water_foam_does_not_bridge_exits_or_teleports :: proc(t: ^testing.T) {
	state: Water_Foam_State
	body := Transform {
		position = {20, 20},
		velocity = {60, 0},
	}
	water_foam_track(&state, &body, water_test_foam_bounds(body.position), true)
	water_foam_track(&state, &body, water_test_foam_bounds(body.position), false)
	body.position.x += 20
	water_foam_track(&state, &body, water_test_foam_bounds(body.position), true)
	testing.expect_value(t, state.next, 0)
	body.position.x += 100
	water_foam_track(&state, &body, water_test_foam_bounds(body.position), true)
	testing.expect_value(t, state.next, 0)
}

@(test)
test_water_foam_sampling_is_distance_based :: proc(t: ^testing.T) {
	slow, fast: Water_Foam_State
	rates := [2]int{30, 120}
	for rate in rates {
		state := rate == 30 ? &slow : &fast
		body := Transform {
			position = {20, 20},
			velocity = {60, 0},
		}
		for frame in 0 ..= rate {
			body.position.x = 20 + 60 * f32(frame) / f32(rate)
			water_foam_track(state, &body, water_test_foam_bounds(body.position), true)
		}
	}
	testing.expect_value(t, slow.next, fast.next)
	for trail, i in slow.trails {
		testing.expect_value(t, trail.start, fast.trails[i].start)
		testing.expect_value(t, trail.end, fast.trails[i].end)
	}
}
