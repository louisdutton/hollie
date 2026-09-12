package hollie

import "core:testing"

@(test)
test_animation_tracks_visual_elapsed_time :: proc(t: ^testing.T) {
	animator: Animator
	animation_init(&animator)
	animation_update(&animator, 0.125)
	testing.expect_value(t, animator.visual_time, f32(0.125))
	animation_set_state(&animator, .Run)
	testing.expect_value(t, animator.visual_time, f32(0))
	testing.expect_value(t, animator.previous_anim, Animation_State.Idle)
	testing.expect_value(t, animator.previous_time, f32(0.125))
	testing.expect_value(t, animator.blend_elapsed, f32(0))
}

@(test)
test_animation_playback_modes_normalize_frames_before_rendering :: proc(t: ^testing.T) {
	testing.expect_value(t, animation_frame_at_time(0.1, 21, .Loop), f32(6))
	testing.expect_value(t, animation_frame_at_time(0.4, 21, .Loop), f32(4))
	testing.expect_value(t, animation_frame_at_time(0.4, 21, .Once_Hold), f32(19))
	testing.expect_value(t, animation_frame_at_time(10, 1, .Once_Hold), f32(0))
}

@(test)
test_animation_elapsed_time_agrees_across_frame_rates :: proc(t: ^testing.T) {
	rates := [3]int{30, 60, 120}
	for rate in rates {
		animator: Animator
		animation_init(&animator)
		animation_set_state(&animator, .Run)
		for frame in 0 ..< rate do animation_update(&animator, f32(1) / f32(rate))
		testing.expect(t, abs(animator.visual_time - 1) < 0.00001)
		testing.expect(t, abs(animator.blend_elapsed - 1) < 0.00001)
		animation_set_state(&animator, .Jump)
		testing.expect(t, abs(animator.previous_time - 1) < 0.00001)
		testing.expect_value(t, animator.visual_time, f32(0))
	}
}
