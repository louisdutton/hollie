package tilemap

import "core:os"
import "core:strings"
import "core:testing"

@(test)
test_tilemap_load_save :: proc(t: ^testing.T) {
	// Reset any existing tilemap state
	reset_for_testing()

	// Create a test tilemap resource
	test_res := TilemapResource {
		width = 3,
		height = 2,
		tileset_path = "test/tileset.png",
		base_data = []TileType{.GRASS_1, .GRASS_2, .GRASS_3, .SAND_1, .SAND_2, .SAND_3},
		deco_data = []TileType{.EMPTY, .GRASS_DEC_1, .EMPTY, .GRASS_DEC_2, .EMPTY, .EMPTY},
		config = TilemapConfig{tile_size = 16, tileset_cols = 32},
	}

	// Test saving
	test_path := "test_tilemap.map"
	defer os.remove(test_path)
	defer reset_for_testing()

	// Load the test resource
	load_from_config(test_res)

	// Save it
	testing.expect(t, save_tilemap_to_file(test_path), "Failed to save tilemap")

	// Load it back
	loaded_res, ok := load_tilemap_from_file(test_path)
	testing.expect(t, ok, "Failed to load tilemap from file")
	defer {
		delete(loaded_res.base_data)
		delete(loaded_res.deco_data)
	}

	// Verify the loaded data matches original dimensions and config
	testing.expect_value(t, loaded_res.width, test_res.width)
	testing.expect_value(t, loaded_res.height, test_res.height)
	// Note: tileset_path gets hardcoded in save_tilemap_to_file, so we check for the expected hardcoded value
	testing.expect_value(
		t,
		loaded_res.tileset_path,
		"art/tileset/spr_tileset_sunnysideworld_16px.png",
	)
	testing.expect_value(t, loaded_res.config.tile_size, test_res.config.tile_size)
	testing.expect_value(t, loaded_res.config.tileset_cols, test_res.config.tileset_cols)

	// Verify base data
	testing.expect_value(t, len(loaded_res.base_data), len(test_res.base_data))
	for i in 0 ..< len(test_res.base_data) {
		testing.expect_value(t, loaded_res.base_data[i], test_res.base_data[i])
	}

	// Verify deco data
	testing.expect_value(t, len(loaded_res.deco_data), len(test_res.deco_data))
	for i in 0 ..< len(test_res.deco_data) {
		testing.expect_value(t, loaded_res.deco_data[i], test_res.deco_data[i])
	}
}

@(test)
test_tile_coordinates :: proc(t: ^testing.T) {
	// Test world to tile conversion
	world_pos := Vec2{32, 48}
	tile_x, tile_y := world_to_tile(world_pos)
	testing.expect_value(t, tile_x, 2)
	testing.expect_value(t, tile_y, 3)

	// Test tile to world conversion
	world_result := tile_to_world(tile_x, tile_y)
	testing.expect_value(t, world_result, Vec2{32, 48})
}

@(test)
test_tile_source_rect :: proc(t: ^testing.T) {
	// Test tile source rectangle calculation
	rect := get_tile_source_rect(.GRASS_1)
	testing.expect_value(t, rect.x, 0)
	testing.expect_value(t, rect.y, 0)
	testing.expect_value(t, rect.width, 16)
	testing.expect_value(t, rect.height, 16)

	// Test second row tile
	rect2 := get_tile_source_rect(.GRASS_4)
	testing.expect_value(t, rect2.x, 0)
	testing.expect_value(t, rect2.y, 16)
	testing.expect_value(t, rect2.width, 16)
	testing.expect_value(t, rect2.height, 16)
}

@(test)
test_tile_access :: proc(t: ^testing.T) {
	// Reset any existing tilemap state
	reset_for_testing()

	// Create small test tilemap
	// Layout: | GRASS_1  GRASS_2  |  (row 0)
	//         | GRASS_3  GRASS_4  |  (row 1)
	test_res := TilemapResource {
		width = 2,
		height = 2,
		tileset_path = "test.png",
		base_data = []TileType{.GRASS_1, .GRASS_2, .GRASS_3, .GRASS_4},
		deco_data = []TileType{.EMPTY, .GRASS_DEC_1, .GRASS_DEC_2, .EMPTY},
		config = TilemapConfig{tile_size = 16, tileset_cols = 32},
	}

	load_from_config(test_res)
	defer reset_for_testing()

	// Test valid tile access
	// (0,0) = index 0 = GRASS_1
	tile := get_base_tile(0, 0)
	testing.expect(t, tile != nil, "Should return valid tile")
	testing.expect_value(t, tile.type, TileType.GRASS_1)

	// (1,0) = index 1 = GRASS_2
	tile = get_base_tile(1, 0)
	testing.expect(t, tile != nil, "Should return valid tile")
	testing.expect_value(t, tile.type, TileType.GRASS_2)

	// (0,1) = index 2 = GRASS_3
	tile = get_base_tile(0, 1)
	testing.expect(t, tile != nil, "Should return valid tile")
	testing.expect_value(t, tile.type, TileType.GRASS_3)

	// (1,1) = index 3 = GRASS_4
	tile = get_base_tile(1, 1)
	testing.expect(t, tile != nil, "Should return valid tile")
	testing.expect_value(t, tile.type, TileType.GRASS_4)

	// Test out of bounds access
	tile = get_base_tile(-1, 0)
	testing.expect(t, tile == nil, "Should return nil for out of bounds")

	tile = get_base_tile(2, 0)
	testing.expect(t, tile == nil, "Should return nil for out of bounds")

	tile = get_base_tile(0, 2)
	testing.expect(t, tile == nil, "Should return nil for out of bounds")

	// Test decoration tiles
	// (1,0) = index 1 = GRASS_DEC_1
	deco_tile := get_deco_tile(1, 0)
	testing.expect(t, deco_tile != nil, "Should return valid deco tile")
	testing.expect_value(t, deco_tile.type, TileType.GRASS_DEC_1)
}
