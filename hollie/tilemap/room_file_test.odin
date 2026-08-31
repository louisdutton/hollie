package tilemap

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
		columns: 32,
	},
	camera_bounds: {x: -64, y: 0, width: 448, height: 256},
	collision_bounds: {x: 0, y: 0, width: 32, height: 16},
	layers: {
		base: [1, 2],
		decoration: [0, 257],
	},
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
			columns = 32,
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
	if len(room.layers.base) == 2 {
		testing.expect_value(t, room.layers.base[0], u16(1))
		testing.expect_value(t, room.layers.base[1], u16(2))
	}
	if len(room.layers.decoration) == 2 {
		testing.expect_value(t, room.layers.decoration[0], u16(0))
		testing.expect_value(t, room.layers.decoration[1], u16(257))
	}
}

@(test)
test_room_file_metadata_and_layers_follow_json5_contract :: proc(t: ^testing.T) {
	room, decode_error := decode_room_file_json5(ROOM_FILE_CONTRACT_TEST_JSON5)
	testing.expect(t, decode_error == nil, "the room file contract should decode")
	if decode_error != nil do return
	defer destroy_room_file(&room)

	expect_room_file_contract(t, room)

	encoded, encode_error := encode_room_file_json5(room)
	testing.expect(t, encode_error == nil, "the room file contract should encode")
	if encode_error != nil do return
	defer delete(encoded)

	roundtripped, roundtrip_error := decode_room_file_json5(string(encoded))
	testing.expect(t, roundtrip_error == nil, "encoded room data should decode again")
	if roundtrip_error != nil do return
	defer destroy_room_file(&roundtripped)

	expect_room_file_contract(t, roundtripped)
}
