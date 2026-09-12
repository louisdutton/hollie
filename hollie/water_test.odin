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
	body.vertical_velocity = -120
	deepest := body.height
	for _ in 0 ..< 360 {
		physics_step(&body, collider, nil, PHYSICS_STEP, true)
		deepest = min(deepest, body.height)
	}
	equilibrium := WATER_SURFACE - min(WATER_DRAFT, collider.size.y * 0.55)
	testing.expect(t, abs(body.height - equilibrium) < 0.1)
	testing.expect(
		t,
		deepest < equilibrium - 1,
		"entry momentum must carry the body below its resting draft",
	)
	testing.expect(t, body.height > WATER_BED && !body.grounded && body.swimming)
	testing.expect(t, abs(body.vertical_velocity) < 0.1)
	physics_move_axis(&body, collider, {size * 2.5, size * 0.5}, nil, true)
	for _ in 0 ..< 60 do physics_step(&body, collider, nil, PHYSICS_STEP, true)
	testing.expect_value(t, body.position.x, size * 2.5)
	testing.expect_value(t, body.height, f32(0))
	testing.expect(t, body.grounded && !body.swimming)
}

@(test)
test_buoyancy_changes_velocity_without_snapping_height :: proc(t: ^testing.T) {
	collider := Collider {
		size = {8, 20, 8},
	}
	body := Transform {
		height = WATER_SURFACE - 14,
	}
	before := body.height
	body.vertical_velocity -= PHYSICS_GRAVITY * PHYSICS_STEP
	water_apply_buoyancy(&body, collider, PHYSICS_STEP)
	testing.expect_value(t, body.height, before)
	testing.expect(t, body.vertical_velocity > 0 && body.swimming)
	body = Transform {
		height            = WATER_SURFACE + 1,
		vertical_velocity = -100,
	}
	water_apply_buoyancy(&body, collider, PHYSICS_STEP)
	testing.expect_value(t, body.vertical_velocity, f32(-100))
	testing.expect(t, !body.swimming)
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
