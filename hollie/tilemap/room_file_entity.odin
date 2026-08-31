package tilemap

import json "core:encoding/json"
import "core:strings"

Room_File_Entity_Type :: enum {
	// Unknown enum names remain at the zero value during Odin JSON decoding.
	invalid,
	player,
	enemy,
	npc,
	holdable,
	door,
	pressure_plate,
	gate,
}

Room_File_Position :: struct {
	x: int,
	y: int,
}

Room_File_Player :: struct {
	player_index: int,
}

Room_File_Enemy :: struct {
	archetype_id: string,
}

Room_File_NPC :: struct {
	archetype_id: string,
}

Room_File_Holdable :: struct {
	archetype_id: string,
}

Room_File_Door :: struct {
	size:           Room_File_Size,
	target_room_id: string,
	target_door_id: string,
}

Room_File_Pressure_Plate :: struct {
	trigger_id:    int,
	requires_both: bool `json:"requires_both,omitempty"`,
}

Room_File_Gate :: struct {
	gate_id:              int,
	size:                 Room_File_Size,
	required_trigger_ids: []int,
	inverted:             bool `json:"inverted,omitempty"`,
}

Room_File_Entity_Properties :: union #no_nil {
	Room_File_Player,
	Room_File_Enemy,
	Room_File_NPC,
	Room_File_Holdable,
	Room_File_Door,
	Room_File_Pressure_Plate,
	Room_File_Gate,
}

Room_File_Entity :: struct {
	id:         string,
	position:   Room_File_Position,
	properties: Room_File_Entity_Properties,
}

Room_File_Entity_Wire :: struct {
	id:         string,
	type:       Room_File_Entity_Type,
	position:   Room_File_Position,
	properties: json.Value,
}

decode_room_file_entity_properties :: proc(
	value: json.Value,
	properties: ^$T,
	allocator := context.allocator,
) -> bool {
	data, unparse_error := json.unparse(value, allocator = allocator)
	if unparse_error != nil do return false
	defer delete(data, allocator)

	json_error := json.unmarshal_string(data, properties, .JSON5, allocator)
	return json_error == nil
}

decode_room_file_entity :: proc(
	wire: Room_File_Entity_Wire,
	entity_index: int,
	allocator := context.allocator,
) -> (
	entity: Room_File_Entity,
	err: Room_File_Decode_Error,
) {
	entity.id = strings.clone(wire.id, allocator)
	entity.position = wire.position

	switch wire.type {
	case .player:
		properties: Room_File_Player
		ok := decode_room_file_entity_properties(wire.properties, &properties, allocator)
		entity.properties = properties
		if !ok {
			err = {
				kind         = .invalid_entity_properties,
				entity_index = entity_index,
			}
		}
	case .enemy:
		properties: Room_File_Enemy
		ok := decode_room_file_entity_properties(wire.properties, &properties, allocator)
		entity.properties = properties
		if !ok {
			err = {
				kind         = .invalid_entity_properties,
				entity_index = entity_index,
			}
		}
	case .npc:
		properties: Room_File_NPC
		ok := decode_room_file_entity_properties(wire.properties, &properties, allocator)
		entity.properties = properties
		if !ok {
			err = {
				kind         = .invalid_entity_properties,
				entity_index = entity_index,
			}
		}
	case .holdable:
		properties: Room_File_Holdable
		ok := decode_room_file_entity_properties(wire.properties, &properties, allocator)
		entity.properties = properties
		if !ok {
			err = {
				kind         = .invalid_entity_properties,
				entity_index = entity_index,
			}
		}
	case .door:
		properties: Room_File_Door
		ok := decode_room_file_entity_properties(wire.properties, &properties, allocator)
		entity.properties = properties
		if !ok {
			err = {
				kind         = .invalid_entity_properties,
				entity_index = entity_index,
			}
		}
	case .pressure_plate:
		properties: Room_File_Pressure_Plate
		ok := decode_room_file_entity_properties(wire.properties, &properties, allocator)
		entity.properties = properties
		if !ok {
			err = {
				kind         = .invalid_entity_properties,
				entity_index = entity_index,
			}
		}
	case .gate:
		properties: Room_File_Gate
		ok := decode_room_file_entity_properties(wire.properties, &properties, allocator)
		entity.properties = properties
		if !ok {
			err = {
				kind         = .invalid_entity_properties,
				entity_index = entity_index,
			}
		}
	case .invalid: err = {
				kind         = .unknown_entity_type,
				entity_index = entity_index,
			}
	}

	if err.kind != .none {
		destroy_room_file_entity(&entity, allocator)
	}
	return
}

encode_room_file_entity_properties :: proc(
	properties: any,
	allocator := context.allocator,
) -> (
	value: json.Value,
	ok: bool,
) {
	data, marshal_error := json.marshal(properties, room_file_json5_options(), allocator)
	if marshal_error != nil do return {}, false
	defer delete(data, allocator)

	parse_error: json.Error
	value, parse_error = json.parse(data, .JSON5, true, allocator)
	if parse_error != .None {
		json.destroy_value(value, allocator)
		return {}, false
	}
	return value, true
}

encode_room_file_entity :: proc(
	entity: Room_File_Entity,
	entity_index: int,
	allocator := context.allocator,
) -> (
	wire: Room_File_Entity_Wire,
	err: Room_File_Encode_Error,
) {
	wire.id = entity.id
	wire.position = entity.position
	properties_ok: bool

	switch properties in entity.properties {
	case Room_File_Player:
		wire.type = .player
		wire.properties, properties_ok = encode_room_file_entity_properties(properties, allocator)
	case Room_File_Enemy:
		wire.type = .enemy
		wire.properties, properties_ok = encode_room_file_entity_properties(properties, allocator)
	case Room_File_NPC:
		wire.type = .npc
		wire.properties, properties_ok = encode_room_file_entity_properties(properties, allocator)
	case Room_File_Holdable:
		wire.type = .holdable
		wire.properties, properties_ok = encode_room_file_entity_properties(properties, allocator)
	case Room_File_Door:
		wire.type = .door
		wire.properties, properties_ok = encode_room_file_entity_properties(properties, allocator)
	case Room_File_Pressure_Plate:
		wire.type = .pressure_plate
		wire.properties, properties_ok = encode_room_file_entity_properties(properties, allocator)
	case Room_File_Gate:
		wire.type = .gate
		wire.properties, properties_ok = encode_room_file_entity_properties(properties, allocator)
	}

	if !properties_ok {
		err = {
			kind         = .invalid_entity_properties,
			entity_index = entity_index,
		}
	}
	return
}

destroy_room_file_entity :: proc(entity: ^Room_File_Entity, allocator := context.allocator) {
	if entity == nil do return

	delete(entity.id, allocator)
	switch &properties in entity.properties {
	case Room_File_Player, Room_File_Pressure_Plate:
	case Room_File_Enemy: delete(properties.archetype_id, allocator)
	case Room_File_NPC: delete(properties.archetype_id, allocator)
	case Room_File_Holdable: delete(properties.archetype_id, allocator)
	case Room_File_Door:
		delete(properties.target_room_id, allocator)
		delete(properties.target_door_id, allocator)
	case Room_File_Gate: delete(properties.required_trigger_ids, allocator)
	}
	entity^ = {}
}
