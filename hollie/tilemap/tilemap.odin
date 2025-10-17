package tilemap

import "../asset"
import "../renderer"
import "../window"
import "core:strings"
import rl "vendor:raylib"

Vec2 :: rl.Vector2

TILE_SIZE :: 16

EntityType :: enum {
	ENEMY          = 1,
	PRESSURE_PLATE = 2,
	GATE           = 3,
	HOLDABLE       = 4,
	NPC            = 5,
	DOOR           = 6,
}

/// Configuration for tilemap rendering and behavior
TilemapConfig :: struct {
	tile_size:    int,
	tileset_cols: int,
}

@(private)
config := TilemapConfig {
	tile_size    = TILE_SIZE,
	tileset_cols = 32,
}

TileType :: enum u16 {
	EMPTY = 0,
	GRASS_1 = 1,
	GRASS_2,
	GRASS_3,
	GRASS_4 = 33,
	GRASS_5,
	GRASS_6,
	GRASS_7 = 65,
	GRASS_8,

	// grass decorations
	GRASS_DEC_1 = 257,
	GRASS_DEC_2,
	GRASS_DEC_3,
	GRASS_DEC_4,
	GRASS_DEC_5 = 289,
	GRASS_DEC_6,
	GRASS_DEC_7,
	GRASS_DEC_8,
	GRASS_DEC_9 = 321,
	GRASS_DEC_10,
	GRASS_DEC_11,
	GRASS_DEC_12,
	GRASS_DEC_13 = 353,
	GRASS_DEC_14,
	GRASS_DEC_15,
	GRASS_DEC_16,

	// sand
	SAND_1 = 4,
	SAND_2,
	SAND_3,

	// sand decorations
	SAND_DEC_13 = 385,
	SAND_DEC_14,
	SAND_DEC_15,
	SAND_DEC_16,

	// walls and structures
	WALL_1 = 7,
	WALL_2,
	WALL_3,
	WALL_TOP = 39,
	WALL_BOTTOM,
	WALL_LEFT,
	WALL_RIGHT,
	WALL_CORNER_TL = 71,
	WALL_CORNER_TR,
	WALL_CORNER_BL = 103,
	WALL_CORNER_BR,

	// doors
	DOOR_HORIZONTAL = 11,
	DOOR_VERTICAL = 43,
}


EntityData :: struct {
	x:                 int,
	y:                 int,
	entity_type:       EntityType,
	trigger_id:        int,
	gate_id:           int,
	requires_both:     bool,
	inverted:          bool,
	width:             int,
	height:            int,
	texture_path:      string,
	target_room:       string,
	target_door:       string,
	required_triggers: [dynamic]int,
}

TileMap :: struct {
	width:            int,
	height:           int,
	base_tiles:       []TileType,
	deco_tiles:       []TileType,
	entities:         []EntityData,
	tileset:          renderer.Texture2D,
	tile_size:        int,
	tileset_path:     string,
	config:           TilemapConfig,
	room_id:          string,
	room_name:        string,
	music_path:       string,
	camera_bounds:    renderer.Rect,
	collision_bounds: renderer.Rect,
}

@(private)
tilemap := TileMap {
	width = 50,
	height = 30,
	tile_size = TILE_SIZE,
	config = {tile_size = TILE_SIZE, tileset_cols = 32},
}

load_tilemap :: proc(new_tilemap: TileMap) {
	if tilemap.base_tiles != nil {
		delete(tilemap.base_tiles)
	}
	if tilemap.deco_tiles != nil {
		delete(tilemap.deco_tiles)
	}
	if tilemap.entities != nil {
		for &entity in tilemap.entities {
			delete(entity.required_triggers)
		}
		delete(tilemap.entities)
	}
	if tilemap.tileset.id != 0 {
		renderer.unload_texture(tilemap.tileset)
	}

	// Update global config
	config = new_tilemap.config

	// Copy all metadata
	tilemap.width = new_tilemap.width
	tilemap.height = new_tilemap.height
	tilemap.tile_size = new_tilemap.config.tile_size
	tilemap.tileset_path = strings.clone(new_tilemap.tileset_path)
	tilemap.config = new_tilemap.config
	tilemap.room_id = strings.clone(new_tilemap.room_id)
	tilemap.room_name = strings.clone(new_tilemap.room_name)
	tilemap.music_path = strings.clone(new_tilemap.music_path)
	tilemap.camera_bounds = new_tilemap.camera_bounds
	tilemap.collision_bounds = new_tilemap.collision_bounds

	// Load texture
	tilemap.tileset = renderer.load_texture(asset.path(new_tilemap.tileset_path))

	// Copy tile data
	tilemap.base_tiles = make([]TileType, len(new_tilemap.base_tiles))
	copy(tilemap.base_tiles, new_tilemap.base_tiles)

	tilemap.deco_tiles = make([]TileType, len(new_tilemap.deco_tiles))
	copy(tilemap.deco_tiles, new_tilemap.deco_tiles)

	// Copy entity data
	if len(new_tilemap.entities) > 0 {
		tilemap.entities = make([]EntityData, len(new_tilemap.entities))
		for i in 0 ..< len(new_tilemap.entities) {
			tilemap.entities[i] = new_tilemap.entities[i]
			// Copy required_triggers array
			tilemap.entities[i].required_triggers = make(
				[dynamic]int,
				len(new_tilemap.entities[i].required_triggers),
			)
			copy(
				tilemap.entities[i].required_triggers[:],
				new_tilemap.entities[i].required_triggers[:],
			)
		}
	}
}

get_tile :: proc(x, y: int) -> ^TileType {
	return get_base_tile(x, y)
}

get_base_tile :: proc(x, y: int) -> ^TileType {
	if x < 0 || x >= tilemap.width || y < 0 || y >= tilemap.height {
		return nil
	}
	index := y * tilemap.width + x
	return &tilemap.base_tiles[index]
}

get_deco_tile :: proc(x, y: int) -> ^TileType {
	if x < 0 || x >= tilemap.width || y < 0 || y >= tilemap.height {
		return nil
	}
	index := y * tilemap.width + x
	if index >= len(tilemap.deco_tiles) {
		return nil
	}
	return &tilemap.deco_tiles[index]
}

get_tile_source_rect :: proc(tile_type: TileType) -> renderer.Rect {
	if tile_type == .EMPTY {
		return {}
	}

	tile_id := int(tile_type) - 1
	tiles_per_row := config.tileset_cols

	source_x := (tile_id % tiles_per_row) * config.tile_size
	source_y := (tile_id / tiles_per_row) * config.tile_size

	return renderer.Rect {
		x = f32(source_x),
		y = f32(source_y),
		width = f32(config.tile_size),
		height = f32(config.tile_size),
	}
}

get_tileset :: proc() -> renderer.Texture2D {
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

get_entities :: proc() -> []EntityData {
	return tilemap.entities
}

get_current_tilemap :: proc() -> ^TileMap {
	return &tilemap
}

get_room_id :: proc() -> string {
	return tilemap.room_id
}

get_room_name :: proc() -> string {
	return tilemap.room_name
}

get_music_path :: proc() -> string {
	return tilemap.music_path
}

get_camera_bounds :: proc() -> renderer.Rect {
	return tilemap.camera_bounds
}

get_collision_bounds :: proc() -> renderer.Rect {
	return tilemap.collision_bounds
}

add_entity :: proc(x, y: int, entity_type: EntityType) {
	entity := EntityData {
		x                 = x,
		y                 = y,
		entity_type       = entity_type,
		width             = TILE_SIZE,
		height            = TILE_SIZE,
		required_triggers = make([dynamic]int),
	}

	temp_entities := make([dynamic]EntityData, len(tilemap.entities))
	copy(temp_entities[:], tilemap.entities[:])
	append(&temp_entities, entity)

	delete(tilemap.entities)
	tilemap.entities = make([]EntityData, len(temp_entities))
	copy(tilemap.entities, temp_entities[:])
	delete(temp_entities)
}

remove_entity_at :: proc(x, y: int) -> bool {
	for i in 0 ..< len(tilemap.entities) {
		entity := &tilemap.entities[i]
		if entity.x == x && entity.y == y {
			delete(entity.required_triggers)

			temp_entities := make([dynamic]EntityData, 0, len(tilemap.entities) - 1)
			for j in 0 ..< len(tilemap.entities) {
				if j != i {
					append(&temp_entities, tilemap.entities[j])
				}
			}

			delete(tilemap.entities)
			tilemap.entities = make([]EntityData, len(temp_entities))
			copy(tilemap.entities, temp_entities[:])
			delete(temp_entities)
			return true
		}
	}
	return false
}

world_to_tile :: proc(world_pos: Vec2) -> (int, int) {
	return int(world_pos.x / f32(config.tile_size)), int(world_pos.y / f32(config.tile_size))
}

tile_to_world :: proc(tile_x, tile_y: int) -> Vec2 {
	return {f32(tile_x * config.tile_size), f32(tile_y * config.tile_size)}
}

is_tile_solid :: proc(x, y: int) -> bool {
	return false
}

check_collision :: proc(rect: renderer.Rect) -> bool {
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

draw :: proc(camera: renderer.Camera2D) {
	screen_width := f32(window.get_screen_width())
	screen_height := f32(window.get_screen_height())

	world_min := renderer.get_screen_to_world_2d({0, 0}, camera)
	world_max := renderer.get_screen_to_world_2d({screen_width, screen_height}, camera)

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

			source_rect := get_tile_source_rect(base_tile^)
			dest_rect := renderer.Rect {
				x      = world_x,
				y      = world_y,
				width  = f32(config.tile_size),
				height = f32(config.tile_size),
			}

			renderer.draw_texture_pro(
				tilemap.tileset,
				source_rect,
				dest_rect,
				{0, 0},
				0,
				renderer.WHITE,
			)
		}
	}

	// Draw decorative layer on top
	for y in start_y ..< end_y {
		world_y := f32(y * tilemap.tile_size)

		for x in start_x ..< end_x {
			deco_tile := get_deco_tile(x, y)
			if deco_tile == nil || deco_tile^ == .EMPTY do continue

			world_x := f32(x * tilemap.tile_size)

			source_rect := get_tile_source_rect(deco_tile^)
			dest_rect := renderer.Rect {
				x      = world_x,
				y      = world_y,
				width  = f32(config.tile_size),
				height = f32(config.tile_size),
			}

			renderer.draw_texture_pro(
				tilemap.tileset,
				source_rect,
				dest_rect,
				{0, 0},
				0,
				renderer.WHITE,
			)
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
	if tilemap.entities != nil {
		for &entity in tilemap.entities {
			delete(entity.required_triggers)
		}
		delete(tilemap.entities)
		tilemap.entities = nil
	}
	if tilemap.tileset.id != 0 {
		renderer.unload_texture(tilemap.tileset)
	}
	// Clean up metadata strings
	delete(tilemap.tileset_path)
	delete(tilemap.room_id)
	delete(tilemap.room_name)
	delete(tilemap.music_path)
}
