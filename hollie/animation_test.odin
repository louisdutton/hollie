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
