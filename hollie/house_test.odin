package hollie

import "core:testing"

@(test)
test_house_walls_block_sides_and_leave_doorway_clear :: proc(t: ^testing.T) {
	walls := house_wall_aabbs({16, 0}, {96, 96})
	passage := AABB {
		min = {56, 0, 90},
		max = {72, 24, 100},
	}
	for wall in walls do testing.expect(t, !aabbs_intersect(passage, wall))
	testing.expect(t, aabbs_intersect(AABB{min = {14, 0, 40}, max = {18, 24, 48}}, walls[1]))
	testing.expect(t, aabbs_intersect(AABB{min = {20, 0, 94}, max = {28, 24, 100}}, walls[3]))
	testing.expect(t, aabbs_intersect(AABB{min = {56, 36, 94}, max = {72, 42, 100}}, walls[5]))
}
