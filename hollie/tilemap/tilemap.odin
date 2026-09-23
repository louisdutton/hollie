package tilemap

import "../content"
import "../graphics"
import "../spatial"
import "core:encoding/uuid"
import "core:strings"
import rl "vendor:raylib"

Vec2 :: rl.Vector2

TILE_SIZE :: 16 // width and height of one tile in world units

Entity_Type :: enum {
	Player         = 0,
	Enemy          = 1,
	Pressure_Plate = 2,
	Gate           = 3,
	Holdable       = 4,
	Npc            = 5,
	Door           = 6,
}

/// Configuration for tilemap rendering and behavior
Tilemap_Config :: struct {
	world_tile_size: int,
}

@(private)
config := Tilemap_Config {
	world_tile_size = TILE_SIZE,
}

Tile_Type :: enum u16 {
	Empty = 0,
	Water = 500,
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

Collision_Type :: enum u8 {
	Walkable = 0,
	Solid    = 1,
}

Structure_Data :: struct {
	instance_id: string,
	position:    Vec2,
	size:        Vec2,
}


Entity_Data :: struct {
	instance_id:       string,
	x:                 int,
	y:                 int,
	entity_type:       Entity_Type,
	player_index:      int,
	character_kind:    content.Character_Kind,
	trigger_id:        int,
	gate_id:           int,
	requires_both:     bool,
	inverted:          bool,
	breakable:         bool,
	width:             int,
	height:            int,
	target_room:       string,
	target_door:       string,
	required_triggers: [dynamic]int,
}

Tile_Map :: struct {
	width:            int,
	height:           int,
	base_tiles:       []Tile_Type,
	deco_tiles:       []Tile_Type,
	collision_tiles:  []Collision_Type,
	grass_density:    []u8,
	structures:       []Structure_Data,
	entities:         []Entity_Data,
	tile_size:        int,
	config:           Tilemap_Config,
	room_id:          string,
	room_name:        string,
	music_path:       string,
	interior:         bool,
	camera_bounds:    graphics.Rect,
	collision_bounds: graphics.Rect,
}

has_floor :: proc(x, y: int) -> bool {
	if x < 0 || y < 0 || x >= get_tilemap_width() || y >= get_tilemap_height() do return false
	tile := get_base_tile(x, y)
	return tile != nil && tile^ != .Empty
}

entity_type_is_valid :: proc(entity_type: Entity_Type) -> bool {
	switch entity_type {
	case .Player, .Enemy, .Pressure_Plate, .Gate, .Holdable, .Npc, .Door: return true
	case: return false
	}
}

clone_entity_data :: proc(entity: Entity_Data, allocator := context.allocator) -> Entity_Data {
	cloned := entity
	cloned.instance_id = strings.clone(entity.instance_id, allocator)
	cloned.target_room = strings.clone(entity.target_room, allocator)
	cloned.target_door = strings.clone(entity.target_door, allocator)
	cloned.required_triggers = make([dynamic]int, len(entity.required_triggers), allocator)
	copy(cloned.required_triggers[:], entity.required_triggers[:])
	return cloned
}

destroy_entity_data :: proc(entity: ^Entity_Data, allocator := context.allocator) {
	if entity == nil do return

	delete(entity.instance_id, allocator)
	delete(entity.target_room, allocator)
	delete(entity.target_door, allocator)
	delete(entity.required_triggers)
	entity^ = {}
}

destroy_tilemap :: proc(tm: ^Tile_Map, allocator := context.allocator) {
	if tm == nil do return

	delete(tm.base_tiles, allocator)
	delete(tm.deco_tiles, allocator)
	delete(tm.collision_tiles, allocator)
	delete(tm.grass_density, allocator)
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
tilemap := Tile_Map {
	width = 50,
	height = 30,
	tile_size = TILE_SIZE,
	config = {world_tile_size = TILE_SIZE},
}

load_tilemap :: proc(new_tilemap: Tile_Map) {
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
	tilemap.interior = new_tilemap.interior
	tilemap.camera_bounds = new_tilemap.camera_bounds
	tilemap.collision_bounds = new_tilemap.collision_bounds

	// Copy tile data
	tilemap.base_tiles = make([]Tile_Type, len(new_tilemap.base_tiles))
	copy(tilemap.base_tiles, new_tilemap.base_tiles)

	tilemap.deco_tiles = make([]Tile_Type, len(new_tilemap.deco_tiles))
	copy(tilemap.deco_tiles, new_tilemap.deco_tiles)

	tilemap.collision_tiles = make([]Collision_Type, len(new_tilemap.collision_tiles))
	copy(tilemap.collision_tiles, new_tilemap.collision_tiles)

	tilemap.grass_density = make([]u8, len(new_tilemap.grass_density))
	copy(tilemap.grass_density, new_tilemap.grass_density)

	tilemap.structures = make([]Structure_Data, len(new_tilemap.structures))
	for structure, index in new_tilemap.structures {
		tilemap.structures[index] = structure
		tilemap.structures[index].instance_id = strings.clone(structure.instance_id)
	}

	// Copy entity data
	if len(new_tilemap.entities) > 0 {
		tilemap.entities = make([]Entity_Data, len(new_tilemap.entities))
		for i in 0 ..< len(new_tilemap.entities) {
			tilemap.entities[i] = clone_entity_data(new_tilemap.entities[i])
		}
	}
}

get_tile :: proc(x, y: int) -> ^Tile_Type {
	return get_base_tile(x, y)
}

get_base_tile :: proc(x, y: int) -> ^Tile_Type {
	if x < 0 || x >= tilemap.width || y < 0 || y >= tilemap.height {
		return nil
	}
	index := y * tilemap.width + x
	if index >= len(tilemap.base_tiles) do return nil
	return &tilemap.base_tiles[index]
}

get_deco_tile :: proc(x, y: int) -> ^Tile_Type {
	if x < 0 || x >= tilemap.width || y < 0 || y >= tilemap.height {
		return nil
	}
	index := y * tilemap.width + x
	if index >= len(tilemap.deco_tiles) {
		return nil
	}
	return &tilemap.deco_tiles[index]
}

get_collision_tile :: proc(x, y: int) -> ^Collision_Type {
	if x < 0 || x >= tilemap.width || y < 0 || y >= tilemap.height {
		return nil
	}
	index := y * tilemap.width + x
	if index >= len(tilemap.collision_tiles) {
		return nil
	}
	return &tilemap.collision_tiles[index]
}

get_grass_density :: proc(x, y: int) -> u8 {
	if x < 0 || x >= tilemap.width || y < 0 || y >= tilemap.height do return 0
	index := y * tilemap.width + x
	if index >= len(tilemap.grass_density) do return 0
	return tilemap.grass_density[index]
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

get_entities :: proc() -> []Entity_Data {
	return tilemap.entities
}

get_current_tilemap :: proc() -> ^Tile_Map {
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

get_camera_bounds :: proc() -> graphics.Rect {
	return tilemap.camera_bounds
}

get_collision_bounds :: proc() -> graphics.Rect {
	return tilemap.collision_bounds
}

add_entity :: proc(x, y: int, entity_type: Entity_Type) {
	entity := Entity_Data {
		instance_id       = uuid.to_string(uuid.generate_v4()),
		x                 = x,
		y                 = y,
		entity_type       = entity_type,
		width             = TILE_SIZE,
		height            = TILE_SIZE,
		required_triggers = make([dynamic]int),
	}

	temp_entities := make([dynamic]Entity_Data, len(tilemap.entities))
	copy(temp_entities[:], tilemap.entities[:])
	append(&temp_entities, entity)

	delete(tilemap.entities)
	tilemap.entities = make([]Entity_Data, len(temp_entities))
	copy(tilemap.entities, temp_entities[:])
	delete(temp_entities)
}

remove_entity_at :: proc(x, y: int) -> bool {
	for i in 0 ..< len(tilemap.entities) {
		entity := &tilemap.entities[i]
		if entity.x == x && entity.y == y {
			destroy_entity_data(entity)

			temp_entities := make([dynamic]Entity_Data, 0, len(tilemap.entities) - 1)
			for j in 0 ..< len(tilemap.entities) {
				if j != i {
					append(&temp_entities, tilemap.entities[j])
				}
			}

			delete(tilemap.entities)
			tilemap.entities = make([]Entity_Data, len(temp_entities))
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

check_collision :: proc(aabb: spatial.Aabb) -> bool {
	tile_size_f := f32(config.world_tile_size)
	map_width := f32(tilemap.width * config.world_tile_size)
	map_height := f32(tilemap.height * config.world_tile_size)
	if aabb.min.x < 0 || aabb.min.z < 0 || aabb.max.x > map_width || aabb.max.z > map_height {
		return true
	}

	left := int(aabb.min.x / tile_size_f)
	right := int((aabb.max.x - 0.001) / tile_size_f)
	top := int(aabb.min.z / tile_size_f)
	bottom := int((aabb.max.z - 0.001) / tile_size_f)

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
