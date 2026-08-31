package tilemap

import "core:testing"

@(test)
test_valid_map_has_no_validation_errors :: proc(t: ^testing.T) {
	context.allocator = context.temp_allocator

	tm, ok := deserialise_tilemap(OLIVEWOOD_MAP)
	testing.expect(t, ok, "test map should parse")
	if !ok do return

	errors := validate_tilemap(&tm)
	testing.expect_value(t, len(errors), 0)
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
