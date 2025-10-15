package tilemap

import "core:strings"
import "core:testing"

TEST_MAP :: #load("./test.map", string)

@(test)
test_serialize :: proc(t: ^testing.T) {
	context.allocator = context.temp_allocator

	base_tiles := make([]TileType, 8 * 8)
	for i in 0 ..< len(base_tiles) do base_tiles[i] = .GRASS_1

	deco_tiles := make([]TileType, 8 * 5)
	for i in 0 ..< len(deco_tiles) do deco_tiles[i] = .EMPTY

	entity1_triggers := make([dynamic]int)
	entity2_triggers := make([dynamic]int)
	entity3_triggers := make([dynamic]int)
	entity4_triggers := make([dynamic]int)

	entity_data := []EntityData {
		{
			x = 64,
			y = 64,
			entity_type = .PLAYER,
			width = 16,
			height = 16,
			required_triggers = entity1_triggers,
		},
		{
			x = 80,
			y = 64,
			entity_type = .PLAYER,
			width = 16,
			height = 16,
			required_triggers = entity2_triggers,
		},
		{
			x = 96,
			y = 96,
			entity_type = .NPC,
			width = 16,
			height = 16,
			required_triggers = entity3_triggers,
		},
		{
			x = 16,
			y = 64,
			entity_type = .DOOR,
			trigger_id = 0,
			gate_id = 0,
			requires_both = false,
			inverted = false,
			width = 32,
			height = 32,
			texture_path = "",
			target_room = "olivewood",
			target_door = "from_small_room",
			required_triggers = entity4_triggers,
		},
	}

	test_tilemap := TileMap {
		width = 8,
		height = 8,
		tileset_path = "art/tileset/spr_tileset_sunnysideworld_16px.png",
		base_tiles = base_tiles,
		deco_tiles = deco_tiles,
		entities = entity_data,
		config = TilemapConfig{tile_size = 16, tileset_cols = 32},
		tile_size = 16,
		room_id = "small_room",
		room_name = "???",
		music_path = "audio/music/ambient.ogg",
		camera_bounds = {x = -200, y = -150, width = 528, height = 428},
		collision_bounds = {x = 0, y = 0, width = 128, height = 128},
	}

	expected := TEST_MAP

	serialized := serialise_tilemap(&test_tilemap)
	testing.expect_value(t, serialized, expected)
}

@(test)
test_deserialize :: proc(t: ^testing.T) {
	context.allocator = context.temp_allocator
	input := TEST_MAP

	loaded_tilemap, ok := deserialise_tilemap(input)
	testing.expect(t, ok, "Parsing should succeed")

	testing.expect_value(t, loaded_tilemap.width, 8)
	testing.expect_value(t, loaded_tilemap.height, 8)
	testing.expect_value(t, loaded_tilemap.room_id, "small_room")
	testing.expect_value(t, loaded_tilemap.room_name, "???")
	testing.expect_value(t, loaded_tilemap.music_path, "audio/music/ambient.ogg")
	testing.expect_value(t, loaded_tilemap.camera_bounds.x, -200)
	testing.expect_value(t, loaded_tilemap.camera_bounds.y, -150)
	testing.expect_value(t, loaded_tilemap.camera_bounds.width, 528)
	testing.expect_value(t, loaded_tilemap.camera_bounds.height, 428)
	testing.expect_value(t, loaded_tilemap.collision_bounds.x, 0)
	testing.expect_value(t, loaded_tilemap.collision_bounds.y, 0)

	testing.expect_value(t, len(loaded_tilemap.base_tiles), 64)
	testing.expect_value(t, loaded_tilemap.base_tiles[0], TileType.GRASS_1)
	testing.expect_value(t, loaded_tilemap.base_tiles[1], TileType.GRASS_1)
	testing.expect_value(t, loaded_tilemap.base_tiles[2], TileType.GRASS_1)
	testing.expect_value(t, loaded_tilemap.base_tiles[3], TileType.GRASS_1)

	testing.expect_value(t, len(loaded_tilemap.deco_tiles), 40)
	testing.expect_value(t, loaded_tilemap.deco_tiles[0], TileType.EMPTY)
	testing.expect_value(t, loaded_tilemap.deco_tiles[1], TileType.EMPTY)
	testing.expect_value(t, loaded_tilemap.deco_tiles[2], TileType.EMPTY)
	testing.expect_value(t, loaded_tilemap.deco_tiles[3], TileType.EMPTY)

	testing.expect_value(t, len(loaded_tilemap.entities), 4)
	testing.expect_value(t, loaded_tilemap.entities[0].entity_type, EntityType.PLAYER)
	testing.expect_value(t, loaded_tilemap.entities[0].x, 64)
	testing.expect_value(t, loaded_tilemap.entities[0].y, 64)
	testing.expect_value(t, loaded_tilemap.entities[3].entity_type, EntityType.DOOR)
	testing.expect_value(t, loaded_tilemap.entities[3].target_room, "olivewood")
	testing.expect_value(t, loaded_tilemap.entities[3].target_door, "from_small_room")
}
