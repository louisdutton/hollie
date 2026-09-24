package hollie

import "core:math"

SHORELINE_STEPS :: 8

Shoreline_Vertex :: struct {
	position: Vec2,
	value:    f32,
}
Shoreline_Polygon :: struct {
	vertices: [4]Vec2,
	count:    int,
}
Shoreline_Segment :: struct {
	a, b: Vec2,
}
Shoreline_Tile :: struct {
	affected, grass:            bool,
	density:                    f32,
	segment_start, segment_end: int,
}
Shoreline_Field :: struct {
	width, height: int,
	size:          f32,
	values:        []f32,
}

shoreline_sample_tiles :: proc(tiles: []bool, width, height: int, x, y: int) -> f32 {
	if x < 0 || y < 0 || x >= width || y >= height do return -1
	return tiles[y * width + x] ? 1 : -1
}

// Reconstruct between tile centres. Subdivision resolves rounded bilinear
// corners; tile centres stay unchanged, preserving single-cell islands/channels.
shoreline_field_build :: proc(tiles: []bool, width, height: int, size: f32) -> Shoreline_Field {
	field := Shoreline_Field {
		width  = width,
		height = height,
		size   = size,
	}
	stride := width * SHORELINE_STEPS + 1
	field.values = make([]f32, stride * (height * SHORELINE_STEPS + 1))
	for y in 0 ..= height * SHORELINE_STEPS {
		for x in 0 ..= width * SHORELINE_STEPS {
			p := Vec2{f32(x), f32(y)} / SHORELINE_STEPS - Vec2{0.5, 0.5}
			ix, iy := int(math.floor(p.x)), int(math.floor(p.y))
			f := p - Vec2{f32(ix), f32(iy)}
			a := math.lerp(
				shoreline_sample_tiles(tiles, width, height, ix, iy),
				shoreline_sample_tiles(tiles, width, height, ix + 1, iy),
				f.x,
			)
			b := math.lerp(
				shoreline_sample_tiles(tiles, width, height, ix, iy + 1),
				shoreline_sample_tiles(tiles, width, height, ix + 1, iy + 1),
				f.x,
			)
			// Resolve diagonal saddle ties toward land: diagonal water pools never
			// acquire a zero-width connection. Shared edges use identical values.
			field.values[y * stride + x] = math.lerp(a, b, f.y) - 0.0001
		}
	}
	return field
}

shoreline_vertex :: proc(field: ^Shoreline_Field, x, y: int) -> Shoreline_Vertex {
	return {
		Vec2{f32(x), f32(y)} * (field.size / SHORELINE_STEPS),
		field.values[y * (field.width * SHORELINE_STEPS + 1) + x],
	}
}

// Same two triangles as the generated mesh; contact queries do not approximate
// the contour with the old square tile classification.
shoreline_field_at :: proc(field: ^Shoreline_Field, position: Vec2) -> f32 {
	if field.size <= 0 || len(field.values) == 0 do return -1
	p := position / field.size * SHORELINE_STEPS
	x, y := int(math.floor(p.x)), int(math.floor(p.y))
	if x < 0 || y < 0 || x >= field.width * SHORELINE_STEPS || y >= field.height * SHORELINE_STEPS do return -1
	f := p - Vec2{f32(x), f32(y)}
	a := shoreline_vertex(field, x, y).value
	b := shoreline_vertex(field, x, y + 1).value
	c := shoreline_vertex(field, x + 1, y + 1).value
	d := shoreline_vertex(field, x + 1, y).value
	return(
		f.y >= f.x ? a * (1 - f.y) + b * (f.y - f.x) + c * f.x : a * (1 - f.x) + c * f.y + d * (f.x - f.y) \
	)
}

shoreline_clip :: proc(triangle: [3]Shoreline_Vertex, wet: bool) -> Shoreline_Polygon {
	result: Shoreline_Polygon
	for a, i in triangle {
		b := triangle[(i + 1) % 3]
		inside_a, inside_b := (a.value > 0) == wet, (b.value > 0) == wet
		if inside_a {
			result.vertices[result.count] = a.position
			result.count += 1
		}
		if inside_a != inside_b {
			result.vertices[result.count] =
				a.position + (b.position - a.position) * (a.value / (a.value - b.value))
			result.count += 1
		}
	}
	return result
}

shoreline_segment :: proc(
	triangle: [3]Shoreline_Vertex,
) -> (
	segment: Shoreline_Segment,
	valid: bool,
) {
	points: [2]Vec2
	count := 0
	for a, i in triangle {
		b := triangle[(i + 1) % 3]
		if (a.value > 0) == (b.value > 0) do continue
		points[count] = a.position + (b.position - a.position) * (a.value / (a.value - b.value))
		count += 1
	}
	if count != 2 do return {}, false
	// Orient bank normals toward water, consistently across both cell triangles.
	for vertex in triangle {
		if vertex.value <= 0 do continue
		delta := points[1] - points[0]
		to_water := vertex.position - points[0]
		if delta.y * to_water.x - delta.x * to_water.y < 0 do points[0], points[1] = points[1], points[0]
		break
	}
	return {points[0], points[1]}, true
}

shoreline_segment_distance :: proc(point: Vec2, segment: Shoreline_Segment) -> f32 {
	delta := segment.b - segment.a
	length_squared := delta.x * delta.x + delta.y * delta.y
	t :=
		length_squared > 0 ? clamp(((point.x - segment.a.x) * delta.x + (point.y - segment.a.y) * delta.y) / length_squared, 0, 1) : 0
	d := point - (segment.a + delta * t)
	return math.sqrt(d.x * d.x + d.y * d.y)
}
