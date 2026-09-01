package tilemap

import "../content"
import "core:strings"
import "core:testing"

validation_contains :: proc(errors: []Validation_Error, text: string, entity_index := -1) -> bool {
	for err in errors {
		if err.entity_index == entity_index && strings.contains(err.message, text) do return true
	}
	return false
}

@(test)
test_invalid_map_reports_semantic_errors :: proc(t: ^testing.T) {
	context.allocator = context.temp_allocator

	missing_triggers := make([dynamic]int)
	append(&missing_triggers, 99)

	tm := TileMap {
		width = 2,
		height = 2,
		base_tiles = []TileType{.GRASS_1},
		deco_tiles = []TileType{},
		entities = []EntityData {
			{
				x = 0,
				y = 0,
				entity_type = .GATE,
				width = 16,
				height = 16,
				required_triggers = missing_triggers,
			},
			{x = 64, y = 0, entity_type = .DOOR, width = 16, height = 16},
		},
		config = {tile_size = 16, tileset_cols = 32},
		room_id = "invalid",
		room_name = "Invalid",
		tileset_path = "tiles.png",
		camera_bounds = {0, 0, 32, 32},
		collision_bounds = {0, 0, 32, 32},
	}

	errors := validate_tilemap(&tm)
	testing.expect(t, len(errors) >= 6, "invalid map should report each independent problem")
}

@(test)
test_invalid_room_file_reports_typed_semantic_errors :: proc(t: ^testing.T) {
	context.allocator = context.temp_allocator

	room: Room_File
	room.size = {
		width  = 1,
		height = 1,
	}
	room.tileset = {
		tile_size = 16,
	}
	room.layers.decoration = []u16{0, 0}
	room.entities = []Room_File_Entity {
		{
			id = "duplicate",
			position = {x = 16, y = 0},
			properties = Room_File_Player{player_index = 3},
		},
		{id = "duplicate", properties = Room_File_Enemy{kind = content.Character_Kind(99)}},
		{id = "gate", properties = Room_File_Gate{required_trigger_ids = []int{99, 99}}},
		{id = "door", properties = Room_File_Door{}},
	}

	errors := validate_room_file(&room)
	testing.expect(t, len(errors) >= 12, "invalid typed content should report independent errors")
	testing.expect(t, validation_contains(errors[:], "room id must not be empty"))
	testing.expect(t, validation_contains(errors[:], "base layer contains"))
	testing.expect(t, validation_contains(errors[:], "entity origin lies outside", 0))
	testing.expect(t, validation_contains(errors[:], "player_index must be 1 or 2", 0))
	testing.expect(t, validation_contains(errors[:], "entity id \"duplicate\" is duplicated", 1))
	testing.expect(t, validation_contains(errors[:], "enemy kind is invalid", 1))
	testing.expect(t, validation_contains(errors[:], "gate references missing trigger ID 99", 2))
	testing.expect(t, validation_contains(errors[:], "door target_room_id must not be empty", 3))
}
