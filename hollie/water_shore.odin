package hollie

import "core:c"
import "core:math"
import "graphics"

WATER_SHORE_SAMPLES :: 8

Water_Shore :: struct {
	texture: graphics.Texture_2D,
}

water_shore: Water_Shore

water_unload_shore :: proc() {
	if water_shore.texture.id != 0 do graphics.unload_texture(water_shore.texture)
	water_shore = {}
}

// Distance to the actual generated bank segments, capped at one tile.
// Tile-local segment ranges keep load-time texture generation bounded.
water_shore_distance :: proc(cache: ^Shoreline_Cache, point: Vec2) -> f32 {
	field := &cache.field
	if shoreline_field_at(field, point) <= 0 do return 0
	x, y := int(math.floor(point.x / field.size)), int(math.floor(point.y / field.size))
	distance := field.size
	for row in max(y - 1, 0) ..= min(y + 1, field.height - 1) {
		for column in max(x - 1, 0) ..= min(x + 1, field.width - 1) {
			tile := cache.tiles[row * field.width + column]
			for segment in cache.segments[tile.segment_start:tile.segment_end] {
				distance = min(distance, shoreline_segment_distance(point, segment))
			}
		}
	}
	return distance / field.size
}

// Called only during room_init, after the shoreline mesh has been generated.
water_prepare_shore :: proc() -> bool {
	water_unload_shore()
	field := &shoreline.field
	if len(field.values) == 0 do return false
	width, height := field.width * WATER_SHORE_SAMPLES + 1, field.height * WATER_SHORE_SAMPLES + 1
	pixels := make([]graphics.Colour, width * height)
	defer delete(pixels)
	for y in 0 ..< height {
		for x in 0 ..< width {
			point := Vec2{f32(x), f32(y)} * (field.size / WATER_SHORE_SAMPLES)
			value := u8(water_shore_distance(&shoreline, point) * 255 + 0.5)
			pixels[y * width + x] = {value, value, value, 255}
		}
	}
	water_shore.texture = graphics.load_texture_colors(pixels, width, height)
	return water_shore.texture.id != 0
}

water_bind_shore :: proc(shader: graphics.Shader) {
	// Reserve a unit outside raylib's material/batch textures, as shadows do.
	// A normal batch sampler binding would be cleared on an automatic flush.
	texture_slot := c.int(11)
	graphics.enable_shader(shader.id)
	graphics.active_texture_slot(texture_slot)
	graphics.enable_texture(water_shore.texture.id)
	location := graphics.get_shader_location(shader, "shore_map")
	graphics.set_uniform(location, &texture_slot, graphics.SHADER_UNIFORM_INT, 1)
	graphics.active_texture_slot(0)
	map_info := Vec3 {
		f32(water_shore.texture.width),
		f32(water_shore.texture.height),
		f32(WATER_SHORE_SAMPLES),
	}
	rendering_set_shader_vec3(shader, "shore_map_info", map_info)
}
