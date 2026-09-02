package tilemap

import "../asset"
import "../content"
import "../renderer"
import "../window"
import "core:encoding/uuid"
import "core:strings"
import rl "vendor:raylib"

Vec2 :: rl.Vector2

TILE_SIZE :: 16

EntityType :: enum {
	PLAYER         = 0,
	ENEMY          = 1,
	PRESSURE_PLATE = 2,
	GATE           = 3,
	HOLDABLE       = 4,
	NPC            = 5,
	DOOR           = 6,
}

/// Configuration for tilemap rendering and behavior
TilemapConfig :: struct {
	world_tile_size:  int,
	source_tile_size: int,
	tileset_cols:     int,
	smooth:           bool,
}

@(private)
config := TilemapConfig {
	world_tile_size  = TILE_SIZE,
	source_tile_size = TILE_SIZE,
	tileset_cols     = 32,
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

CollisionType :: enum u8 {
	WALKABLE = 0,
	SOLID    = 1,
}

SceneryData :: struct {
	instance_id:  string,
	texture_path: string,
	position:     Vec2,
	size:         Vec2,
	texture:      renderer.Texture2D,
	smooth:       bool,
}


EntityData :: struct {
	instance_id:       string,
	x:                 int,
	y:                 int,
	entity_type:       EntityType,
	player_index:      int,
	character_kind:    content.Character_Kind,
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
	collision_tiles:  []CollisionType,
	scenery:          []SceneryData,
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

clone_entity_data :: proc(entity: EntityData, allocator := context.allocator) -> EntityData {
	cloned := entity
	cloned.instance_id = strings.clone(entity.instance_id, allocator)
	cloned.texture_path = strings.clone(entity.texture_path, allocator)
	cloned.target_room = strings.clone(entity.target_room, allocator)
	cloned.target_door = strings.clone(entity.target_door, allocator)
	cloned.required_triggers = make([dynamic]int, len(entity.required_triggers), allocator)
	copy(cloned.required_triggers[:], entity.required_triggers[:])
	return cloned
}

destroy_entity_data :: proc(entity: ^EntityData, allocator := context.allocator) {
	if entity == nil do return

	delete(entity.instance_id, allocator)
	delete(entity.texture_path, allocator)
	delete(entity.target_room, allocator)
	delete(entity.target_door, allocator)
	delete(entity.required_triggers)
	entity^ = {}
}

destroy_tilemap :: proc(tm: ^TileMap, allocator := context.allocator) {
	if tm == nil do return

	delete(tm.base_tiles, allocator)
	delete(tm.deco_tiles, allocator)
	delete(tm.collision_tiles, allocator)
	for &scenery in tm.scenery {
		delete(scenery.instance_id, allocator)
		delete(scenery.texture_path, allocator)
		if scenery.texture.id != 0 do renderer.unload_texture(scenery.texture)
	}
	delete(tm.scenery, allocator)
	for &entity in tm.entities {
		destroy_entity_data(&entity, allocator)
	}
	delete(tm.entities, allocator)
	if tm.tileset.id != 0 {
		renderer.unload_texture(tm.tileset)
	}
	delete(tm.tileset_path, allocator)
	delete(tm.room_id, allocator)
	delete(tm.room_name, allocator)
	delete(tm.music_path, allocator)
	tm^ = {}
}

@(private)
tilemap := TileMap {
	width = 50,
	height = 30,
	tile_size = TILE_SIZE,
	config = {world_tile_size = TILE_SIZE, source_tile_size = TILE_SIZE, tileset_cols = 32},
}

load_tilemap :: proc(new_tilemap: TileMap) {
	destroy_tilemap(&tilemap)

	// Update global config
	config = new_tilemap.config

	// Copy all metadata
	tilemap.width = new_tilemap.width
	tilemap.height = new_tilemap.height
	tilemap.tile_size = new_tilemap.config.world_tile_size
	tilemap.tileset_path = strings.clone(new_tilemap.tileset_path)
	tilemap.config = new_tilemap.config
	tilemap.room_id = strings.clone(new_tilemap.room_id)
	tilemap.room_name = strings.clone(new_tilemap.room_name)
	tilemap.music_path = strings.clone(new_tilemap.music_path)
	tilemap.camera_bounds = new_tilemap.camera_bounds
	tilemap.collision_bounds = new_tilemap.collision_bounds

	// Load texture
	tilemap.tileset = renderer.load_texture(asset.path(new_tilemap.tileset_path))
	rl.SetTextureFilter(tilemap.tileset, new_tilemap.config.smooth ? .BILINEAR : .POINT)

	// Copy tile data
	tilemap.base_tiles = make([]TileType, len(new_tilemap.base_tiles))
	copy(tilemap.base_tiles, new_tilemap.base_tiles)

	tilemap.deco_tiles = make([]TileType, len(new_tilemap.deco_tiles))
	copy(tilemap.deco_tiles, new_tilemap.deco_tiles)

	tilemap.collision_tiles = make([]CollisionType, len(new_tilemap.collision_tiles))
	copy(tilemap.collision_tiles, new_tilemap.collision_tiles)

	tilemap.scenery = make([]SceneryData, len(new_tilemap.scenery))
	for scenery, index in new_tilemap.scenery {
		tilemap.scenery[index] = scenery
		tilemap.scenery[index].instance_id = strings.clone(scenery.instance_id)
		tilemap.scenery[index].texture_path = strings.clone(scenery.texture_path)
		tilemap.scenery[index].texture = renderer.load_texture(asset.path(scenery.texture_path))
		rl.SetTextureFilter(tilemap.scenery[index].texture, scenery.smooth ? .BILINEAR : .POINT)
	}

	// Copy entity data
	if len(new_tilemap.entities) > 0 {
		tilemap.entities = make([]EntityData, len(new_tilemap.entities))
		for i in 0 ..< len(new_tilemap.entities) {
			tilemap.entities[i] = clone_entity_data(new_tilemap.entities[i])
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

get_collision_tile :: proc(x, y: int) -> ^CollisionType {
	if x < 0 || x >= tilemap.width || y < 0 || y >= tilemap.height {
		return nil
	}
	index := y * tilemap.width + x
	if index >= len(tilemap.collision_tiles) {
		return nil
	}
	return &tilemap.collision_tiles[index]
}

get_tile_source_rect :: proc(tile_type: TileType) -> renderer.Rect {
	if tile_type == .EMPTY {
		return {}
	}

	tile_id := int(tile_type) - 1
	tiles_per_row := config.tileset_cols

	source_x := (tile_id % tiles_per_row) * config.source_tile_size
	source_y := (tile_id / tiles_per_row) * config.source_tile_size

	return renderer.Rect {
		x = f32(source_x),
		y = f32(source_y),
		width = f32(config.source_tile_size),
		height = f32(config.source_tile_size),
	}
}

get_tileset :: proc() -> renderer.Texture2D {
	return tilemap.tileset
}

get_tile_size :: proc() -> int {
	return config.world_tile_size
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
		instance_id       = uuid.to_string(uuid.generate_v4()),
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
			destroy_entity_data(entity)

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
	return int(
		world_pos.x / f32(config.world_tile_size),
	), int(world_pos.y / f32(config.world_tile_size))
}

tile_to_world :: proc(tile_x, tile_y: int) -> Vec2 {
	return {f32(tile_x * config.world_tile_size), f32(tile_y * config.world_tile_size)}
}

is_tile_solid :: proc(x, y: int) -> bool {
	tile := get_collision_tile(x, y)
	return tile == nil || tile^ == .SOLID
}

check_collision :: proc(rect: renderer.Rect) -> bool {
	tile_size_f := f32(config.world_tile_size)
	map_width := f32(tilemap.width * config.world_tile_size)
	map_height := f32(tilemap.height * config.world_tile_size)
	if rect.x < 0 ||
	   rect.y < 0 ||
	   rect.x + rect.width > map_width ||
	   rect.y + rect.height > map_height {
		return true
	}

	left := int(rect.x / tile_size_f)
	right := int((rect.x + rect.width - 0.001) / tile_size_f)
	top := int(rect.y / tile_size_f)
	bottom := int((rect.y + rect.height - 0.001) / tile_size_f)

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

	tile_size_f := f32(config.world_tile_size)
	start_x := max(0, int(world_min.x / tile_size_f) - 1)
	end_x := min(tilemap.width, int(world_max.x / tile_size_f) + 2)
	start_y := max(0, int(world_min.y / tile_size_f) - 1)
	end_y := min(tilemap.height, int(world_max.y / tile_size_f) + 2)

	// Draw base layer first
	for y in start_y ..< end_y {
		world_y := f32(y * tilemap.tile_size)

		for x in start_x ..< end_x {
			base_tile := get_base_tile(x, y)
			if base_tile == nil || base_tile^ == .EMPTY do continue

			world_x := f32(x * tilemap.tile_size)

			source_rect := get_tile_source_rect(base_tile^)
			dest_rect := renderer.Rect {
				x      = world_x,
				y      = world_y,
				width  = f32(config.world_tile_size),
				height = f32(config.world_tile_size),
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
				width  = f32(config.world_tile_size),
				height = f32(config.world_tile_size),
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

	// Draw standalone scenery images after tiles and before gameplay entities.
	for scenery in tilemap.scenery {
		if scenery.texture.id == 0 do continue
		renderer.draw_texture_pro(
			scenery.texture,
			{0, 0, f32(scenery.texture.width), f32(scenery.texture.height)},
			{scenery.position.x, scenery.position.y, scenery.size.x, scenery.size.y},
			{},
			0,
			renderer.WHITE,
		)
	}
}

fini :: proc() {
	destroy_tilemap(&tilemap)
}
