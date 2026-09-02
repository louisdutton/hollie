package hollie

import "core:testing"
import rl "vendor:raylib"

@(test)
test_animation_source_and_world_geometry_are_independent :: proc(t: ^testing.T) {
	animator := Animator {
		rect = {128, 0, 128, 96},
		profile = {source_frame_size = {128, 96}, world_size = {32, 24}, anchor = {0.5, 0.75}},
	}

	testing.expect_value(t, animation_source_rect(&animator), rl.Rectangle{128, 0, 128, 96})
	testing.expect_value(
		t,
		animation_destination_rect(&animator, {100, 80}),
		rl.Rectangle{84, 62, 32, 24},
	)

	animator.is_flipped = true
	testing.expect_value(t, animation_source_rect(&animator), rl.Rectangle{128, 0, -128, 96})
}

@(test)
test_prototype_characters_retain_original_animation_frames :: proc(t: ^testing.T) {
	testing.expect_value(t, len(goblin_animations), 4)
	testing.expect_value(t, goblin_animations[0].frame_count, 9)
	testing.expect_value(t, goblin_animations[1].frame_count, 8)
	testing.expect_value(t, goblin_animations[2].frame_count, 9)
	testing.expect_value(t, goblin_animations[3].frame_count, 13)

	testing.expect_value(t, len(skeleton_animations), 4)
	testing.expect_value(t, skeleton_animations[0].frame_count, 6)
	testing.expect_value(t, skeleton_animations[1].frame_count, 8)
	testing.expect_value(t, skeleton_animations[2].frame_count, 10)
	testing.expect_value(t, skeleton_animations[3].frame_count, 10)

	testing.expect_value(t, len(human_animations), 6)
	testing.expect_value(t, len(player_animations), 7)
	testing.expect_value(t, player_animations[4].frame_count, 10)
	testing.expect_value(t, player_animations[5].frame_count, 10)
	testing.expect_value(t, player_animations[6].frame_count, 8)
}
