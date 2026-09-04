package tilemap

import "../content"
import "../renderer"
import "core:encoding/uuid"
import "core:strings"
import rl "vendor:raylib"

Vec2 :: rl.Vector2

TILE_SIZE :: 16

EntityType :: enum {
	Player         = 0,
	Enemy          = 1,
	Pressure_Plate = 2,
	Gate           = 3,
	Holdable       = 4,
	Npc            = 5,
	Door           = 6,
}

/// Configuration for tilemap rendering and behavior
TilemapConfig :: struct {
	world_tile_size: int,
}

@(private)
config := TilemapConfig {
	world_tile_size = TILE_SIZE,
}

TileType :: enum u16 {
	Empty = 0,
	Grass_1 = 1,
	Grass_2,
	Grass_3,
	Grass_4 = 33,
	Grass_5,
	Grass_6,
	Grass_7 = 65,
	Grass_8,

	// grass decorations
	Grass_Dec_1 = 257,
	Grass_Dec_2,
	Grass_Dec_3,
	Grass_Dec_4,
	Grass_Dec_5 = 289,
	Grass_Dec_6,
	Grass_Dec_7,
	Grass_Dec_8,
	Grass_Dec_9 = 321,
	Grass_Dec_10,
	Grass_Dec_11,
	Grass_Dec_12,
	Grass_Dec_13 = 353,
	Grass_Dec_14,
	Grass_Dec_15,
	Grass_Dec_16,

	// sand
	Sand_1 = 4,
	Sand_2,
	Sand_3,

	// sand decorations
	Sand_Dec_13 = 385,
	Sand_Dec_14,
	Sand_Dec_15,
	Sand_Dec_16,

	// walls and structures
	Wall_1 = 7,
	Wall_2,
	Wall_3,
	Wall_Top = 39,
	Wall_Bottom,
	Wall_Left,
	Wall_Right,
	Wall_Corner_Top_Left = 71,
	Wall_Corner_Top_Right,
	Wall_Corner_Bottom_Left = 103,
	Wall_Corner_Bottom_Right,

	// doors
	Door_Horizontal = 11,
	Door_Vertical = 43,
}

CollisionType :: enum u8 {
	Walkable = 0,
	Solid    = 1,
}

Structure_Data :: struct {
	instance_id: string,
	position:    Vec2,
	size:        Vec2,
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
	structures:       []Structure_Data,
	entities:         []EntityData,
	tile_size:        int,
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
	cloned.target_room = strings.clone(entity.target_room, allocator)
	cloned.target_door = strings.clone(entity.target_door, allocator)
	cloned.required_triggers = make([dynamic]int, len(entity.required_triggers), allocator)
	copy(cloned.required_triggers[:], entity.required_triggers[:])
	return cloned
}

destroy_entity_data :: proc(entity: ^EntityData, allocator := context.allocator) {
	if entity == nil do return

	delete(entity.instance_id, allocator)
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
	for &structure in tm.structures {
		delete(structure.instance_id, allocator)
	}
	delete(tm.structures, allocator)
	for &entity in tm.entities {
		destroy_entity_data(&entity, allocator)
	}
	delete(tm.entities, allocator)
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
	config = {world_tile_size = TILE_SIZE},
}

load_tilemap :: proc(new_tilemap: TileMap) {
	destroy_tilemap(&tilemap)

	// Update global config
	config = new_tilemap.config

	// Copy all metadata
	tilemap.width = new_tilemap.width
	tilemap.height = new_tilemap.height
	tilemap.tile_size = new_tilemap.config.world_tile_size
	tilemap.config = new_tilemap.config
	tilemap.room_id = strings.clone(new_tilemap.room_id)
	tilemap.room_name = strings.clone(new_tilemap.room_name)
	tilemap.music_path = strings.clone(new_tilemap.music_path)
	tilemap.camera_bounds = new_tilemap.camera_bounds
	tilemap.collision_bounds = new_tilemap.collision_bounds

	// Copy tile data
	tilemap.base_tiles = make([]TileType, len(new_tilemap.base_tiles))
	copy(tilemap.base_tiles, new_tilemap.base_tiles)

	tilemap.deco_tiles = make([]TileType, len(new_tilemap.deco_tiles))
	copy(tilemap.deco_tiles, new_tilemap.deco_tiles)

	tilemap.collision_tiles = make([]CollisionType, len(new_tilemap.collision_tiles))
	copy(tilemap.collision_tiles, new_tilemap.collision_tiles)

	tilemap.structures = make([]Structure_Data, len(new_tilemap.structures))
	for structure, index in new_tilemap.structures {
		tilemap.structures[index] = structure
		tilemap.structures[index].instance_id = strings.clone(structure.instance_id)
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
	return tile == nil || tile^ == .Solid
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

fini :: proc() {
	destroy_tilemap(&tilemap)
}
