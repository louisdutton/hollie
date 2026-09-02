package hollie

import "core:testing"
import rl "vendor:raylib"

@(test)
test_world_3d_maps_gameplay_y_to_depth :: proc(t: ^testing.T) {
	testing.expect_value(t, world_3d_position({24, 48}), rl.Vector3{24, 0, 48})
	testing.expect_value(t, world_3d_position({24, 48}, 7), rl.Vector3{24, 7, 48})
}

@(test)
test_world_3d_pose_uses_existing_animation_frames :: proc(t: ^testing.T) {
	frame_counts := []int{9, 8, 10, 13, 10, 10, 8}
	anim := Animator {
		frame_counts = frame_counts,
		frame        = 4,
		current_anim = .JUMP,
	}
	jump_pose := world_3d_character_pose(&anim)
	testing.expect_value(t, jump_pose.height, f32(13))

	anim.current_anim = .ROLL
	anim.frame = 5
	roll_pose := world_3d_character_pose(&anim)
	testing.expect_value(t, roll_pose.angle, f32(180))
}
