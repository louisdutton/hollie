package hollie

import "core:testing"

@(test)
test_door_spawn_candidates_use_floor_footprint_and_clear_trigger :: proc(t: ^testing.T) {
	door := AABB {
		min = {48, 0, 128},
		max = {80, 18, 144},
	}
	player := Collider {
		size   = {16, 40, 16},
		offset = {-8, 0, -8},
	}
	candidates := room_door_spawn_candidates(door, player, true)
	testing.expect_value(t, candidates[0], Vec2{64, 118})
	for candidate in candidates {
		testing.expect(t, !aabbs_intersect(collision_aabb_at(candidate, player), door))
	}
	testing.expect(
		t,
		!aabbs_intersect(
			collision_aabb_at(candidates[0], player),
			collision_aabb_at(candidates[1], player),
		),
	)
}

@(test)
test_exterior_has_two_spawns_in_front_of_house_despite_pressure_plate :: proc(t: ^testing.T) {
	door := AABB {
		min = {48, 0, 80},
		max = {80, 18, 96},
	}
	player := Collider {
		size   = {16, 22.4, 16},
		offset = {-8, 0, -8},
	}
	plate := AABB {
		min = {64, 0, 112},
		max = {96, 5, 144},
	}
	candidates := room_door_spawn_candidates(door, player, false)
	occupied: AABB
	count := 0
	for candidate in candidates[:5] {
		aabb := collision_aabb_at(candidate, player)
		if aabbs_intersect(aabb, plate) do continue
		if count > 0 && aabbs_intersect(aabb, occupied) do continue
		testing.expect(t, aabb.min.z > 96)
		testing.expect(t, !aabbs_intersect(aabb, door))
		occupied = aabb
		count += 1
		if count == 2 do break
	}
	testing.expect_value(t, count, 2)
}
