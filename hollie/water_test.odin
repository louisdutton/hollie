package hollie

import "core:testing"
import "tilemap"

@(test)
test_water_floats_bodies_and_allows_both_shore_crossings :: proc(t: ^testing.T) {
	tm := tilemap.get_current_tilemap()
	previous := tm^
	defer tm^ = previous
	tm^ = tilemap.TileMap {
		width           = 3,
		height          = 1,
		base_tiles      = []tilemap.TileType{.Grass_1, .Water, .Grass_1},
		collision_tiles = []tilemap.CollisionType{.Walkable, .Walkable, .Walkable},
	}
	size := f32(tilemap.get_tile_size())
	body := Transform {
		position = {size * 0.5, size * 0.5},
		grounded = true,
	}
	collider := Collider {
		size   = {2, 8, 2},
		offset = {-1, 0, -1},
	}
	physics_move_axis(&body, collider, {size * 1.5, size * 0.5}, nil, true)
	testing.expect_value(t, body.position.x, size * 1.5)
	for _ in 0 ..< 60 do physics_step(&body, collider, nil, PHYSICS_STEP, true)
	testing.expect_value(t, body.height, WATER_FLOAT_HEIGHT)
	testing.expect(t, body.height > WATER_BED && body.grounded)
	physics_move_axis(&body, collider, {size * 2.5, size * 0.5}, nil, true)
	physics_step(&body, collider, nil, PHYSICS_STEP, true)
	testing.expect_value(t, body.position.x, size * 2.5)
	testing.expect_value(t, body.height, f32(0))
}

@(test)
test_turtle_provides_water_speed_advantage :: proc(t: ^testing.T) {
	turtle := water_movement_profile(animal_riding_profile(.Turtle), true, true)
	player := water_movement_profile(PLAYER_MOVEMENT_PROFILE, true)
	horse := water_movement_profile(animal_riding_profile(.Horse), true)
	testing.expect(t, turtle.max_speed > player.max_speed)
	testing.expect(t, turtle.max_speed > horse.max_speed)
	testing.expect_value(
		t,
		water_movement_profile(PLAYER_MOVEMENT_PROFILE, false),
		PLAYER_MOVEMENT_PROFILE,
	)
}
