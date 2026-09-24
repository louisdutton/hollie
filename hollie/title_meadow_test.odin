package hollie

import "core:testing"
import "graphics"

@(test)
test_title_meadow_uses_shared_grass_geometry_without_a_room :: proc(t: ^testing.T) {
	builder: Grass_Mesh_Builder
	defer delete(builder.positions)
	defer delete(builder.roots)
	defer delete(builder.colors)
	defer delete(builder.indices)
	grass_build_patch(&builder, -2, -3, 32, 40, 1, true)
	testing.expect_value(t, len(builder.positions), 4 + 36 * 5)
	testing.expect_value(t, len(builder.indices), 6 + 36 * 18)
	testing.expect_value(t, len(builder.roots), len(builder.positions))
	for index in builder.indices do testing.expect(t, int(index) < len(builder.positions))
	for root in builder.roots {
		testing.expect(t, root.x >= -64 && root.x <= -32)
		testing.expect(t, root.y >= -96 && root.y <= -64)
	}
	clear(&builder.positions)
	clear(&builder.roots)
	clear(&builder.colors)
	clear(&builder.indices)
	grass_build_patch(&builder, 0, 0, 32, 40, 0, true)
	testing.expect_value(t, len(builder.positions), 4)
}

@(test)
test_title_meadow_camera_is_low_and_perspective :: proc(t: ^testing.T) {
	view := title_meadow_camera()
	testing.expect_value(t, view.projection, graphics.Camera_Projection.PERSPECTIVE)
	testing.expect(t, view.position.y - view.target.y < (view.position.z - view.target.z) * 0.1)
	testing.expect(t, view.fovy >= 40 && view.fovy <= 60)
}
