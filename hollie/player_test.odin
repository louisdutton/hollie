package hollie

import "core:testing"

@(test)
test_player_drops_carried_item_in_front_of_facing_direction :: proc(t: ^testing.T) {
	crate := Holdable {
		collider = {size = {12, 12}, offset = {-6, -6}, solid = true},
	}
	player := Player {
		transform = {position = {40, 50}},
		collider = {size = {16, 16}, offset = {-8, -8}},
		movement = {facing_direction = {1, 0}},
		carrying = &crate,
	}
	crate.held_by = &player
	testing.expect(t, !holdable_blocks_character(crate))

	player_drop(&player)

	testing.expect_value(t, crate.position, Vec2{56, 50})
	testing.expect(t, crate.held_by == nil)
	testing.expect(t, holdable_blocks_character(crate))
	testing.expect(t, player.carrying == nil)

	diagonal_position := player_drop_position({40, 50}, {1, 1}, player.collider, crate.collider)
	testing.expect(t, diagonal_position.x > player.position.x)
	testing.expect(t, diagonal_position.y > player.position.y)
	testing.expect(
		t,
		!rects_intersect(
			collider_rect_at(player.position, player.collider),
			collider_rect_at(diagonal_position, crate.collider),
		),
		"a diagonal drop should clear the player's collision box",
	)
}
