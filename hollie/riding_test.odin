package hollie

import "content"
import "core:testing"
import "graphics"

@(test)
test_animals_can_be_mounted_only_when_available_and_grounded :: proc(t: ^testing.T) {
	player := Player {
		transform = {grounded = true},
		collider = {size = {2, 4, 2}},
	}
	animal := Enemy {
		transform = {grounded = true},
		collider = {size = {4, 6, 4}},
	}
	kinds := [3]content.Character_Kind{.Dog, .Horse, .Bison}
	for kind in kinds {
		animal.kind = kind
		testing.expect(t, riding_can_mount(&player, &animal))
	}
	animal.mounted = true
	testing.expect(t, !riding_can_mount(&player, &animal))
	animal.mounted = false
	animal.grounded = false
	testing.expect(t, !riding_can_mount(&player, &animal))
	animal.grounded = true
	player.grounded = false
	testing.expect(t, !riding_can_mount(&player, &animal))
	player.grounded = true
	crate: Holdable
	player.carrying = &crate
	testing.expect(t, !riding_can_mount(&player, &animal))
	player.carrying = nil
	animal.kind = .Goblin
	testing.expect(t, !riding_can_mount(&player, &animal))
	animal.kind = .Dog
	animal.position = {100, 100}
	testing.expect(t, !riding_can_mount(&player, &animal))
}

@(test)
test_rider_seat_rotates_with_animal_facing :: proc(t: ^testing.T) {
	seat := Vec3{-2, 9, 0}
	forward := riding_seat_offset({0, 1}, seat, 2)
	right := riding_seat_offset({1, 0}, seat, 2)
	testing.expect(t, abs(forward.x) < 0.001 && abs(forward.z - 2) < 0.001)
	testing.expect(t, abs(right.x - 2) < 0.001 && abs(right.z) < 0.001)
	testing.expect_value(t, forward.y, f32(7))
}

@(test)
test_ridden_animal_collider_includes_rider_headroom :: proc(t: ^testing.T) {
	animal := Enemy {
		collider = {size = {10, 10, 10}, offset = {-5, 0, -5}},
		movement = {facing_direction = {0, 1}},
	}
	rider := Collider {
		size   = {4, 6, 4},
		offset = {-2, 0, -2},
	}
	combined := riding_combined_collider(&animal, rider, {0, 9, 0}, 2)
	ceiling := AABB {
		min = {-10, 12, -10},
		max = {10, 15, 10},
	}
	testing.expect(t, !aabbs_intersect(collision_aabb_at({}, animal.collider), ceiling))
	testing.expect(t, aabbs_intersect(collision_aabb_at({}, combined), ceiling))
	testing.expect_value(t, combined.size.y, f32(13))
}

@(test)
test_dismount_chooses_clear_side_and_rejects_enclosed_animal :: proc(t: ^testing.T) {
	player := Player {
		collider = {size = {2, 4, 2}, offset = {-1, 0, -1}},
	}
	animal := Enemy {
		transform = {position = {20, 20}, grounded = true},
		collider = {size = {10, 10, 10}, offset = {-5, 0, -5}},
		movement = {facing_direction = {0, 1}},
	}
	obstacles := [2]AABB {
		collision_aabb_at(animal.position, animal.collider),
		{min = {26, 0, 15}, max = {30, 20, 25}},
	}
	position, height, ok := riding_find_dismount(
		&player,
		&animal,
		obstacles[:],
		graphics.Rect{0, 0, 40, 40},
	)
	testing.expect(t, ok)
	testing.expect(t, position.x < animal.position.x)
	testing.expect_value(t, height, f32(0))
	_, _, enclosed := riding_find_dismount(
		&player,
		&animal,
		obstacles[:],
		graphics.Rect{15, 15, 10, 10},
	)
	testing.expect(t, !enclosed)
}
