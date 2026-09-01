package tilemap

import "../content"
import json "core:encoding/json"
import "core:fmt"
import "core:strings"

Room_File_Position :: struct {
	x: int,
	y: int,
}

Room_File_Player :: struct {
	player_index: int,
}

Room_File_Enemy :: struct {
	kind: content.Character_Kind,
}

Room_File_Enemy_Wire :: struct {
	kind: string,
}

Room_File_NPC :: struct {}

Room_File_Holdable :: struct {}

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
	type:       string,
	position:   Room_File_Position,
	properties: json.Value `json:"properties,omitempty"`,
}

room_file_entity_type_is_known :: proc(entity_type: string) -> bool {
	switch entity_type {
	case "player", "enemy", "npc", "holdable", "door", "pressure_plate", "gate": return true
	case: return false
	}
}

room_file_entity_property_is_allowed :: proc(entity_type, property: string) -> bool {
	switch entity_type {
	case "player": return property == "player_index"
	case "enemy": return property == "kind"
	case "npc", "holdable": return false
	case "door":
		return property == "size" || property == "target_room_id" || property == "target_door_id"
	case "pressure_plate": return property == "trigger_id" || property == "requires_both"
	case "gate":
		return(
				property == "gate_id" ||
				property == "size" ||
				property == "required_trigger_ids" ||
				property == "inverted" \
			)
	case: return false
	}
}

room_file_entity_properties_error :: proc(
	wire: Room_File_Entity_Wire,
	allocator := context.allocator,
) -> string {
	context.allocator = allocator
	properties, ok := wire.properties.(json.Object)
	if !ok do return ""

	for property in properties {
		if !room_file_entity_property_is_allowed(wire.type, property) {
			return fmt.aprintf("unknown property %q for entity type %q", property, wire.type)
		}
	}

	if wire.type == "door" || wire.type == "gate" {
		if size_value, found := properties["size"]; found {
			if size, size_ok := size_value.(json.Object); size_ok {
				for property in size {
					if property != "width" && property != "height" {
						return fmt.aprintf(
							"unknown size property %q for entity type %q",
							property,
							wire.type,
						)
					}
				}
			}
		}
	}

	return ""
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
	context.allocator = allocator
	entity.id = strings.clone(wire.id, allocator)
	entity.position = wire.position
	if !room_file_entity_type_is_known(wire.type) {
		err = {
			kind         = .unknown_entity_type,
			entity_index = entity_index,
			message      = fmt.aprintf("unknown entity type %q", wire.type),
		}
		destroy_room_file_entity(&entity, allocator)
		return
	}

	properties_are_empty := wire.type == "npc" || wire.type == "holdable"
	if _, ok := wire.properties.(json.Object);
	   !ok && !(properties_are_empty && wire.properties == nil) {
		err = {
			kind         = .invalid_entity_properties,
			entity_index = entity_index,
			message      = strings.clone("entity properties must be an object", allocator),
		}
		destroy_room_file_entity(&entity, allocator)
		return
	}

	if properties_error := room_file_entity_properties_error(wire, allocator);
	   properties_error != "" {
		err = {
			kind         = .unknown_entity_property,
			entity_index = entity_index,
			message      = properties_error,
		}
		destroy_room_file_entity(&entity, allocator)
		return
	}

	switch wire.type {
	case "player":
		properties: Room_File_Player
		ok := decode_room_file_entity_properties(wire.properties, &properties, allocator)
		entity.properties = properties
		if !ok {
			err = {
				kind         = .invalid_entity_properties,
				entity_index = entity_index,
				message      = strings.clone("player properties have invalid types", allocator),
			}
		}
	case "enemy":
		properties_wire: Room_File_Enemy_Wire
		ok := decode_room_file_entity_properties(wire.properties, &properties_wire, allocator)
		if !ok {
			err = {
				kind         = .invalid_entity_properties,
				entity_index = entity_index,
				message      = strings.clone("enemy properties have invalid types", allocator),
			}
			break
		}
		defer delete(properties_wire.kind, allocator)

		kind, known := content.character_kind_from_wire(properties_wire.kind)
		if !known {
			err = {
				kind         = .unknown_content_variant,
				entity_index = entity_index,
				message      = fmt.aprintf("unknown enemy kind %q", properties_wire.kind),
			}
			break
		}
		entity.properties = Room_File_Enemy {
			kind = kind,
		}
	case "npc":
		properties: Room_File_NPC
		entity.properties = properties
	case "holdable":
		properties: Room_File_Holdable
		entity.properties = properties
	case "door":
		properties: Room_File_Door
		ok := decode_room_file_entity_properties(wire.properties, &properties, allocator)
		entity.properties = properties
		if !ok {
			err = {
				kind         = .invalid_entity_properties,
				entity_index = entity_index,
				message      = strings.clone("door properties have invalid types", allocator),
			}
		}
	case "pressure_plate":
		properties: Room_File_Pressure_Plate
		ok := decode_room_file_entity_properties(wire.properties, &properties, allocator)
		entity.properties = properties
		if !ok {
			err = {
				kind         = .invalid_entity_properties,
				entity_index = entity_index,
				message      = strings.clone(
					"pressure plate properties have invalid types",
					allocator,
				),
			}
		}
	case "gate":
		properties: Room_File_Gate
		ok := decode_room_file_entity_properties(wire.properties, &properties, allocator)
		entity.properties = properties
		if !ok {
			err = {
				kind         = .invalid_entity_properties,
				entity_index = entity_index,
				message      = strings.clone("gate properties have invalid types", allocator),
			}
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
		wire.type = "player"
		wire.properties, properties_ok = encode_room_file_entity_properties(properties, allocator)
	case Room_File_Enemy:
		wire.type = "enemy"
		kind, known := content.character_kind_to_wire(properties.kind)
		if known {
			wire.properties, properties_ok = encode_room_file_entity_properties(
				Room_File_Enemy_Wire{kind = kind},
				allocator,
			)
		}
	case Room_File_NPC:
		wire.type = "npc"
		properties_ok = true
	case Room_File_Holdable:
		wire.type = "holdable"
		properties_ok = true
	case Room_File_Door:
		wire.type = "door"
		wire.properties, properties_ok = encode_room_file_entity_properties(properties, allocator)
	case Room_File_Pressure_Plate:
		wire.type = "pressure_plate"
		wire.properties, properties_ok = encode_room_file_entity_properties(properties, allocator)
	case Room_File_Gate:
		wire.type = "gate"
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
	case Room_File_Player,
	     Room_File_Enemy,
	     Room_File_NPC,
	     Room_File_Holdable,
	     Room_File_Pressure_Plate:
	case Room_File_Door:
		delete(properties.target_room_id, allocator)
		delete(properties.target_door_id, allocator)
	case Room_File_Gate: delete(properties.required_trigger_ids, allocator)
	}
	entity^ = {}
}
