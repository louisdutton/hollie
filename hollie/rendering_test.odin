package hollie

import "core:math"
import "core:testing"
import "graphics"

@(test)
test_rendering_maps_gameplay_y_to_depth :: proc(t: ^testing.T) {
	testing.expect_value(t, geometry_position({24, 48}), graphics.Vec3{24, 0, 48})
	testing.expect_value(t, geometry_position({24, 48}, 7), graphics.Vec3{24, 7, 48})
}

@(test)
test_rendering_derives_grounded_box_colliders_from_model_bounds :: proc(t: ^testing.T) {
	crate := geometry_collider_from_bounds(
		{min = {-0.25, 0, -0.25}, max = {0.25, 0.5, 0.25}},
		24,
		false,
		false,
	)
	testing.expect_value(t, crate.size, graphics.Vec3{12, 12, 12})
	testing.expect_value(t, crate.offset, graphics.Vec3{-6, 0, -6})

	character := geometry_collider_from_bounds(
		{min = {-0.25, 0, -0.1}, max = {0.25, 0.7, 0.1}},
		32,
		true,
		true,
	)
	testing.expect_value(t, character.size.x, f32(16))
	testing.expect(t, math.abs(character.size.y - 22.4) < 0.001)
	testing.expect_value(t, character.size.z, f32(16))
	testing.expect_value(t, character.offset, graphics.Vec3{-8, 0, -8})

	position := geometry_grounded_position({3, 4}, {min = {-1, -0.5, -1}, max = {1, 1, 1}}, 10, 2)
	testing.expect_value(t, position, graphics.Vec3{3, 7, 4})
}

@(test)
test_collider_box_respects_mesh_derived_offset :: proc(t: ^testing.T) {
	collider := Collider {
		size   = {12, 5, 8},
		offset = {-6, 0, -2},
	}
	testing.expect_value(
		t,
		collision_box_at({10, 20}, collider),
		Collision_Box{min = {4, 0, 18}, max = {16, 5, 26}},
	)
}

@(test)
test_collision_boxes_require_vertical_overlap :: proc(t: ^testing.T) {
	grounded := Collision_Box {
		min = {0, 0, 0},
		max = {10, 2, 10},
	}
	above := Collision_Box {
		min = {0, 3, 0},
		max = {10, 5, 10},
	}
	overlapping := Collision_Box {
		min = {5, 1, 5},
		max = {15, 4, 15},
	}

	testing.expect(t, !boxes_intersect(grounded, above))
	testing.expect(t, boxes_intersect(grounded, overlapping))
}

@(test)
test_rendering_facing_uses_full_movement_direction :: proc(t: ^testing.T) {
	testing.expect(t, math.abs(geometry_facing_angle({1, 0}) - 90) < 0.001)
	testing.expect(t, math.abs(geometry_facing_angle({-1, 0}) + 90) < 0.001)
	testing.expect(t, math.abs(math.abs(geometry_facing_angle({0, -1})) - 180) < 0.001)
}

@(test)
test_rendering_one_shot_clip_holds_its_final_frame :: proc(t: ^testing.T) {
	clip := graphics.Model_Animation {
		keyframeCount = 21,
	}
	testing.expect_value(t, model_animation_frame(1, clip, .Once_Hold), f32(19))
	testing.expect_value(t, model_animation_frame(1, clip, .Loop), f32(0))
}

@(test)
test_rendering_text_scales_with_the_display :: proc(t: ^testing.T) {
	testing.expect_value(t, rendering_scaled_text_size(12, 1), 12)
	testing.expect_value(t, rendering_scaled_text_size(12, 2.4), 29)
}
