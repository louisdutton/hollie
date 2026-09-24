package hollie

import "core:testing"

@(test)
test_grass_moving_bodies_share_footprints :: proc(t: ^testing.T) {
	body := Transform {
		position = {20, 30},
		velocity = {60, 0},
	}
	collider := Collider {
		offset = {-6, 0, -4},
		size   = {12, 16, 8},
	}
	entities := []Entity {
		Player{transform = body, collider = collider},
		Enemy{transform = body, collider = collider},
		Npc{transform = body, collider = collider},
		Holdable{transform = body, collider = collider},
	}
	for &entity in entities {
		for trail in ([]bool{false, true}) {
			imprint, valid := grass_entity_imprint(&entity, trail)
			testing.expect(t, valid)
			testing.expect_value(t, imprint.position, Vec2{20, 30})
			testing.expect_value(t, imprint.direction, Vec2{1, 0})
			testing.expect_value(t, imprint.radius, f32(9))
			testing.expect(t, imprint.strength > 0)
		}
	}
}

@(test)
test_grass_excludes_carried_idle_and_airborne_bodies :: proc(t: ^testing.T) {
	collider := Collider {
		size = {12, 16, 8},
	}
	entities := []Entity {
		Holdable{transform = {velocity = {60, 0}}, collider = collider, held_by = 1},
		Holdable{collider = collider},
		Enemy{transform = {height = 8, velocity = {60, 0}}, collider = collider},
		Npc{transform = {height = -20, velocity = {60, 0}}, collider = collider},
		Enemy{transform = {swimming = true, velocity = {60, 0}}, collider = collider},
		Gate{},
	}
	for &entity in entities {
		for trail in ([]bool{false, true}) {
			_, valid := grass_entity_imprint(&entity, trail)
			testing.expect(t, !valid)
		}
	}
}

@(test)
test_grass_mount_supplies_contact_instead_of_rider :: proc(t: ^testing.T) {
	saved_world := world
	world = {}
	defer {
		delete(world.entities)
		world = saved_world
	}
	collider := Collider {
		size = {20, 16, 12},
	}
	entity_add(
		Player{index = .Player_1, transform = {velocity = {60, 0}}, collider = collider},
		&world,
	)
	entity_add(
		Enemy {
			mounted = true,
			rider = .Player_1,
			transform = {velocity = {60, 0}},
			collider = collider,
		},
		&world,
	)
	for trail in ([]bool{false, true}) {
		_, rider_valid := grass_entity_imprint(&world.entities[0], trail)
		imprint, mount_valid := grass_entity_imprint(&world.entities[1], trail)
		testing.expect(t, !rider_valid)
		testing.expect(t, mount_valid)
		testing.expect_value(t, imprint.radius, f32(13))
		testing.expect(t, grass_imprint_overlaps_chunk(imprint, {-1, -1}, {1, 1}))
		testing.expect(t, !grass_imprint_overlaps_chunk(imprint, {100, 100}, {120, 120}))
	}
}
