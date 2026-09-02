package hollie

import "core:math"
import "core:testing"
import rl "vendor:raylib"

@(test)
test_world_3d_maps_gameplay_y_to_depth :: proc(t: ^testing.T) {
	testing.expect_value(t, world_3d_position({24, 48}), rl.Vector3{24, 0, 48})
	testing.expect_value(t, world_3d_position({24, 48}, 7), rl.Vector3{24, 7, 48})
}

@(test)
test_world_3d_facing_uses_full_movement_direction :: proc(t: ^testing.T) {
	testing.expect(t, math.abs(world_3d_facing_angle({1, 0}) - 90) < 0.001)
	testing.expect(t, math.abs(world_3d_facing_angle({-1, 0}) + 90) < 0.001)
	testing.expect(t, math.abs(math.abs(world_3d_facing_angle({0, -1})) - 180) < 0.001)
}

@(test)
test_world_3d_one_shot_clip_holds_its_final_frame :: proc(t: ^testing.T) {
	clip := rl.ModelAnimation{keyframeCount = 21}
	testing.expect_value(t, world_3d_clip_frame(1, clip, false), f32(20))
	testing.expect_value(t, world_3d_clip_frame(1, clip, true), f32(60))
}

@(test)
test_every_character_state_maps_to_a_native_kenney_clip :: proc(t: ^testing.T) {
	testing.expect_value(t, WORLD_3D_CHARACTER_CLIP_NAMES[int(AnimationState.IDLE)], "idle")
	testing.expect_value(t, WORLD_3D_CHARACTER_CLIP_NAMES[int(AnimationState.RUN)], "walk")
	testing.expect_value(t, WORLD_3D_CHARACTER_CLIP_NAMES[int(AnimationState.JUMP)], "sprint")
	testing.expect_value(t, WORLD_3D_CHARACTER_CLIP_NAMES[int(AnimationState.DEATH)], "die")
	testing.expect_value(
		t,
		WORLD_3D_CHARACTER_CLIP_NAMES[int(AnimationState.ATTACK)],
		"attack-melee-right",
	)
	testing.expect_value(t, WORLD_3D_CHARACTER_CLIP_NAMES[int(AnimationState.ROLL)], "sprint")
	testing.expect_value(
		t,
		WORLD_3D_CHARACTER_CLIP_NAMES[int(AnimationState.CARRY)],
		"walk-holding-both",
	)
}
