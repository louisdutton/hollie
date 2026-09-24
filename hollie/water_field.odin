package hollie

import "core:math"

WATER_WAVE_SPEED :: f32(22)
WATER_WAVE_STEP :: f32(1.0 / 120)
WATER_WAVE_DAMPING :: f32(1.8)

Water_Cell :: struct {
	height, velocity, foam: f32,
}

Water_Field :: struct {
	width, height: int,
	spacing:       f32,
	cells, next:   []Water_Cell,
	wet:           []bool,
	pixels:        [][4]f32,
}

Water_Disturbance :: struct {
	previous, current, radius: Vec2,
	previous_depth, depth:     f32,
}

water_field_init :: proc(width, height: int, spacing: f32) -> Water_Field {
	return {
		width = width,
		height = height,
		spacing = spacing,
		cells = make([]Water_Cell, width * height),
		next = make([]Water_Cell, width * height),
		wet = make([]bool, width * height),
		pixels = make([][4]f32, width * height),
	}
}

water_field_fini :: proc(field: ^Water_Field) {
	delete(field.cells)
	delete(field.next)
	delete(field.wet)
	delete(field.pixels)
	field^ = {}
}

// A compact, smooth submerged footprint. Moving it adds the old displaced
// volume and removes the new one, rather than emitting timed wake shapes.
water_displaced_volume :: proc(point, center, radius: Vec2, depth: f32) -> f32 {
	delta := (point - center) / radius
	r2 := delta.x * delta.x + delta.y * delta.y
	if r2 >= 1 do return 0
	return depth * (1 - r2) * (1 - r2) * 0.18
}

water_field_displace :: proc(field: ^Water_Field, source: Water_Disturbance) {
	if source.previous == source.current && source.previous_depth == source.depth do return
	left := max(
		int(
			math.floor(
				(min(source.previous.x, source.current.x) - source.radius.x) / field.spacing,
			),
		),
		1,
	)
	right := min(
		int(
			math.ceil(
				(max(source.previous.x, source.current.x) + source.radius.x) / field.spacing,
			),
		) +
		1,
		field.width - 2,
	)
	top := max(
		int(
			math.floor(
				(min(source.previous.y, source.current.y) - source.radius.y) / field.spacing,
			),
		),
		1,
	)
	bottom := min(
		int(
			math.ceil(
				(max(source.previous.y, source.current.y) + source.radius.y) / field.spacing,
			),
		) +
		1,
		field.height - 2,
	)
	for y in top ..= bottom {
		for x in left ..= right {
			i := y * field.width + x
			if !field.wet[i] do continue
			point := Vec2{f32(x) - 0.5, f32(y) - 0.5} * field.spacing
			old_volume := water_displaced_volume(
				point,
				source.previous,
				source.radius,
				source.previous_depth,
			)
			new_volume := water_displaced_volume(
				point,
				source.current,
				source.radius,
				source.depth,
			)
			change := old_volume - new_volume
			field.cells[i].height += change
			// Sparse turbulence remains where the body disturbed the surface.
			field.cells[i].foam = min(field.cells[i].foam + abs(change) * 0.10, 0.30)
		}
	}
}

water_field_neighbor :: proc(field: ^Water_Field, index, neighbor: int) -> f32 {
	// Zero normal derivative at solid banks: reflect, do not transmit through land.
	return field.wet[neighbor] ? field.cells[neighbor].height : field.cells[index].height
}

water_field_step :: proc(field: ^Water_Field, dt: f32) {
	assert(dt > 0 && WATER_WAVE_SPEED * dt / field.spacing < 0.7)
	damping := math.exp(-WATER_WAVE_DAMPING * dt)
	foam_decay := math.exp(-2.5 * dt)
	coefficient := WATER_WAVE_SPEED * WATER_WAVE_SPEED / (field.spacing * field.spacing)
	for y in 1 ..< field.height - 1 {
		for x in 1 ..< field.width - 1 {
			i := y * field.width + x
			if !field.wet[i] {
				field.next[i] = {}
				continue
			}
			cell := field.cells[i]
			laplacian :=
				water_field_neighbor(field, i, i - 1) +
				water_field_neighbor(field, i, i + 1) +
				water_field_neighbor(field, i, i - field.width) +
				water_field_neighbor(field, i, i + field.width) -
				4 * cell.height
			velocity := (cell.velocity + coefficient * laplacian * dt) * damping
			field.next[i] = {cell.height + velocity * dt, velocity, cell.foam * foam_decay}
		}
	}
	field.cells, field.next = field.next, field.cells
}

water_field_advance :: proc(field: ^Water_Field, sources: []Water_Disturbance, dt: f32) {
	if dt <= 0 do return
	// Bound both wave propagation and swept body motion by small time steps.
	steps := max(int(math.ceil(dt / WATER_WAVE_STEP)), 1)
	step := dt / f32(steps)
	for iteration in 0 ..< steps {
		t0, t1 := f32(iteration) / f32(steps), f32(iteration + 1) / f32(steps)
		for source in sources {
			delta := source.current - source.previous
			depth_delta := source.depth - source.previous_depth
			water_field_displace(
				field,
				{
					previous = source.previous + delta * t0,
					current = source.previous + delta * t1,
					radius = source.radius,
					previous_depth = source.previous_depth + depth_delta * t0,
					depth = source.previous_depth + depth_delta * t1,
				},
			)
		}
		water_field_step(field, step)
	}
}

water_field_encode :: proc(field: ^Water_Field) {
	for y in 1 ..< field.height - 1 {
		for x in 1 ..< field.width - 1 {
			i := y * field.width + x
			field.pixels[i] = {}
			if !field.wet[i] do continue
			dx :=
				(water_field_neighbor(field, i, i + 1) - water_field_neighbor(field, i, i - 1)) /
				(2 * field.spacing)
			dz :=
				(water_field_neighbor(field, i, i + field.width) -
					water_field_neighbor(field, i, i - field.width)) /
				(2 * field.spacing)
			field.pixels[i] = {field.cells[i].height, dx, dz, field.cells[i].foam}
		}
	}
}
