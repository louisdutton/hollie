package hollie

import "core:math"
import "core:testing"

@(test)
test_water_shore_continues_around_diagonal_land :: proc(t: ^testing.T) {
	tiles := [9]bool{false, true, true, true, true, true, true, true, true}
	// The centre water tile has no land edge, but must still see the land corner.
	distance := water_shore_distance(tiles[:], 3, 3, {1.25, 1.25})
	testing.expect(t, abs(distance - math.sqrt(f32(0.125))) < 0.0001)
	left := water_shore_distance(tiles[:], 3, 3, {0.9999, 1.5})
	right := water_shore_distance(tiles[:], 3, 3, {1.0001, 1.5})
	testing.expect(t, abs(left - right) < 0.0001)
}

@(test)
test_water_shore_preserves_room_edges_and_open_water :: proc(t: ^testing.T) {
	tiles := [9]bool{true, true, true, true, true, true, true, true, true}
	testing.expect_value(t, water_shore_distance(tiles[:], 3, 3, {0, 1.5}), f32(0))
	testing.expect_value(t, water_shore_distance(tiles[:], 3, 3, {3, 1.5}), f32(0))
	testing.expect_value(t, water_shore_distance(tiles[:], 3, 3, {0.25, 1.5}), f32(0.25))
	testing.expect_value(t, water_shore_distance(tiles[:], 3, 3, {1.5, 1.5}), f32(1))
	// Editing a neighbouring water tile into land immediately changes the field.
	tiles[3] = false
	testing.expect_value(t, water_shore_distance(tiles[:], 3, 3, {1.5, 1.5}), f32(0.5))
}
