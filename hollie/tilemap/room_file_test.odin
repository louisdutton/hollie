package tilemap

import "../content"
import "core:strings"
import "core:testing"

ROOM_FILE_CONTRACT_TEST_JSON5 :: `{
	// Room identity and presentation.
	id: 'olivewood',
	name: 'Olivewood',
	music_path: 'audio/music/ambient.ogg',

	size: {width: 2, height: 1},
	tileset: {
		path: 'art/tileset/spr_tileset_sunnysideworld_16px.png',
		tile_size: 16,
		source_tile_size: 64,
		columns: 32,
		smooth: true,
	},
	camera_bounds: {x: -64, y: 0, width: 448, height: 256},
	collision_bounds: {x: 0, y: 0, width: 32, height: 16},
	layers: {
		base: [1, 2],
		decoration: [0, 257],
		collision: [0, 1],
	},
	scenery: [{
		id: 'cottage',
		texture_path: 'art/scenery/cottage.png',
		position: {x: 0, y: 0},
		size: {width: 32, height: 16},
		smooth: true,
	}],
	entities: [
		{
			id: 'player_one_spawn',
			type: 'player',
			position: {x: 0, y: 0},
			properties: {player_index: 1},
		},
		{
			id: 'goblin_one',
			type: 'enemy',
			position: {x: 16, y: 0},
			properties: {kind: 'Goblin'},
		},
		{
			id: 'villager',
			type: 'npc',
			position: {x: 0, y: 0},
		},
		{
			id: 'wood',
			type: 'holdable',
			position: {x: 16, y: 0},
		},
		{
			id: 'to_other_room',
			type: 'door',
			position: {x: 0, y: 0},
			properties: {
				size: {width: 32, height: 64},
				target_room_id: 'other_room',
				target_door_id: 'from_test_room',
			},
		},
		{
			id: 'plate_one',
			type: 'pressure_plate',
			position: {x: 16, y: 0},
			properties: {trigger_id: 1, requires_both: true},
		},
		{
			id: 'gate_one',
			type: 'gate',
			position: {x: 0, y: 0},
			properties: {
				gate_id: 1,
				size: {width: 64, height: 16},
				required_trigger_ids: [1],
				inverted: true,
			},
		},
	],
}`

expect_room_file_contract :: proc(t: ^testing.T, room: Room_File) {
	testing.expect_value(t, room.id, "olivewood")
	testing.expect_value(t, room.name, "Olivewood")
	testing.expect_value(t, room.music_path, "audio/music/ambient.ogg")
	testing.expect_value(t, room.size, Room_File_Size{width = 2, height = 1})
	testing.expect_value(
		t,
		room.tileset,
		Room_File_Tileset {
			path = "art/tileset/spr_tileset_sunnysideworld_16px.png",
			tile_size = 16,
			source_tile_size = 64,
			columns = 32,
			smooth = true,
		},
	)
	testing.expect_value(
		t,
		room.camera_bounds,
		Room_File_Bounds{x = -64, y = 0, width = 448, height = 256},
	)
	testing.expect_value(
		t,
		room.collision_bounds,
		Room_File_Bounds{x = 0, y = 0, width = 32, height = 16},
	)
	testing.expect_value(t, len(room.layers.base), 2)
	testing.expect_value(t, len(room.layers.decoration), 2)
	testing.expect_value(t, len(room.layers.collision), 2)
	if len(room.layers.base) == 2 {
		testing.expect_value(t, room.layers.base[0], u16(1))
		testing.expect_value(t, room.layers.base[1], u16(2))
	}
	if len(room.layers.decoration) == 2 {
		testing.expect_value(t, room.layers.decoration[0], u16(0))
		testing.expect_value(t, room.layers.decoration[1], u16(257))
	}
	if len(room.layers.collision) == 2 {
		testing.expect_value(t, room.layers.collision[0], u8(0))
		testing.expect_value(t, room.layers.collision[1], u8(1))
	}
	testing.expect_value(t, len(room.scenery), 1)
	if len(room.scenery) == 1 {
		testing.expect_value(t, room.scenery[0].id, "cottage")
		testing.expect_value(t, room.scenery[0].texture_path, "art/scenery/cottage.png")
		testing.expect_value(t, room.scenery[0].position, Room_File_Position{x = 0, y = 0})
		testing.expect_value(t, room.scenery[0].size, Room_File_Size{width = 32, height = 16})
		testing.expect_value(t, room.scenery[0].smooth, true)
	}

	testing.expect_value(t, len(room.entities), 7)
	if len(room.entities) != 7 do return

	player, player_ok := room.entities[0].properties.(Room_File_Player)
	testing.expect(t, player_ok, "player properties should be typed")
	if player_ok do testing.expect_value(t, player.player_index, 1)

	enemy, enemy_ok := room.entities[1].properties.(Room_File_Enemy)
	testing.expect(t, enemy_ok, "enemy properties should be typed")
	if enemy_ok do testing.expect_value(t, enemy.kind, content.Character_Kind.Goblin)

	_, npc_ok := room.entities[2].properties.(Room_File_NPC)
	testing.expect(t, npc_ok, "NPC properties should be typed")

	_, holdable_ok := room.entities[3].properties.(Room_File_Holdable)
	testing.expect(t, holdable_ok, "holdable properties should be typed")

	door, door_ok := room.entities[4].properties.(Room_File_Door)
	testing.expect(t, door_ok, "door properties should be typed")
	if door_ok {
		testing.expect_value(t, door.size, Room_File_Size{width = 32, height = 64})
		testing.expect_value(t, door.target_room_id, "other_room")
		testing.expect_value(t, door.target_door_id, "from_test_room")
	}

	plate, plate_ok := room.entities[5].properties.(Room_File_Pressure_Plate)
	testing.expect(t, plate_ok, "pressure plate properties should be typed")
	if plate_ok {
		testing.expect_value(t, plate.trigger_id, 1)
		testing.expect_value(t, plate.requires_both, true)
	}

	gate, gate_ok := room.entities[6].properties.(Room_File_Gate)
	testing.expect(t, gate_ok, "gate properties should be typed")
	if gate_ok {
		testing.expect_value(t, gate.gate_id, 1)
		testing.expect_value(t, gate.size, Room_File_Size{width = 64, height = 16})
		testing.expect_value(t, len(gate.required_trigger_ids), 1)
		if len(gate.required_trigger_ids) == 1 {
			testing.expect_value(t, gate.required_trigger_ids[0], 1)
		}
		testing.expect_value(t, gate.inverted, true)
	}
}

@(test)
test_room_file_json5_contract :: proc(t: ^testing.T) {
	room, decode_error := decode_room_file_json5(ROOM_FILE_CONTRACT_TEST_JSON5)
	testing.expect(t, decode_error.kind == .none, "the room file contract should decode")
	if decode_error.kind != .none do return
	defer destroy_room_file(&room)

	expect_room_file_contract(t, room)
	validation_errors := validate_room_file(&room)
	defer destroy_validation_errors(&validation_errors)
	testing.expect_value(t, len(validation_errors), 0)

	encoded, encode_error := encode_room_file_json5(room)
	testing.expect(t, encode_error.kind == .none, "the room file contract should encode")
	if encode_error.kind != .none do return
	defer delete(encoded)
	testing.expect(
		t,
		strings.contains(string(encoded), `"type": "pressure_plate"`),
		"entity discriminators should be written as stable names",
	)

	roundtripped, roundtrip_error := decode_room_file_json5(string(encoded))
	testing.expect(t, roundtrip_error.kind == .none, "encoded room data should decode again")
	if roundtrip_error.kind != .none do return
	defer destroy_room_file(&roundtripped)

	expect_room_file_contract(t, roundtripped)

	_, unknown_error := decode_room_file_json5(
		`{
		entities: [{
			id: 'mystery',
			type: 'teleporter',
			position: {x: 0, y: 0},
			properties: {},
		}],
	}`,
	)
	defer destroy_room_file_decode_error(&unknown_error)
	testing.expect_value(t, unknown_error.kind, Room_File_Decode_Error_Kind.unknown_entity_type)
	testing.expect_value(t, unknown_error.entity_index, 0)
	testing.expect_value(t, unknown_error.message, `unknown entity type "teleporter"`)

	_, properties_error := decode_room_file_json5(
		`{
		entities: [{
			id: 'broken_player',
			type: 'player',
			position: {x: 0, y: 0},
			properties: {player_index: 'one'},
		}],
	}`,
	)
	defer destroy_room_file_decode_error(&properties_error)
	testing.expect_value(
		t,
		properties_error.kind,
		Room_File_Decode_Error_Kind.invalid_entity_properties,
	)
	testing.expect_value(t, properties_error.entity_index, 0)

	_, unknown_property_error := decode_room_file_json5(
		`{
		entities: [{
			id: 'broken_player',
			type: 'player',
			position: {x: 0, y: 0},
			properties: {player_index: 1, god_mode: true},
		}],
	}`,
	)
	defer destroy_room_file_decode_error(&unknown_property_error)
	testing.expect_value(
		t,
		unknown_property_error.kind,
		Room_File_Decode_Error_Kind.unknown_entity_property,
	)
	testing.expect_value(
		t,
		unknown_property_error.message,
		`unknown property "god_mode" for entity type "player"`,
	)

	_, unknown_kind_error := decode_room_file_json5(
		`{
		entities: [{
			id: 'orc',
			type: 'enemy',
			position: {x: 0, y: 0},
			properties: {kind: 'Orc'},
		}],
	}`,
	)
	defer destroy_room_file_decode_error(&unknown_kind_error)
	testing.expect_value(
		t,
		unknown_kind_error.kind,
		Room_File_Decode_Error_Kind.unknown_content_variant,
	)
	testing.expect_value(t, unknown_kind_error.entity_index, 0)
	testing.expect_value(t, unknown_kind_error.message, `unknown enemy kind "Orc"`)
}

@(test)
test_room_file_runtime_conversion_is_lossless :: proc(t: ^testing.T) {
	room, decode_error := decode_room_file_json5(ROOM_FILE_CONTRACT_TEST_JSON5)
	testing.expect(t, decode_error.kind == .none, "the room file contract should decode")
	if decode_error.kind != .none do return
	defer destroy_room_file(&room)

	tm, validation_errors := room_file_to_tilemap(room)
	defer destroy_validation_errors(&validation_errors)
	testing.expect_value(t, len(validation_errors), 0)
	if len(validation_errors) != 0 do return
	defer destroy_tilemap(&tm)
	testing.expect_value(t, tm.tileset.id, u32(0))
	testing.expect_value(t, tm.config.world_tile_size, 16)
	testing.expect_value(t, tm.config.source_tile_size, 64)
	testing.expect_value(t, tm.config.smooth, true)
	testing.expect_value(t, len(tm.scenery), 1)
	if len(tm.scenery) == 1 {
		testing.expect_value(t, tm.scenery[0].size, Vec2{32, 16})
		testing.expect_value(t, tm.scenery[0].smooth, true)
	}
	testing.expect_value(t, len(tm.entities), 7)
	if len(tm.entities) == 7 {
		testing.expect_value(t, tm.entities[0].instance_id, "player_one_spawn")
		testing.expect_value(t, tm.entities[0].player_index, 1)
		testing.expect_value(t, tm.entities[1].character_kind, content.Character_Kind.Goblin)
		testing.expect_value(t, tm.entities[6].instance_id, "gate_one")
	}

	converted, conversion_error := tilemap_to_room_file(tm)
	testing.expect_value(t, conversion_error.kind, Room_File_Conversion_Error_Kind.none)
	if conversion_error.kind != .none do return
	defer destroy_room_file(&converted)

	original_json, original_encode_error := encode_room_file_json5(room)
	testing.expect_value(t, original_encode_error.kind, Room_File_Encode_Error_Kind.none)
	if original_encode_error.kind != .none do return
	defer delete(original_json)

	converted_json, converted_encode_error := encode_room_file_json5(converted)
	testing.expect_value(t, converted_encode_error.kind, Room_File_Encode_Error_Kind.none)
	if converted_encode_error.kind != .none do return
	defer delete(converted_json)

	testing.expect_value(t, string(converted_json), string(original_json))
}
