package tilemap

import "../renderer"
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
		collision_tiles = []CollisionType{.SOLID, .WALKABLE, .SOLID, .SOLID, .WALKABLE, .SOLID},
	}
	config = tilemap.config

	testing.expect(t, is_tile_solid(0, 0))
	testing.expect(t, !is_tile_solid(1, 0))
	testing.expect(t, is_tile_solid(-1, 0), "outside the map should be solid")
	testing.expect(
		t,
		!check_collision(renderer.Rect{x = 16, y = 0, width = 16, height = 16}),
		"a collider ending on a tile edge should not include the adjacent solid tile",
	)
	testing.expect(
		t,
		check_collision(renderer.Rect{x = 24, y = 0, width = 16, height = 16}),
		"a collider spanning a solid tile should collide",
	)
	testing.expect(
		t,
		check_collision(renderer.Rect{x = -1, y = 0, width = 16, height = 16}),
		"a collider leaving the map should collide",
	)
}
