package hollie

import "core:testing"

water_test_pool :: proc() -> Water_Field {
	field := water_field_init(50, 34, 2)
	for y in 1 ..< field.height - 1 {
		for x in 1 ..< field.width - 1 do field.wet[y * field.width + x] = true
	}
	return field
}

water_test_energy :: proc(field: ^Water_Field) -> f32 {
	energy := f32(0)
	for y in 1 ..< field.height - 1 {
		for x in 1 ..< field.width - 1 {
			i := y * field.width + x
			if !field.wet[i] do continue
			cell := field.cells[i]
			dx := (water_field_neighbor(field, i, i + 1) - cell.height) / field.spacing
			dy := (water_field_neighbor(field, i, i + field.width) - cell.height) / field.spacing
			energy +=
				cell.velocity * cell.velocity +
				WATER_WAVE_SPEED * WATER_WAVE_SPEED * (dx * dx + dy * dy)
		}
	}
	return energy
}

@(test)
test_water_disturbance_propagates_then_settles :: proc(t: ^testing.T) {
	field := water_test_pool()
	defer water_field_fini(&field)
	water_field_displace(&field, {{30, 30}, {34, 30}, {6, 6}, 4, 4})
	volume := f32(0)
	for cell in field.cells do volume += cell.height
	testing.expect(t, abs(volume) < 0.0001)
	initial := water_test_energy(&field)
	testing.expect(t, initial > 0)
	// This cell is outside both body footprints. A drawn trail cannot reach it.
	remote := 15 * field.width + 24
	testing.expect_value(t, field.cells[remote].height, f32(0))
	water_field_advance(&field, nil, 0.6)
	testing.expect(t, abs(field.cells[remote].height) > 0.00001)
	water_field_advance(&field, nil, 5)
	testing.expect(t, water_test_energy(&field) < initial * 0.05)
}

@(test)
test_water_banks_block_propagation :: proc(t: ^testing.T) {
	field := water_test_pool()
	defer water_field_fini(&field)
	for y in 1 ..< field.height - 1 do field.wet[y * field.width + 25] = false
	water_field_displace(&field, {{30, 30}, {34, 30}, {6, 6}, 4, 4})
	water_field_advance(&field, nil, 2)
	for y in 1 ..< field.height - 1 {
		for x in 25 ..< field.width - 1 {
			cell := field.cells[y * field.width + x]
			testing.expect_value(t, cell.height, f32(0))
			testing.expect_value(t, cell.velocity, f32(0))
		}
	}
}

@(test)
test_stationary_water_contact_does_not_emit :: proc(t: ^testing.T) {
	field := water_test_pool()
	defer water_field_fini(&field)
	sources := [1]Water_Disturbance{{{30, 30}, {30, 30}, {6, 6}, 4, 4}}
	water_field_advance(&field, sources[:], 1)
	for cell in field.cells do testing.expect_value(t, cell, Water_Cell{})
}

@(test)
test_water_motion_is_consistent_across_frame_rates :: proc(t: ^testing.T) {
	slow := water_test_pool()
	fast := water_test_pool()
	defer water_field_fini(&slow)
	defer water_field_fini(&fast)
	rates := [2]int{30, 120}
	for rate in rates {
		field := rate == 30 ? &slow : &fast
		for frame in 0 ..< rate {
			start := Vec2{20 + 40 * f32(frame) / f32(rate), 30}
			end := Vec2{20 + 40 * f32(frame + 1) / f32(rate), 30}
			sources := [1]Water_Disturbance{{start, end, {6, 6}, 4, 4}}
			water_field_advance(field, sources[:], 1 / f32(rate))
		}
	}
	for cell, i in slow.cells {
		testing.expect(t, abs(cell.height - fast.cells[i].height) < 0.001)
		testing.expect(t, abs(cell.velocity - fast.cells[i].velocity) < 0.01)
	}
}
