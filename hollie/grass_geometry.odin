package hollie

import "graphics"
import "tilemap"

GRASS_CHUNK_TILES :: 4

Grass_Mesh_Builder :: struct {
	positions: [dynamic]Vec3,
	roots:     [dynamic]Vec2,
	colors:    [dynamic]graphics.Colour,
	indices:   [dynamic]u16,
}

Grass_Chunk :: struct {
	model:    graphics.Model,
	min, max: Vec2,
}

grass_chunks: [dynamic]Grass_Chunk
grass_geometry_ready: bool

grass_mesh_append :: proc(
	builder: ^Grass_Mesh_Builder,
	positions: []Vec3,
	indices: []u16,
	color: graphics.Colour,
	root: Vec2 = {},
) {
	base := u16(len(builder.positions))
	for position in positions {
		append(&builder.positions, position)
		append(&builder.colors, color)
		append(&builder.roots, color.a == 0 ? Vec2{position.x, position.z} : root)
	}
	for index in indices do append(&builder.indices, base + index)
}

grass_unload_geometry :: proc() {
	for chunk in grass_chunks do graphics.unload_model(chunk.model)
	delete(grass_chunks)
	grass_chunks = {}
	grass_geometry_ready = false
}

grass_build_geometry :: proc() {
	builder: Grass_Mesh_Builder
	defer delete(builder.positions)
	defer delete(builder.roots)
	defer delete(builder.colors)
	defer delete(builder.indices)
	size := f32(tilemap.get_tile_size())
	width, height := tilemap.get_tilemap_width(), tilemap.get_tilemap_height()
	for top := 0; top < height; top += GRASS_CHUNK_TILES {
		for left := 0; left < width; left += GRASS_CHUNK_TILES {
			clear(&builder.positions)
			clear(&builder.roots)
			clear(&builder.colors)
			clear(&builder.indices)
			right, bottom :=
				min(left + GRASS_CHUNK_TILES, width), min(top + GRASS_CHUNK_TILES, height)
			for y in top ..< bottom {
				for x in left ..< right {
					if grass_tile(x, y) do grass_build_tile(&builder, x, y)
				}
			}
			if len(builder.positions) == 0 do continue
			model := graphics.load_indexed_model(
				builder.positions[:],
				builder.colors[:],
				builder.indices[:],
				builder.roots[:],
			)
			rendering_apply_shader(&model, rendering_state.grass_shader)
			append(
				&grass_chunks,
				Grass_Chunk {
					model = model,
					// Include blade width and lean outside the tile boundary.
					min   = {f32(left) * size - 3, f32(top) * size - 3},
					max   = {f32(right) * size + 3, f32(bottom) * size + 3},
				},
			)
		}
	}
	grass_geometry_ready = true
}

rendering_draw_grass :: proc() {
	enabled := grass_is_enabled()
	shader := rendering_state.grass_shader
	if !graphics.shader_is_loaded(shader) || rendering_state.grass_time_location < 0 do return
	if enabled && !grass_geometry_ready do grass_build_geometry()
	rendering_set_shader_vec3(shader, "view_position", rendering_camera().position)
	graphics.set_shader_float(shader, rendering_state.grass_time_location, &water_time)
	shoreline_draw(.Grass, shader)
	if !enabled do return
	for chunk in grass_chunks {
		grass_upload_contacts(shader, chunk.min, chunk.max)
		grass_upload_trail(shader, chunk.min, chunk.max)
		graphics.draw_model(chunk.model, {}, {0, 1, 0}, 0, {1, 1, 1}, graphics.WHITE)
	}
}
