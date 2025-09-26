package tilemap

import "core:math/rand"
import rl "vendor:raylib"

Vec2 :: rl.Vector2

TILE_SIZE :: 16
TILESET_WIDTH :: 64
TILESET_HEIGHT :: 50
TILESET_COLS :: 32

TileType :: enum u16 {
	GRASS_1 = 0,
	GRASS_2,
	GRASS_3,
	GRASS_4 = TILESET_COLS,
	GRASS_5,
	GRASS_6,
	GRASS_7 = TILESET_COLS * 2,
	GRASS_8,

	// grass decorations 
	GRASS_DEC_1 = TILESET_COLS * 8,
	GRASS_DEC_2,
	GRASS_DEC_3,
	GRASS_DEC_4,
	GRASS_DEC_5 = TILESET_COLS * 9,
	GRASS_DEC_6,
	GRASS_DEC_7,
	GRASS_DEC_8,
	GRASS_DEC_9 = TILESET_COLS * 10,
	GRASS_DEC_10,
	GRASS_DEC_11,
	GRASS_DEC_12,
	GRASS_DEC_13 = TILESET_COLS * 11,
	GRASS_DEC_14,
	GRASS_DEC_15,
	GRASS_DEC_16,

	// sand
	SAND_1 = 3,
	SAND_2,
	SAND_3,

	// sand decorations
	SAND_DEC_13 = TILESET_COLS * 12,
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
	tile_size = TILE_SIZE,
}

TilemapResource :: struct {
	width:        int,
	height:       int,
	tileset_path: string,
	base_data:    []TileType,
	deco_data:    []TileType,
}

init :: proc() {
	tilemap.tileset = rl.LoadTexture("res/art/tileset/spr_tileset_sunnysideworld_16px.png")

	tilemap.base_tiles = make([]Tile, tilemap.width * tilemap.height)
	tilemap.deco_tiles = make([]Tile, tilemap.width * tilemap.height)

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
			// Initialize deco tiles as empty
			tilemap.deco_tiles[index] = Tile {
				type  = .EMPTY,
				solid = false,
			}
		}
	}
}

load_from_config :: proc(config: TilemapResource) {
	if tilemap.base_tiles != nil {
		delete(tilemap.base_tiles)
	}
	if tilemap.deco_tiles != nil {
		delete(tilemap.deco_tiles)
	}
	if tilemap.tileset.id != 0 {
		rl.UnloadTexture(tilemap.tileset)
	}

	tilemap.width = config.width
	tilemap.height = config.height
	tilemap.tileset = rl.LoadTexture(cstring(raw_data(config.tileset_path)))

	tilemap.base_tiles = make([]Tile, tilemap.width * tilemap.height)
	tilemap.deco_tiles = make([]Tile, tilemap.width * tilemap.height)

	// Load base layer
	if len(config.base_data) > 0 {
		for i in 0 ..< min(len(config.base_data), len(tilemap.base_tiles)) {
			tilemap.base_tiles[i] = Tile {
				type  = config.base_data[i],
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
	if len(config.deco_data) > 0 {
		for i in 0 ..< min(len(config.deco_data), len(tilemap.deco_tiles)) {
			tilemap.deco_tiles[i] = Tile {
				type  = config.deco_data[i],
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
	tiles_per_row := TILESET_COLS

	source_x := (tile_id % tiles_per_row) * TILE_SIZE
	source_y := (tile_id / tiles_per_row) * TILE_SIZE

	return rl.Rectangle {
		x = f32(source_x),
		y = f32(source_y),
		width = TILE_SIZE,
		height = TILE_SIZE,
	}
}

world_to_tile :: proc(world_pos: Vec2) -> (int, int) {
	return int(world_pos.x / TILE_SIZE), int(world_pos.y / TILE_SIZE)
}

tile_to_world :: proc(tile_x, tile_y: int) -> Vec2 {
	return {f32(tile_x * TILE_SIZE), f32(tile_y * TILE_SIZE)}
}

is_tile_solid :: proc(x, y: int) -> bool {
	if tile := get_tile(x, y); tile != nil {
		return tile.solid
	}
	return true
}

check_collision :: proc(rect: rl.Rectangle) -> bool {
	left := int(rect.x / TILE_SIZE)
	right := int((rect.x + rect.width) / TILE_SIZE)
	top := int(rect.y / TILE_SIZE)
	bottom := int((rect.y + rect.height) / TILE_SIZE)

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

	start_x := max(0, int(world_min.x / TILE_SIZE) - 1)
	end_x := min(tilemap.width, int(world_max.x / TILE_SIZE) + 2)
	start_y := max(0, int(world_min.y / TILE_SIZE) - 1)
	end_y := min(tilemap.height, int(world_max.y / TILE_SIZE) + 2)

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
				width  = TILE_SIZE,
				height = TILE_SIZE,
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
				width  = TILE_SIZE,
				height = TILE_SIZE,
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
