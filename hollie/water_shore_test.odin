package hollie

import "core:testing"

shoreline_test_area :: proc(polygon: Shoreline_Polygon) -> f32 {
	area: f32
	for i in 0 ..< polygon.count {
		a, b := polygon.vertices[i], polygon.vertices[(i + 1) % polygon.count]
		area += a.x * b.y - b.x * a.y
	}
	return abs(area) * 0.5
}

@(test)
test_shoreline_clipping_partitions_every_triangle :: proc(t: ^testing.T) {
	for mask in 0 ..< 8 {
		triangle := [3]Shoreline_Vertex {
			{{0, 0}, mask & 1 != 0 ? 1 : -1},
			{{0, 1}, mask & 2 != 0 ? 1 : -1},
			{{1, 1}, mask & 4 != 0 ? 1 : -1},
		}
		land, water := shoreline_clip(triangle, false), shoreline_clip(triangle, true)
		testing.expect(
			t,
			abs(shoreline_test_area(land) + shoreline_test_area(water) - 0.5) < 0.00001,
		)
		segment, valid := shoreline_segment(triangle)
		testing.expect_value(t, valid, mask != 0 && mask != 7)
		if valid {
			delta := segment.b - segment.a
			for vertex in triangle {
				if vertex.value <= 0 do continue
				to_water := vertex.position - segment.a
				testing.expect(t, delta.y * to_water.x - delta.x * to_water.y >= 0)
			}
			for point in ([2]Vec2{segment.a, segment.b}) {
				for polygon in ([2]Shoreline_Polygon{land, water}) {
					found := false
					for i in 0 ..< polygon.count do found = found || polygon.vertices[i] == point
					testing.expect(t, found)
				}
			}
		}
	}
}

@(test)
test_shoreline_rounds_corners_and_preserves_tile_centres :: proc(t: ^testing.T) {
	tiles := [9]bool{false, false, false, false, true, false, false, false, false}
	field := shoreline_field_build(tiles[:], 3, 3, 32)
	defer delete(field.values)
	testing.expect(t, shoreline_field_at(&field, {33, 33}) < 0)
	testing.expect(t, shoreline_field_at(&field, {48, 48}) > 0)
	for y in 0 ..< 3 {
		for x in 0 ..< 3 {
			testing.expect_value(
				t,
				shoreline_field_at(&field, Vec2{f32(x) + 0.5, f32(y) + 0.5} * 32) > 0,
				tiles[y * 3 + x],
			)
		}
	}
	// Source edits cannot mutate this load's cached field.
	tiles[4] = false
	testing.expect(t, shoreline_field_at(&field, {48, 48}) > 0)
	// Grid sampling and queries agree at interior points of generated triangles.
	triangle := [3]Shoreline_Vertex {
		shoreline_vertex(&field, 9, 9),
		shoreline_vertex(&field, 9, 10),
		shoreline_vertex(&field, 10, 10),
	}
	center := (triangle[0].position + triangle[1].position + triangle[2].position) / 3
	testing.expect(
		t,
		abs(
			shoreline_field_at(&field, center) -
			(triangle[0].value + triangle[1].value + triangle[2].value) / 3,
		) <
		0.00001,
	)
}

@(test)
test_shoreline_preserves_channels_islands_and_separates_diagonal_pools :: proc(t: ^testing.T) {
	channel := [9]bool{false, true, false, false, true, false, false, true, false}
	island := [9]bool{true, true, true, true, false, true, true, true, true}
	for tiles in ([2][]bool{channel[:], island[:]}) {
		field := shoreline_field_build(tiles, 3, 3, 1)
		for y in 0 ..< 3 {
			for x in 0 ..< 3 {
				testing.expect_value(
					t,
					shoreline_field_at(&field, {f32(x) + 0.5, f32(y) + 0.5}) > 0,
					tiles[y * 3 + x],
				)
			}
		}
		delete(field.values)
	}
	diagonal := [4]bool{true, false, false, true}
	field := shoreline_field_build(diagonal[:], 2, 2, 1)
	defer delete(field.values)
	testing.expect(t, shoreline_field_at(&field, {1, 1}) < 0)
	testing.expect(t, shoreline_field_at(&field, {-0.1, 0.5}) < 0)
	testing.expect(t, shoreline_field_at(&field, {2, 0.5}) < 0)
}

@(test)
test_shoreline_distance_follows_bank_segments :: proc(t: ^testing.T) {
	segment := Shoreline_Segment{{0, 0}, {1, 1}}
	testing.expect(t, shoreline_segment_distance({0.5, 0.5}, segment) < 0.00001)
	testing.expect(t, abs(shoreline_segment_distance({0, 1}, segment) - 0.70710678) < 0.00001)
	testing.expect(t, abs(shoreline_segment_distance({2, 1}, segment) - 1) < 0.00001)
}
