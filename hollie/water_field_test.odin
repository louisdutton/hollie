package hollie

import "core:testing"

@(test)
test_swimmer_produces_shading_data_at_room_resolution :: proc(t: ^testing.T) {
	// Same cell spacing as the 960-world-unit demo room at the 256-cell cap.
	field := water_field_init(66, 50, 3.75)
	defer water_field_fini(&field)
	for y in 1 ..< field.height - 1 {
		for x in 1 ..< field.width - 1 do field.wet[y * field.width + x] = true
	}
	collider := Collider {
		size   = {16, 22, 16},
		offset = {-8, 0, -8},
	}
	body := Transform {
		position = {60, 90},
		height   = WATER_SURFACE - WATER_DRAFT,
		velocity = {60, 0},
		swimming = true,
	}
	for frame in 0 ..= 120 {
		body.position.x = 60 + f32(frame)
		bounds := collision_aabb_at(body.position, collider, body.height)
		sources := [1]Water_Disturbance{water_body_disturbance(&body, bounds, field.spacing, true)}
		water_field_advance(&field, sources[:], 1.0 / 60)
	}
	water_field_encode(&field)
	crest, slope := f32(0), f32(0)
	readable_cells := 0
	for y in 1 ..< field.height - 1 {
		for x in 1 ..< field.width - 1 {
			point := Vec2{f32(x) - 0.5, f32(y) - 0.5} * field.spacing
			// Measure the trail outside the body silhouette, not its hidden centre.
			if point.x > body.position.x - 16 || point.x < body.position.x - 60 do continue
			pixel := field.pixels[y * field.width + x]
			crest = max(crest, pixel[0])
			slope = max(slope, max(abs(pixel[1]), abs(pixel[2])))
			if abs(pixel[0]) > 0.025 do readable_cells += 1
		}
	}
	testing.expect(t, crest > 0.025)
	testing.expect(t, slope > 0.005)
	testing.expect(t, readable_cells >= 10)
}

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
