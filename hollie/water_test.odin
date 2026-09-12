package hollie

import "core:testing"
import "tilemap"

@(test)
test_mammal_wades_on_recessed_bed_and_steps_ashore :: proc(t: ^testing.T) {
	tm := tilemap.get_current_tilemap()
	previous := tm^
	defer tm^ = previous
	tm^ = tilemap.TileMap {
		width           = 3,
		height          = 1,
		base_tiles      = []tilemap.TileType{.Grass_1, .Shallow_Water, .Water},
		collision_tiles = []tilemap.CollisionType{.Walkable, .Walkable, .Walkable},
	}
	size := f32(tilemap.get_tile_size())
	body := Transform {
		position = {size * 1.5, size * 0.5},
		grounded = true,
	}
	collider := Collider {
		size   = {2, 8, 2},
		offset = {-1, 0, -1},
	}
	for _ in 0 ..< 60 do physics_step(&body, collider, nil, PHYSICS_STEP, true)
	testing.expect_value(t, body.height, WATER_SHALLOW_BED)
	testing.expect(t, body.grounded)
	shallow_position := body.position
	physics_move_axis(&body, collider, {size * 2.5, size * 0.5}, nil, true)
	testing.expect(t, body.position == shallow_position, "mammals cannot enter the deep channel")
	physics_move_axis(&body, collider, {size * 0.5, size * 0.5}, nil, true)
	physics_step(&body, collider, nil, PHYSICS_STEP, true)
	testing.expect(t, body.height == 0, "the shallow bank is a walkable step")
	testing.expect_value(t, body.position.x, size * 0.5)
}

@(test)
test_aquatic_mount_floats_across_depths_and_stays_in_water :: proc(t: ^testing.T) {
	tm := tilemap.get_current_tilemap()
	previous := tm^
	defer tm^ = previous
	tm^ = tilemap.TileMap {
		width           = 3,
		height          = 1,
		base_tiles      = []tilemap.TileType{.Grass_1, .Shallow_Water, .Water},
		collision_tiles = []tilemap.CollisionType{.Walkable, .Walkable, .Walkable},
	}
	size := f32(tilemap.get_tile_size())
	body := Transform {
		position = {size * 1.5, size * 0.5},
		aquatic  = true,
	}
	collider := Collider {
		size   = {2, 8, 2},
		offset = {-1, 0, -1},
	}
	for _ in 0 ..< 60 do physics_step(&body, collider, nil, PHYSICS_STEP, true)
	float_height := body.height
	testing.expect(t, float_height > WATER_SHALLOW_BED && float_height < WATER_SURFACE)
	physics_move_axis(&body, collider, {size * 2.5, size * 0.5}, nil, true)
	physics_step(&body, collider, nil, PHYSICS_STEP, true)
	testing.expect_value(t, body.position.x, size * 2.5)
	testing.expect(
		t,
		body.height == float_height,
		"deep water must not drop the mount onto the bed",
	)
	physics_move_axis(&body, collider, {size * 0.5, size * 0.5}, nil, true)
	testing.expect(t, body.position.x == size * 2.5, "aquatic mounts cannot wander onto land")
}
