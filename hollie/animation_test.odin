package hollie

import "core:testing"

@(test)
test_animation_init_copies_logical_frame_counts :: proc(t: ^testing.T) {
	animations := [2]Animation{{frame_count = 9}, {frame_count = 8}}
	animator: Animator
	animation_init(&animator, animations[:])
	defer animation_fini(&animator)

	testing.expect_value(t, len(animator.frame_counts), 2)
	testing.expect_value(t, animator.frame_counts[0], 9)
	testing.expect_value(t, animator.frame_counts[1], 8)
}

@(test)
test_animation_tracks_visual_elapsed_time :: proc(t: ^testing.T) {
	animator := Animator {
		frame_counts = []int{9},
	}
	animation_update(&animator, 0.125)
	testing.expect_value(t, animator.visual_time, f32(0.125))
	animation_set_state(&animator, .RUN)
	testing.expect_value(t, animator.visual_time, f32(0))
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
