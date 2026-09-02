package tilemap

import json "core:encoding/json"
import "core:fmt"

Room_File_Size :: struct {
	width:  int,
	height: int,
}

Room_File_Bounds :: struct {
	x:      f32,
	y:      f32,
	width:  f32,
	height: f32,
}

Room_File_Tileset :: struct {
	path:             string,
	tile_size:        int,
	source_tile_size: int `json:"source_tile_size,omitempty"`,
	columns:          int,
	smooth:           bool `json:"smooth,omitempty"`,
}

Room_File_Layers :: struct {
	base:       []u16,
	decoration: []u16,
	collision:  []u8,
}

Room_File_Scenery :: struct {
	id:           string,
	texture_path: string,
	position:     Room_File_Position,
	size:         Room_File_Size,
	smooth:       bool `json:"smooth,omitempty"`,
}

Room_File_Common :: struct {
	id:               string,
	name:             string,
	music_path:       string `json:"music_path,omitempty"`,
	size:             Room_File_Size,
	tileset:          Room_File_Tileset,
	camera_bounds:    Room_File_Bounds,
	collision_bounds: Room_File_Bounds,
	layers:           Room_File_Layers,
}

Room_File :: struct {
	using _:  Room_File_Common,
	scenery:  []Room_File_Scenery `json:"scenery,omitempty"`,
	entities: []Room_File_Entity `json:"entities,omitempty"`,
}

Room_File_Wire :: struct {
	using _:  Room_File_Common,
	scenery:  []Room_File_Scenery `json:"scenery,omitempty"`,
	entities: []Room_File_Entity_Wire `json:"entities,omitempty"`,
}

Room_File_Decode_Error_Kind :: enum {
	none,
	invalid_json5,
	unknown_entity_type,
	unknown_entity_property,
	unknown_content_variant,
	invalid_entity_properties,
}

Room_File_Decode_Error :: struct {
	kind:         Room_File_Decode_Error_Kind,
	entity_index: int,
	message:      string,
}

Room_File_Encode_Error_Kind :: enum {
	none,
	invalid_entity_properties,
	json_encoding_failed,
}

Room_File_Encode_Error :: struct {
	kind:         Room_File_Encode_Error_Kind,
	entity_index: int,
}

room_file_json5_options :: proc() -> json.Marshal_Options {
	return {
		spec = .JSON5,
		pretty = true,
		use_spaces = true,
		spaces = 2,
		sort_maps_by_key = true,
		use_enum_names = true,
	}
}

decode_room_file_json5 :: proc(
	content: string,
	allocator := context.allocator,
) -> (
	room: Room_File,
	err: Room_File_Decode_Error,
) {
	context.allocator = allocator
	wire: Room_File_Wire
	json_error := json.unmarshal_string(content, &wire, .JSON5, allocator)
	if json_error != nil {
		destroy_room_file_wire(&wire, allocator)
		return {}, {kind = .invalid_json5, entity_index = -1, message = fmt.aprintf("invalid JSON5: %v", json_error)}
	}
	defer destroy_room_file_wire(&wire, allocator)

	room.id = wire.id
	wire.id = ""
	room.name = wire.name
	wire.name = ""
	room.music_path = wire.music_path
	wire.music_path = ""
	room.size = wire.size
	room.tileset = wire.tileset
	wire.tileset.path = ""
	room.camera_bounds = wire.camera_bounds
	room.collision_bounds = wire.collision_bounds
	room.layers = wire.layers
	wire.layers = {}
	room.scenery = wire.scenery
	wire.scenery = nil

	room.entities = make([]Room_File_Entity, len(wire.entities), allocator)
	for wire_entity, entity_index in wire.entities {
		room.entities[entity_index], err = decode_room_file_entity(
			wire_entity,
			entity_index,
			allocator,
		)
		if err.kind != .none {
			destroy_room_file(&room, allocator)
			return
		}
	}
	return
}

encode_room_file_json5 :: proc(
	room: Room_File,
	allocator := context.allocator,
) -> (
	data: []byte,
	err: Room_File_Encode_Error,
) {
	wire: Room_File_Wire
	wire.id = room.id
	wire.name = room.name
	wire.music_path = room.music_path
	wire.size = room.size
	wire.tileset = room.tileset
	wire.camera_bounds = room.camera_bounds
	wire.collision_bounds = room.collision_bounds
	wire.layers = room.layers
	wire.scenery = room.scenery
	wire.entities = make([]Room_File_Entity_Wire, len(room.entities), allocator)
	defer destroy_encoded_room_file_wire(&wire, allocator)

	for entity, entity_index in room.entities {
		wire.entities[entity_index], err = encode_room_file_entity(entity, entity_index, allocator)
		if err.kind != .none do return
	}

	marshal_error: json.Marshal_Error
	data, marshal_error = json.marshal(wire, room_file_json5_options(), allocator)
	if marshal_error != nil {
		err = {
			kind         = .json_encoding_failed,
			entity_index = -1,
		}
	}
	return
}

destroy_room_file :: proc(room: ^Room_File, allocator := context.allocator) {
	if room == nil do return

	delete(room.id, allocator)
	delete(room.name, allocator)
	delete(room.music_path, allocator)
	delete(room.tileset.path, allocator)
	delete(room.layers.base, allocator)
	delete(room.layers.decoration, allocator)
	delete(room.layers.collision, allocator)
	for &scenery in room.scenery {
		delete(scenery.id, allocator)
		delete(scenery.texture_path, allocator)
	}
	delete(room.scenery, allocator)
	for &entity in room.entities {
		destroy_room_file_entity(&entity, allocator)
	}
	delete(room.entities, allocator)
	room^ = {}
}

destroy_room_file_wire :: proc(wire: ^Room_File_Wire, allocator := context.allocator) {
	if wire == nil do return

	delete(wire.id, allocator)
	delete(wire.name, allocator)
	delete(wire.music_path, allocator)
	delete(wire.tileset.path, allocator)
	delete(wire.layers.base, allocator)
	delete(wire.layers.decoration, allocator)
	delete(wire.layers.collision, allocator)
	for &scenery in wire.scenery {
		delete(scenery.id, allocator)
		delete(scenery.texture_path, allocator)
	}
	delete(wire.scenery, allocator)
	for &entity in wire.entities {
		delete(entity.id, allocator)
		delete(entity.type, allocator)
		json.destroy_value(entity.properties, allocator)
	}
	delete(wire.entities, allocator)
	wire^ = {}
}

destroy_room_file_decode_error :: proc(
	err: ^Room_File_Decode_Error,
	allocator := context.allocator,
) {
	if err == nil do return
	delete(err.message, allocator)
	err^ = {}
}

destroy_encoded_room_file_wire :: proc(wire: ^Room_File_Wire, allocator := context.allocator) {
	if wire == nil do return

	for &entity in wire.entities {
		json.destroy_value(entity.properties, allocator)
	}
	delete(wire.entities, allocator)
	wire^ = {}
}
