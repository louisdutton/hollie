package hollie

import "core:math"
import rl "vendor:raylib"

TILE_SIZE :: 16
TILESET_WIDTH :: 64
TILESET_HEIGHT :: 50

TileType :: enum u16 {
	GRASS_1 = 192,
	GRASS_2,
	GRASS_3,
	GRASS_4,
	DIRT_1,
	DIRT_2,
	DIRT_3,
	DIRT_4,
	WATER_1,
	WATER_2,
	WATER_3,
	WATER_4,
	STONE_1,
	STONE_2,
	STONE_3,
	STONE_4,
}

Tile :: struct {
	type:     TileType,
	position: rl.Vector2,
	solid:    bool,
}

TileMap :: struct {
	width:     int,
	height:    int,
	tiles:     []Tile,
	tileset:   rl.Texture2D,
	tile_size: int,
}

tilemap := TileMap {
	width     = 50,
	height    = 30,
	tile_size = TILE_SIZE,
}

init_tilemap :: proc() {
	tilemap.tileset = rl.LoadTexture("res/art/tileset/spr_tileset_sunnysideworld_16px.png")

	tilemap.tiles = make([]Tile, tilemap.width * tilemap.height)

	for y in 0 ..< tilemap.height {
		for x in 0 ..< tilemap.width {
			index := y * tilemap.width + x
			tilemap.tiles[index] = Tile {
				type     = .GRASS_1,
				position = {f32(x * tilemap.tile_size), f32(y * tilemap.tile_size)},
				solid    = false,
			}
		}
	}
}

get_tile :: proc(x, y: int) -> ^Tile {
	if x < 0 || x >= tilemap.width || y < 0 || y >= tilemap.height {
		return nil
	}
	index := y * tilemap.width + x
	return &tilemap.tiles[index]
}

set_tile :: proc(x, y: int, tile_type: TileType, solid: bool = false) {
	if tile := get_tile(x, y); tile != nil {
		tile.type = tile_type
		tile.solid = solid
	}
}

get_tile_source_rect :: proc(tile_type: TileType) -> rl.Rectangle {
	tile_id := int(tile_type)
	tiles_per_row := TILESET_WIDTH

	source_x := (tile_id % tiles_per_row) * TILE_SIZE
	source_y := (tile_id / tiles_per_row) * TILE_SIZE

	return rl.Rectangle {
		x = f32(source_x),
		y = f32(source_y),
		width = TILE_SIZE,
		height = TILE_SIZE,
	}
}

world_to_tile :: proc(world_pos: rl.Vector2) -> (int, int) {
	return int(world_pos.x / TILE_SIZE), int(world_pos.y / TILE_SIZE)
}

tile_to_world :: proc(tile_x, tile_y: int) -> rl.Vector2 {
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

update_tilemap :: proc() {

}

draw_tilemap :: proc(camera: rl.Camera2D) {
	screen_width := f32(rl.GetScreenWidth())
	screen_height := f32(rl.GetScreenHeight())

	world_min := rl.GetScreenToWorld2D({0, 0}, camera)
	world_max := rl.GetScreenToWorld2D({screen_width, screen_height}, camera)

	start_x := max(0, int(world_min.x / TILE_SIZE) - 1)
	end_x := min(tilemap.width, int(world_max.x / TILE_SIZE) + 2)
	start_y := max(0, int(world_min.y / TILE_SIZE) - 1)
	end_y := min(tilemap.height, int(world_max.y / TILE_SIZE) + 2)

	for y in start_y ..< end_y {
		for x in start_x ..< end_x {
			tile := get_tile(x, y)
			if tile == nil do continue

			source_rect := get_tile_source_rect(tile.type)
			dest_rect := rl.Rectangle {
				x      = tile.position.x,
				y      = tile.position.y,
				width  = TILE_SIZE,
				height = TILE_SIZE,
			}

			rl.DrawTexturePro(tilemap.tileset, source_rect, dest_rect, {0, 0}, 0, rl.WHITE)
		}
	}
}

generate_test_map :: proc() {
	for y in 0 ..< tilemap.height {
		for x in 0 ..< tilemap.width {
			// TODO: map generation logic

			set_tile(x, y, .GRASS_1, false)
		}
	}
}

unload_tilemap :: proc() {
	if tilemap.tiles != nil {
		delete(tilemap.tiles)
	}
	rl.UnloadTexture(tilemap.tileset)
}
