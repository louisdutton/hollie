package hollie

import "graphics"
import "tilemap"

Shoreline_Surface :: enum {
	Ground,
	Grass,
	Bed,
	Bank,
	Water,
}
Shoreline_Mesh :: struct {
	model:   graphics.Model,
	surface: Shoreline_Surface,
}
Shoreline_Cache :: struct {
	field:    Shoreline_Field,
	tiles:    []Shoreline_Tile,
	segments: [dynamic]Shoreline_Segment,
	meshes:   [dynamic]Shoreline_Mesh,
}
shoreline: Shoreline_Cache

shoreline_fini :: proc() {
	for mesh in shoreline.meshes do graphics.unload_model(mesh.model)
	delete(shoreline.meshes)
	delete(shoreline.segments)
	delete(shoreline.tiles)
	delete(shoreline.field.values)
	shoreline = {}
}

shoreline_tile :: proc(x, y: int) -> ^Shoreline_Tile {
	if x < 0 || y < 0 || x >= shoreline.field.width || y >= shoreline.field.height do return nil
	return &shoreline.tiles[y * shoreline.field.width + x]
}

shoreline_append_polygon :: proc(
	builder: ^Grass_Mesh_Builder,
	polygon: Shoreline_Polygon,
	height: f32,
	color: graphics.Colour,
) {
	for i in 1 ..< polygon.count - 1 {
		a, b, c := polygon.vertices[0], polygon.vertices[i], polygon.vertices[i + 1]
		area := (b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x)
		if abs(area) < 0.000001 do continue
		grass_mesh_append(
			builder,
			[]Vec3{{a.x, height, a.y}, {b.x, height, b.y}, {c.x, height, c.y}},
			[]u16{0, 1, 2},
			color,
		)
	}
}

shoreline_init :: proc() {
	shoreline_fini()
	width, height := tilemap.get_tilemap_width(), tilemap.get_tilemap_height()
	size := f32(tilemap.get_tile_size())
	if width <= 0 || height <= 0 || size <= 0 do return
	wet := make([]bool, width * height)
	defer delete(wet)
	has_water := false
	for y in 0 ..< height {
		for x in 0 ..< width {
			wet[y * width + x] = water_tile(x, y)
			has_water = has_water || wet[y * width + x]
		}
	}
	if !has_water do return
	shoreline.field = shoreline_field_build(wet, width, height, size)
	// Never expand a water surface into an authored void. Pin its shared edge
	// samples to the land side, including the outer boundary of the room.
	stride := width * SHORELINE_STEPS + 1
	for gy in 0 ..= height * SHORELINE_STEPS {
		for gx in 0 ..= width * SHORELINE_STEPS {
			x, y := gx / SHORELINE_STEPS, gy / SHORELINE_STEPS
			void := !tilemap.has_floor(x, y)
			if gx % SHORELINE_STEPS == 0 do void = void || !tilemap.has_floor(x - 1, y)
			if gy % SHORELINE_STEPS == 0 do void = void || !tilemap.has_floor(x, y - 1)
			if gx % SHORELINE_STEPS == 0 && gy % SHORELINE_STEPS == 0 do void = void || !tilemap.has_floor(x - 1, y - 1)
			if void do shoreline.field.values[gy * stride + gx] = min(shoreline.field.values[gy * stride + gx], -0.0001)
		}
	}
	shoreline.tiles = make([]Shoreline_Tile, width * height)
	builders: [Shoreline_Surface]Grass_Mesh_Builder
	defer for &builder in builders {
		delete(builder.positions)
		delete(builder.roots)
		delete(builder.colors)
		delete(builder.indices)
	}
	for y in 0 ..< height {
		for x in 0 ..< width {
			tile := shoreline_tile(x, y)
			tile.segment_start = len(shoreline.segments)
			tile.segment_end = tile.segment_start
			if !tilemap.has_floor(x, y) do continue
			// Replace water tiles and the surrounding land only. Interior land
			// keeps its original material/model and existing grass geometry.
			for dy in -1 ..= 1 {
				for dx in -1 ..= 1 {
					tile.affected = tile.affected || water_tile(x + dx, y + dy)
				}
			}
			if !tile.affected do continue
			tile.grass = grass_ground_tile(x, y)
			tile.density = f32(tilemap.get_grass_density(x, y)) / 255
			if water_tile(x, y) {
				for dy in -1 ..= 1 {
					for dx in -1 ..= 1 {
						if !grass_ground_tile(x + dx, y + dy) do continue
						tile.grass = true
						tile.density = max(
							tile.density,
							f32(tilemap.get_grass_density(x + dx, y + dy)) / 255,
						)
					}
				}
			}
			for row in 0 ..< SHORELINE_STEPS {
				for column in 0 ..< SHORELINE_STEPS {
					gx, gy := x * SHORELINE_STEPS + column, y * SHORELINE_STEPS + row
					a, b :=
						shoreline_vertex(&shoreline.field, gx, gy),
						shoreline_vertex(&shoreline.field, gx, gy + 1)
					c, d :=
						shoreline_vertex(&shoreline.field, gx + 1, gy + 1),
						shoreline_vertex(&shoreline.field, gx + 1, gy)
					triangles := [2][3]Shoreline_Vertex{{a, b, c}, {a, c, d}}
					for triangle in triangles {
						water := shoreline_clip(triangle, true)
						land := shoreline_clip(triangle, false)
						land_surface: Shoreline_Surface = tile.grass ? .Grass : .Ground
						land_color :=
							tile.grass ? graphics.Colour{255, 255, 255, 0} : graphics.Colour{190, 180, 145, 255}
						shoreline_append_polygon(
							&builders[land_surface],
							land,
							tile.grass ? 0.03 : 0,
							land_color,
						)
						shoreline_append_polygon(
							&builders[.Water],
							water,
							WATER_SURFACE,
							graphics.WHITE,
						)
						shoreline_append_polygon(
							&builders[.Bed],
							water,
							WATER_BED,
							{163, 151, 111, 255},
						)
						if segment, ok := shoreline_segment(triangle); ok {
							append(&shoreline.segments, segment)
							p, q := segment.a, segment.b
							// Both windings: banks remain visible from either side.
							grass_mesh_append(
								&builders[.Bank],
								[]Vec3 {
									{p.x, 0, p.y},
									{q.x, 0, q.y},
									{q.x, WATER_BED, q.y},
									{p.x, WATER_BED, p.y},
								},
								[]u16{0, 1, 2, 0, 2, 3, 2, 1, 0, 3, 2, 0},
								{130, 116, 83, 255},
							)
						}
					}
				}
			}
			tile.segment_end = len(shoreline.segments)
			// Batch compatible surfaces while staying safely below u16 limits.
			for &builder, surface in builders {
				if len(builder.positions) >= 60000 do shoreline_upload(&builder, surface)
			}
		}
	}
	for &builder, surface in builders do shoreline_upload(&builder, surface)
}

shoreline_upload :: proc(builder: ^Grass_Mesh_Builder, surface: Shoreline_Surface) {
	if len(builder.positions) == 0 do return
	model := graphics.load_indexed_model(
		builder.positions[:],
		builder.colors[:],
		builder.indices[:],
		builder.roots[:],
		true,
	)
	append(&shoreline.meshes, Shoreline_Mesh{model, surface})
	clear(&builder.positions)
	clear(&builder.roots)
	clear(&builder.colors)
	clear(&builder.indices)
}

shoreline_draw :: proc(surface: Shoreline_Surface, shader: graphics.Shader) {
	for &mesh in shoreline.meshes {
		if mesh.surface != surface do continue
		rendering_apply_shader(&mesh.model, shader)
		graphics.draw_model(mesh.model, {}, {0, 1, 0}, 0, {1, 1, 1}, graphics.WHITE)
	}
}
