package tilemap

import "../graphics"
import "core:testing"

@(test)
test_collision_map_supports_non_rectangular_walkable_areas :: proc(t: ^testing.T) {
	previous_tilemap := tilemap
	previous_config := config
	defer tilemap = previous_tilemap
	defer config = previous_config

	tilemap = TileMap {
		width = 3,
		height = 2,
		tile_size = 16,
		config = {world_tile_size = 16},
		collision_tiles = []CollisionType{.Solid, .Walkable, .Solid, .Solid, .Walkable, .Solid},
	}
	config = tilemap.config

	testing.expect(t, is_tile_solid(0, 0))
	testing.expect(t, !is_tile_solid(1, 0))
	testing.expect(t, is_tile_solid(-1, 0), "outside the map should be solid")
	testing.expect(
		t,
		!check_collision(graphics.Bounding_Box{min = {16, 0, 0}, max = {32, 1, 16}}),
		"a collider ending on a tile edge should not include the adjacent solid tile",
	)
	testing.expect(
		t,
		check_collision(graphics.Bounding_Box{min = {24, 0, 0}, max = {40, 1, 16}}),
		"a collider spanning a solid tile should collide",
	)
	testing.expect(
		t,
		check_collision(graphics.Bounding_Box{min = {-1, 0, 0}, max = {15, 1, 16}}),
		"a collider leaving the map should collide",
	)
}
