package tilemap

import "core:testing"

TEST_MAP :: #load("./test.map", string)
OLIVEWOOD_MAP :: #load("../../res/maps/olivewood.map", string)
DESERT_MAP :: #load("../../res/maps/desert.map", string)
SMALL_ROOM_MAP :: #load("../../res/maps/room.map", string)

expect_entity_equal :: proc(t: ^testing.T, expected, actual: EntityData) {
	testing.expect_value(t, actual.instance_id, expected.instance_id)
	testing.expect_value(t, actual.x, expected.x)
	testing.expect_value(t, actual.y, expected.y)
	testing.expect_value(t, actual.entity_type, expected.entity_type)
	testing.expect_value(t, actual.player_index, expected.player_index)
	testing.expect_value(t, actual.archetype_id, expected.archetype_id)
	testing.expect_value(t, actual.trigger_id, expected.trigger_id)
	testing.expect_value(t, actual.gate_id, expected.gate_id)
	testing.expect_value(t, actual.requires_both, expected.requires_both)
	testing.expect_value(t, actual.inverted, expected.inverted)
	testing.expect_value(t, actual.width, expected.width)
	testing.expect_value(t, actual.height, expected.height)
	testing.expect_value(t, actual.texture_path, expected.texture_path)
	testing.expect_value(t, actual.target_room, expected.target_room)
	testing.expect_value(t, actual.target_door, expected.target_door)
	testing.expect_value(t, len(actual.required_triggers), len(expected.required_triggers))

	for trigger, i in expected.required_triggers {
		if i >= len(actual.required_triggers) do break
		testing.expect_value(t, actual.required_triggers[i], trigger)
	}
}

expect_tilemap_equal :: proc(t: ^testing.T, expected, actual: TileMap) {
	testing.expect_value(t, actual.width, expected.width)
	testing.expect_value(t, actual.height, expected.height)
	testing.expect_value(t, actual.tileset_path, expected.tileset_path)
	testing.expect_value(t, actual.tile_size, expected.tile_size)
	testing.expect_value(t, actual.config.tile_size, expected.config.tile_size)
	testing.expect_value(t, actual.config.tileset_cols, expected.config.tileset_cols)
	testing.expect_value(t, actual.room_id, expected.room_id)
	testing.expect_value(t, actual.room_name, expected.room_name)
	testing.expect_value(t, actual.music_path, expected.music_path)
	testing.expect_value(t, actual.camera_bounds, expected.camera_bounds)
	testing.expect_value(t, actual.collision_bounds, expected.collision_bounds)
	testing.expect_value(t, len(actual.base_tiles), len(expected.base_tiles))
	testing.expect_value(t, len(actual.deco_tiles), len(expected.deco_tiles))
	testing.expect_value(t, len(actual.entities), len(expected.entities))

	for tile, i in expected.base_tiles {
		if i >= len(actual.base_tiles) do break
		testing.expect_value(t, actual.base_tiles[i], tile)
	}

	for tile, i in expected.deco_tiles {
		if i >= len(actual.deco_tiles) do break
		testing.expect_value(t, actual.deco_tiles[i], tile)
	}

	for entity, i in expected.entities {
		if i >= len(actual.entities) do break
		expect_entity_equal(t, entity, actual.entities[i])
	}
}

expect_map_roundtrip :: proc(t: ^testing.T, content, expected_room_id: string) {
	parsed, ok := deserialise_tilemap(content)
	testing.expect(t, ok, "shipped map should parse")
	if !ok do return

	testing.expect_value(t, parsed.room_id, expected_room_id)
	testing.expect(t, parsed.width > 0, "map width should be positive")
	testing.expect(t, parsed.height > 0, "map height should be positive")
	testing.expect_value(t, len(parsed.base_tiles), parsed.width * parsed.height)
	testing.expect_value(t, len(parsed.deco_tiles), parsed.width * parsed.height)

	serialized := serialise_tilemap(&parsed)
	roundtripped, roundtrip_ok := deserialise_tilemap(serialized)
	testing.expect(t, roundtrip_ok, "serialized map should parse")
	if !roundtrip_ok do return

	expect_tilemap_equal(t, parsed, roundtripped)
	testing.expect_value(t, serialise_tilemap(&roundtripped), serialized)
}

@(test)
test_fixture_roundtrip :: proc(t: ^testing.T) {
	context.allocator = context.temp_allocator
	expect_map_roundtrip(t, TEST_MAP, "small_room")
}

@(test)
test_all_entity_fields_roundtrip :: proc(t: ^testing.T) {
	context.allocator = context.temp_allocator

	gate_triggers := make([dynamic]int)
	append(&gate_triggers, 7, 8)

	entities := []EntityData {
		{x = 0, y = 0, entity_type = .PLAYER, width = 16, height = 16},
		{x = 16, y = 0, entity_type = .ENEMY, width = 16, height = 16},
		{
			x = 32,
			y = 0,
			entity_type = .PRESSURE_PLATE,
			trigger_id = 7,
			requires_both = true,
			width = 32,
			height = 32,
		},
		{
			x = 48,
			y = 0,
			entity_type = .GATE,
			gate_id = 3,
			inverted = true,
			width = 64,
			height = 16,
			required_triggers = gate_triggers,
		},
		{
			x = 64,
			y = 0,
			entity_type = .HOLDABLE,
			width = 16,
			height = 16,
			texture_path = "art/elements/crops/wood.png",
		},
		{x = 80, y = 0, entity_type = .NPC, width = 16, height = 16, texture_path = "human"},
		{
			x = 96,
			y = 0,
			entity_type = .DOOR,
			width = 32,
			height = 64,
			target_room = "olivewood",
			target_door = "from_small_room",
		},
	}

	tm := TileMap {
		width = 7,
		height = 1,
		base_tiles = []TileType{.GRASS_1, .GRASS_2, .GRASS_3, .SAND_1, .SAND_2, .SAND_3, .GRASS_1},
		deco_tiles = []TileType{.EMPTY, .GRASS_DEC_1, .EMPTY, .EMPTY, .EMPTY, .EMPTY, .EMPTY},
		entities = entities,
		tile_size = 16,
		tileset_path = "art/tileset/spr_tileset_sunnysideworld_16px.png",
		config = {tile_size = 16, tileset_cols = 32},
		room_id = "roundtrip",
		room_name = "Round Trip",
		music_path = "audio/music/ambient.ogg",
		camera_bounds = {-16, -16, 144, 48},
		collision_bounds = {0, 0, 112, 16},
	}

	serialized := serialise_tilemap(&tm)
	parsed, ok := deserialise_tilemap(serialized)
	testing.expect(t, ok, "representative map should round-trip")
	if !ok do return

	expect_tilemap_equal(t, tm, parsed)
	testing.expect_value(t, serialise_tilemap(&parsed), serialized)
}

@(test)
test_all_shipped_maps_roundtrip :: proc(t: ^testing.T) {
	context.allocator = context.temp_allocator

	expect_map_roundtrip(t, OLIVEWOOD_MAP, "olivewood")
	expect_map_roundtrip(t, DESERT_MAP, "desert")
	expect_map_roundtrip(t, SMALL_ROOM_MAP, "small_room")
}

@(test)
test_malformed_input_is_rejected :: proc(t: ^testing.T) {
	context.allocator = context.temp_allocator

	_, malformed_rect_ok := deserialise_tilemap("[config]\ncamera_bounds=1,2,3\n")
	testing.expect(t, !malformed_rect_ok, "truncated rectangles should be rejected")

	_, invalid_tile_ok := deserialise_tilemap("[base_data]\n1,nope,3\n")
	testing.expect(t, !invalid_tile_ok, "invalid tile IDs should be rejected")

	_, invalid_entity_ok := deserialise_tilemap("[entity_data]\n0,0,999\n")
	testing.expect(t, !invalid_entity_ok, "unknown entity types should be rejected")

	_, truncated_entity_ok := deserialise_tilemap("[entity_data]\n0,0\n")
	testing.expect(t, !truncated_entity_ok, "truncated entities should be rejected")

	_, invalid_property_ok := deserialise_tilemap("[entity_data]\n0,0,2,nope,0,maybe\n")
	testing.expect(t, !invalid_property_ok, "invalid entity properties should be rejected")
}

@(test)
test_comments_empty_sections_and_entity_defaults :: proc(t: ^testing.T) {
	context.allocator = context.temp_allocator

	content := `
# Comments and empty sections are valid.
[config]
width=1
height=1
tile_size=16
tileset_cols=32
camera_bounds=0,0,16,16
collision_bounds=0,0,16,16

[base_data]
1

[deco_data]
0

[entity_data]
# Entity records may use their default optional properties.
0,0,1
`

	tm, ok := deserialise_tilemap(content)
	testing.expect(t, ok, "comments, empty lines, and omitted optional fields should parse")
	if !ok do return

	testing.expect_value(t, len(tm.entities), 1)
	testing.expect_value(t, tm.entities[0].width, TILE_SIZE)
	testing.expect_value(t, tm.entities[0].height, TILE_SIZE)
	testing.expect_value(t, len(tm.entities[0].required_triggers), 0)

	empty, empty_ok := deserialise_tilemap("[entity_data]\n")
	testing.expect(t, empty_ok, "empty sections should be accepted by the parser")
	testing.expect_value(t, len(empty.entities), 0)
}
