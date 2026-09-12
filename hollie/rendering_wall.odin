package hollie

import "graphics"

rendering_draw_weak_wall :: proc(wall: ^Gate) {
	// Irregular sandstone courses and dark gaps distinguish weak masonry.
	long_x := wall.collider.size.x >= wall.collider.size.z
	length := long_x ? wall.collider.size.x : wall.collider.size.z
	thickness := long_x ? wall.collider.size.z : wall.collider.size.x
	bounds := graphics.get_model_bounding_box(model_assets.cube)
	for row in 0 ..< 3 {
		cursor := f32(0)
		for column := 0; cursor < length; column += 1 {
			width := min(length - cursor, row % 2 == 1 && column == 0 ? f32(6) : f32(12))
			position := geometry_position(wall.position, wall.height)
			position.y += (f32(row) + 0.5) * wall.collider.size.y / 3
			position.x += long_x ? cursor + width / 2 : thickness / 2
			position.z += long_x ? thickness / 2 : cursor + width / 2
			size := Vec3{width - 0.7, wall.collider.size.y / 3 - 0.6, thickness - 0.5}
			if !long_x do size.x, size.z = size.z, size.x
			shade := u8(165 + (row + column) % 3 * 12)
			scale := size / (bounds.max - bounds.min)
			graphics.draw_model(
				model_assets.cube,
				position - (bounds.min + bounds.max) * 0.5 * scale,
				{0, 1, 0},
				0,
				scale,
				{shade, shade - 25, shade - 55, 255},
			)
			cursor += width
		}
	}
}
