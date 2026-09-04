package hollie

import "core:math"
import "core:testing"
import "renderer"
import rl "vendor:raylib"

@(test)
test_world_3d_maps_gameplay_y_to_depth :: proc(t: ^testing.T) {
	testing.expect_value(t, world_3d_position({24, 48}), rl.Vector3{24, 0, 48})
	testing.expect_value(t, world_3d_position({24, 48}, 7), rl.Vector3{24, 7, 48})
}

@(test)
test_world_3d_derives_grounded_box_colliders_from_model_bounds :: proc(t: ^testing.T) {
	crate := world_3d_collider_from_bounds(
		{min = {-0.25, 0, -0.25}, max = {0.25, 0.5, 0.25}},
		24,
		false,
		false,
	)
	testing.expect_value(t, crate.size, Vec2{12, 12})
	testing.expect_value(t, crate.offset, Vec2{-6, -6})
	testing.expect_value(t, crate.height, f32(12))

	character := world_3d_collider_from_bounds(
		{min = {-0.25, 0, -0.1}, max = {0.25, 0.7, 0.1}},
		32,
		true,
		true,
	)
	testing.expect_value(t, character.size, Vec2{16, 16})
	testing.expect_value(t, character.offset, Vec2{-8, -8})
	testing.expect(t, math.abs(character.height - 22.4) < 0.001)

	position := world_3d_grounded_position({3, 4}, {min = {-1, -0.5, -1}, max = {1, 1, 1}}, 10, 2)
	testing.expect_value(t, position, rl.Vector3{3, 7, 4})
}

@(test)
test_collider_rectangle_respects_mesh_derived_offset :: proc(t: ^testing.T) {
	collider := Collider {
		size   = {12, 8},
		offset = {-6, -2},
	}
	testing.expect_value(t, collider_rect_at({10, 20}, collider), renderer.Rect{4, 18, 12, 8})
}

@(test)
test_world_3d_facing_uses_full_movement_direction :: proc(t: ^testing.T) {
	testing.expect(t, math.abs(world_3d_facing_angle({1, 0}) - 90) < 0.001)
	testing.expect(t, math.abs(world_3d_facing_angle({-1, 0}) + 90) < 0.001)
	testing.expect(t, math.abs(math.abs(world_3d_facing_angle({0, -1})) - 180) < 0.001)
}

@(test)
test_world_3d_one_shot_clip_holds_its_final_frame :: proc(t: ^testing.T) {
	clip := rl.ModelAnimation {
		keyframeCount = 21,
	}
	testing.expect_value(t, world_3d_clip_frame(1, clip, .Once_Hold), f32(19))
	testing.expect_value(t, world_3d_clip_frame(1, clip, .Loop), f32(0))
}

@(test)
test_world_3d_text_scales_with_the_display :: proc(t: ^testing.T) {
	testing.expect_value(t, world_3d_scaled_text_size(12, 1), 12)
	testing.expect_value(t, world_3d_scaled_text_size(12, 2.4), 29)
}
