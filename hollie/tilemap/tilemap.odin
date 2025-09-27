package tilemap

import "core:fmt"
import "core:math/rand"
import "core:os"
import "core:strconv"
import "core:strings"
import rl "vendor:raylib"

Vec2 :: rl.Vector2

/// Configuration for tilemap rendering and behavior
TilemapConfig :: struct {
	tile_size:    int,
	tileset_cols: int,
}

@(private)
config := TilemapConfig {
	tile_size    = 16,
	tileset_cols = 32,
}

TileType :: enum u16 {
	GRASS_1 = 0,
	GRASS_2,
	GRASS_3,
	GRASS_4 = 32,
	GRASS_5,
	GRASS_6,
	GRASS_7 = 32 * 2,
	GRASS_8,

	// grass decorations
	GRASS_DEC_1 = 32 * 8,
	GRASS_DEC_2,
	GRASS_DEC_3,
	GRASS_DEC_4,
	GRASS_DEC_5 = 32 * 9,
	GRASS_DEC_6,
	GRASS_DEC_7,
	GRASS_DEC_8,
	GRASS_DEC_9 = 32 * 10,
	GRASS_DEC_10,
	GRASS_DEC_11,
	GRASS_DEC_12,
	GRASS_DEC_13 = 32 * 11,
	GRASS_DEC_14,
	GRASS_DEC_15,
	GRASS_DEC_16,

	// sand
	SAND_1 = 3,
	SAND_2,
	SAND_3,

	// sand decorations
	SAND_DEC_13 = 32 * 12,
	SAND_DEC_14,
	SAND_DEC_15,
	SAND_DEC_16,

	// misc
	EMPTY = 65535, // Special empty tile for decorative layer
}

Tile :: struct {
	type:  TileType,
	solid: bool,
}

TileMap :: struct {
	width:      int,
	height:     int,
	base_tiles: []Tile,
	deco_tiles: []Tile,
	tileset:    rl.Texture2D,
	tile_size:  int,
}

@(private)
tilemap := TileMap {
	width     = 50,
	height    = 30,
	tile_size = 16,
}

TilemapResource :: struct {
	width:        int,
	height:       int,
	tileset_path: string,
	base_data:    []TileType,
	deco_data:    []TileType,
	config:       TilemapConfig,
}

load_from_config :: proc(res: TilemapResource) {
	if tilemap.base_tiles != nil {
		delete(tilemap.base_tiles)
	}
	if tilemap.deco_tiles != nil {
		delete(tilemap.deco_tiles)
	}
	if tilemap.tileset.id != 0 {
		rl.UnloadTexture(tilemap.tileset)
	}

	// Update global config
	config = res.config

	tilemap.width = res.width
	tilemap.height = res.height
	tilemap.tile_size = res.config.tile_size
	tilemap.tileset = rl.LoadTexture(cstring(raw_data(res.tileset_path)))

	tilemap.base_tiles = make([]Tile, tilemap.width * tilemap.height)
	tilemap.deco_tiles = make([]Tile, tilemap.width * tilemap.height)

	// Load base layer
	if len(res.base_data) > 0 {
		for i in 0 ..< min(len(res.base_data), len(tilemap.base_tiles)) {
			tilemap.base_tiles[i] = Tile {
				type  = res.base_data[i],
				solid = false,
			}
		}
	} else {
		for y in 0 ..< tilemap.height {
			for x in 0 ..< tilemap.width {
				index := y * tilemap.width + x
				type := rand.choice(
					[]TileType {
						.GRASS_1,
						.GRASS_2,
						.GRASS_3,
						.GRASS_4,
						.GRASS_5,
						.GRASS_6,
						.GRASS_7,
						.GRASS_8,
					},
				)
				tilemap.base_tiles[index] = Tile {
					type  = type,
					solid = false,
				}
			}
		}
	}

	// Load decorative layer
	if len(res.deco_data) > 0 {
		for i in 0 ..< min(len(res.deco_data), len(tilemap.deco_tiles)) {
			tilemap.deco_tiles[i] = Tile {
				type  = res.deco_data[i],
				solid = false,
			}
		}
	} else {
		// Initialize all decorative tiles as empty
		for i in 0 ..< len(tilemap.deco_tiles) {
			tilemap.deco_tiles[i] = Tile {
				type  = .EMPTY,
				solid = false,
			}
		}
	}
}

get_tile :: proc(x, y: int) -> ^Tile {
	return get_base_tile(x, y)
}

get_base_tile :: proc(x, y: int) -> ^Tile {
	if x < 0 || x >= tilemap.width || y < 0 || y >= tilemap.height {
		return nil
	}
	index := y * tilemap.width + x
	return &tilemap.base_tiles[index]
}

get_deco_tile :: proc(x, y: int) -> ^Tile {
	if x < 0 || x >= tilemap.width || y < 0 || y >= tilemap.height {
		return nil
	}
	index := y * tilemap.width + x
	return &tilemap.deco_tiles[index]
}

get_tile_source_rect :: proc(tile_type: TileType) -> rl.Rectangle {
	tile_id := int(tile_type)
	tiles_per_row := config.tileset_cols

	source_x := (tile_id % tiles_per_row) * config.tile_size
	source_y := (tile_id / tiles_per_row) * config.tile_size

	return rl.Rectangle {
		x = f32(source_x),
		y = f32(source_y),
		width = f32(config.tile_size),
		height = f32(config.tile_size),
	}
}

get_tileset :: proc() -> rl.Texture2D {
	return tilemap.tileset
}

get_tile_size :: proc() -> int {
	return config.tile_size
}

get_tilemap_width :: proc() -> int {
	return tilemap.width
}

get_tilemap_height :: proc() -> int {
	return tilemap.height
}

/// Load complete tilemap resource from file
load_tilemap_from_file :: proc(path: string) -> (TilemapResource, bool) {
	data, ok := os.read_entire_file(path)
	if !ok {
		return {}, false
	}
	defer delete(data)

	content := string(data)
	lines := strings.split_lines(content)
	defer delete(lines)

	res := TilemapResource {
		config = TilemapConfig{tile_size = 16, tileset_cols = 32},
	}

	current_section := ""
	base_data := make([dynamic]TileType)
	deco_data := make([dynamic]TileType)
	defer delete(base_data)
	defer delete(deco_data)

	for &line in lines {
		line = strings.trim_space(line)
		if len(line) == 0 || strings.has_prefix(line, "#") {
			continue
		}

		// Check for section headers
		if strings.has_prefix(line, "[") && strings.has_suffix(line, "]") {
			current_section = strings.trim(line, "[]")
			continue
		}

		switch current_section {
		case "config":
			parts := strings.split(line, "=")
			if len(parts) != 2 do continue
			defer delete(parts)

			key := strings.trim_space(parts[0])
			value := strings.trim_space(parts[1])

			switch key {
			case "width": if parsed_value, parse_ok := strconv.parse_int(value); parse_ok {
						res.width = parsed_value
					}
			case "height": if parsed_value, parse_ok := strconv.parse_int(value); parse_ok {
						res.height = parsed_value
					}
			case "tileset_path": res.tileset_path = value
			case "tile_size": if parsed_value, parse_ok := strconv.parse_int(value); parse_ok {
						res.config.tile_size = parsed_value
					}
			case "tileset_cols": if parsed_value, parse_ok := strconv.parse_int(value); parse_ok {
						res.config.tileset_cols = parsed_value
					}
			}

		case "base_data":
			// Parse comma-separated tile IDs
			tile_strs := strings.split(line, ",")
			defer delete(tile_strs)
			for &tile_str in tile_strs {
				tile_str = strings.trim_space(tile_str)
				if tile_id, parse_ok := strconv.parse_int(tile_str); parse_ok {
					append(&base_data, TileType(tile_id))
				}
			}

		case "deco_data":
			// Parse comma-separated tile IDs
			tile_strs := strings.split(line, ",")
			defer delete(tile_strs)
			for &tile_str in tile_strs {
				tile_str = strings.trim_space(tile_str)
				if tile_id, parse_ok := strconv.parse_int(tile_str); parse_ok {
					append(&deco_data, TileType(tile_id))
				}
			}
		}
	}

	// Convert dynamic arrays to slices
	res.base_data = make([]TileType, len(base_data))
	copy(res.base_data, base_data[:])

	res.deco_data = make([]TileType, len(deco_data))
	copy(res.deco_data, deco_data[:])

	return res, true
}

/// Save current tilemap to file
save_tilemap_to_file :: proc(path: string) -> bool {
	if tilemap.base_tiles == nil || tilemap.deco_tiles == nil {
		return false
	}

	builder := strings.builder_make()
	defer strings.builder_destroy(&builder)

	// Write header
	strings.write_string(&builder, "# Tilemap Configuration\n")
	strings.write_string(&builder, "[config]\n")
	strings.write_string(&builder, fmt.tprintf("width=%d\n", tilemap.width))
	strings.write_string(&builder, fmt.tprintf("height=%d\n", tilemap.height))
	strings.write_string(
		&builder,
		fmt.tprintf("tileset_path=%s\n", "art/tileset/spr_tileset_sunnysideworld_16px.png"),
	)
	strings.write_string(&builder, fmt.tprintf("tile_size=%d\n", config.tile_size))
	strings.write_string(&builder, fmt.tprintf("tileset_cols=%d\n", config.tileset_cols))
	strings.write_string(&builder, "\n")

	// Write base layer data
	strings.write_string(&builder, "# Base layer data\n")
	strings.write_string(&builder, "[base_data]\n")
	for y in 0 ..< tilemap.height {
		for x in 0 ..< tilemap.width {
			index := y * tilemap.width + x
			if x > 0 {
				strings.write_string(&builder, ",")
			}
			strings.write_string(&builder, fmt.tprintf("%d", int(tilemap.base_tiles[index].type)))
		}
		strings.write_string(&builder, "\n")
	}
	strings.write_string(&builder, "\n")

	// Write decorative layer data
	strings.write_string(&builder, "# Decorative layer data\n")
	strings.write_string(&builder, "[deco_data]\n")
	for y in 0 ..< tilemap.height {
		for x in 0 ..< tilemap.width {
			index := y * tilemap.width + x
			if x > 0 {
				strings.write_string(&builder, ",")
			}
			strings.write_string(&builder, fmt.tprintf("%d", int(tilemap.deco_tiles[index].type)))
		}
		strings.write_string(&builder, "\n")
	}

	// Write to file
	content := strings.to_string(builder)
	return os.write_entire_file(path, transmute([]u8)content)
}

world_to_tile :: proc(world_pos: Vec2) -> (int, int) {
	return int(world_pos.x / f32(config.tile_size)), int(world_pos.y / f32(config.tile_size))
}

tile_to_world :: proc(tile_x, tile_y: int) -> Vec2 {
	return {f32(tile_x * config.tile_size), f32(tile_y * config.tile_size)}
}

is_tile_solid :: proc(x, y: int) -> bool {
	if tile := get_tile(x, y); tile != nil {
		return tile.solid
	}
	return true
}

check_collision :: proc(rect: rl.Rectangle) -> bool {
	tile_size_f := f32(config.tile_size)
	left := int(rect.x / tile_size_f)
	right := int((rect.x + rect.width) / tile_size_f)
	top := int(rect.y / tile_size_f)
	bottom := int((rect.y + rect.height) / tile_size_f)

	for y in top ..= bottom {
		for x in left ..= right {
			if is_tile_solid(x, y) {
				return true
			}
		}
	}
	return false
}

draw :: proc(camera: rl.Camera2D) {
	screen_width := f32(rl.GetScreenWidth())
	screen_height := f32(rl.GetScreenHeight())

	world_min := rl.GetScreenToWorld2D({0, 0}, camera)
	world_max := rl.GetScreenToWorld2D({screen_width, screen_height}, camera)

	tile_size_f := f32(config.tile_size)
	start_x := max(0, int(world_min.x / tile_size_f) - 1)
	end_x := min(tilemap.width, int(world_max.x / tile_size_f) + 2)
	start_y := max(0, int(world_min.y / tile_size_f) - 1)
	end_y := min(tilemap.height, int(world_max.y / tile_size_f) + 2)

	// Draw base layer first
	for y in start_y ..< end_y {
		world_y := f32(y * tilemap.tile_size)

		for x in start_x ..< end_x {
			base_tile := get_base_tile(x, y)
			if base_tile == nil do continue

			world_x := f32(x * tilemap.tile_size)

			source_rect := get_tile_source_rect(base_tile.type)
			dest_rect := rl.Rectangle {
				x      = world_x,
				y      = world_y,
				width  = f32(config.tile_size),
				height = f32(config.tile_size),
			}

			rl.DrawTexturePro(tilemap.tileset, source_rect, dest_rect, {0, 0}, 0, rl.WHITE)
		}
	}

	// Draw decorative layer on top
	for y in start_y ..< end_y {
		world_y := f32(y * tilemap.tile_size)

		for x in start_x ..< end_x {
			deco_tile := get_deco_tile(x, y)
			if deco_tile == nil || deco_tile.type == .EMPTY do continue

			world_x := f32(x * tilemap.tile_size)

			source_rect := get_tile_source_rect(deco_tile.type)
			dest_rect := rl.Rectangle {
				x      = world_x,
				y      = world_y,
				width  = f32(config.tile_size),
				height = f32(config.tile_size),
			}

			rl.DrawTexturePro(tilemap.tileset, source_rect, dest_rect, {0, 0}, 0, rl.WHITE)
		}
	}
}

fini :: proc() {
	if tilemap.base_tiles != nil {
		delete(tilemap.base_tiles)
		tilemap.base_tiles = nil
	}
	if tilemap.deco_tiles != nil {
		delete(tilemap.deco_tiles)
		tilemap.deco_tiles = nil
	}
	rl.UnloadTexture(tilemap.tileset)
}

/// Reset tilemap state for testing
reset_for_testing :: proc() {
	if tilemap.base_tiles != nil {
		delete(tilemap.base_tiles)
		tilemap.base_tiles = nil
	}
	if tilemap.deco_tiles != nil {
		delete(tilemap.deco_tiles)
		tilemap.deco_tiles = nil
	}
	tilemap.width = 0
	tilemap.height = 0
}
