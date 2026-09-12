package hollie

import "core:testing"

@(test)
test_pressure_plate_requires_resting_contact_for_players_enemies_and_crates :: proc(
	t: ^testing.T,
) {
	plate := Pressure_Plate {
		collider = {size = {10, 3, 10}},
	}
	transform := Transform {
		position = {5, 5},
		height   = 3,
		grounded = true,
	}
	collider := Collider {
		size   = {2, 4, 2},
		offset = {-1, 0, -1},
	}
	bodies := [3]Entity {
		Player{transform = transform, collider = collider},
		Enemy{transform = transform, collider = collider},
		Holdable{transform = transform, collider = collider},
	}
	for &body in bodies do testing.expect(t, pressure_plate_supports(&plate, &body))
	airborne := Entity(Player{transform = {position = {5, 5}, height = 8}, collider = collider})
	testing.expect(t, !pressure_plate_supports(&plate, &airborne))
	jumping := Entity(Player{transform = {position = {5, 5}, height = 3}, collider = collider})
	testing.expect(t, !pressure_plate_supports(&plate, &jumping))
	beside := Entity(
		Enemy{transform = {position = {12, 5}, height = 3, grounded = true}, collider = collider},
	)
	testing.expect(t, !pressure_plate_supports(&plate, &beside))
}

@(test)
test_pressure_plate_accepts_players_and_dropped_crates_as_weight :: proc(t: ^testing.T) {
	testing.expect(t, pressure_plate_has_required_weight(0, 1, false))
	testing.expect(t, pressure_plate_has_required_weight(1, 0, false))
	testing.expect(t, !pressure_plate_has_required_weight(0, 0, false))
	testing.expect(t, pressure_plate_has_required_weight(1, 1, true))
	testing.expect(t, pressure_plate_has_required_weight(0, 2, true))
	testing.expect(t, !pressure_plate_has_required_weight(0, 1, true))
}

@(test)
test_only_dropped_crates_overlap_pressure_plates :: proc(t: ^testing.T) {
	plate := Pressure_Plate {
		transform = {position = {10, 10}},
		collider = {size = {10, 1, 10}, offset = {-5, 0, -5}},
	}
	crate := Holdable {
		transform = {position = {10, 10}, height = 1, grounded = true},
		collider = {size = {4, 4, 4}, offset = {-2, 0, -2}},
	}
	testing.expect(t, pressure_plate_has_crate(&plate, &crate))

	carrier: Player
	crate.held_by = &carrier
	testing.expect(t, !pressure_plate_has_crate(&plate, &crate))

	crate.held_by = nil
	crate.position = {30, 30}
	testing.expect(t, !pressure_plate_has_crate(&plate, &crate))
}
