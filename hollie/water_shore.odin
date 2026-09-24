package hollie

import "core:c"
import "core:math"
import "graphics"
import "tilemap"

WATER_SHORE_SAMPLES :: 4

Water_Shore :: struct {
	texture:                  graphics.Texture_2D,
	tiles:                    []bool,
	width, height, tile_size: int,
}

water_shore: Water_Shore

water_unload_shore :: proc() {
	if water_shore.texture.id != 0 do graphics.unload_texture(water_shore.texture)
	delete(water_shore.tiles)
	water_shore = {}
}

// Distance in tile units, capped at one tile. Include diagonal land cells so
// contours stay continuous around corners; outside the room is also a bank.
water_shore_distance :: proc(tiles: []bool, width, height: int, point: Vec2) -> f32 {
	cell_x, cell_y := int(math.floor(point.x)), int(math.floor(point.y))
	distance_squared := f32(1)
	for y in cell_y - 1 ..= cell_y + 1 {
		for x in cell_x - 1 ..= cell_x + 1 {
			if x >= 0 && y >= 0 && x < width && y < height && tiles[y * width + x] do continue
			dx := max(max(f32(x) - point.x, point.x - f32(x + 1)), 0)
			dy := max(max(f32(y) - point.y, point.y - f32(y + 1)), 0)
			distance_squared = min(distance_squared, dx * dx + dy * dy)
		}
	}
	return math.sqrt(distance_squared)
}

water_prepare_shore :: proc() -> bool {
	width, height := tilemap.get_tilemap_width(), tilemap.get_tilemap_height()
	size := tilemap.get_tile_size()
	if width <= 0 || height <= 0 || size <= 0 do return false
	changed :=
		water_shore.width != width || water_shore.height != height || water_shore.tile_size != size
	if changed {
		water_unload_shore()
		water_shore.width, water_shore.height, water_shore.tile_size = width, height, size
		water_shore.tiles = make([]bool, width * height)
	}
	// Compare occupancy rather than hashing: editor changes cannot leave stale data.
	has_water := false
	for y in 0 ..< height {
		for x in 0 ..< width {
			index := y * width + x
			wet := water_tile(x, y)
			changed = changed || water_shore.tiles[index] != wet
			water_shore.tiles[index] = wet
			has_water = has_water || wet
		}
	}
	if !has_water {
		if water_shore.texture.id != 0 do graphics.unload_texture(water_shore.texture)
		water_shore.texture = {}
		return false
	}
	if !changed && water_shore.texture.id != 0 do return true
	if water_shore.texture.id != 0 do graphics.unload_texture(water_shore.texture)
	// Samples sit on grid vertices, including both room boundaries. Shader UVs
	// address their texel centres, making the interpolation agree across tiles.
	texture_width, texture_height :=
		width * WATER_SHORE_SAMPLES + 1, height * WATER_SHORE_SAMPLES + 1
	pixels := make([]graphics.Colour, texture_width * texture_height)
	defer delete(pixels)
	for y in 0 ..< texture_height {
		for x in 0 ..< texture_width {
			point := Vec2{f32(x), f32(y)} / f32(WATER_SHORE_SAMPLES)
			distance := water_shore_distance(water_shore.tiles, width, height, point)
			value := u8(distance * 255 + 0.5)
			pixels[y * texture_width + x] = {value, value, value, 255}
		}
	}
	water_shore.texture = graphics.load_texture_colors(pixels, texture_width, texture_height)
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
