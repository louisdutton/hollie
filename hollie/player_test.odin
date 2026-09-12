package hollie

import "core:testing"

@(test)
test_player_releases_carried_item_with_momentum_and_small_impulse :: proc(t: ^testing.T) {
	crate := Holdable {
		collider = {size = {12, 12, 12}, offset = {-6, 0, -6}, solid = true},
		held_offset = {2, 21, -1},
		held_pose_valid = true,
	}
	player := Player {
		transform = {
			position = {40, 50},
			velocity = {60, -20},
			height = 5,
			vertical_velocity = -10,
		},
		collider = {size = {16, 16, 16}, offset = {-8, 0, -8}},
		movement = {facing_direction = {1, 0}},
		carrying = &crate,
	}
	crate.held_by = &player
	testing.expect(t, !holdable_blocks_character(crate))

	player_drop(&player)

	testing.expect_value(t, crate.position, Vec2{42, 49})
	testing.expect_value(t, crate.height, f32(26))
	testing.expect_value(t, crate.velocity, Vec2{105, -20})
	testing.expect_value(t, crate.vertical_velocity, f32(5))
	testing.expect(t, !crate.grounded)
	testing.expect(t, crate.held_by == nil)
	testing.expect(t, holdable_blocks_character(crate))
	testing.expect(t, player.carrying == nil)

	diagonal_position := player_drop_position({40, 50}, {1, 1}, player.collider, crate.collider)
	testing.expect(t, diagonal_position.x > player.position.x)
	testing.expect(t, diagonal_position.y > player.position.y)
	testing.expect(
		t,
		!aabbs_intersect(
			collision_aabb_at(player.position, player.collider),
			collision_aabb_at(diagonal_position, crate.collider),
		),
		"a diagonal drop should clear the player's collision box",
	)
}
