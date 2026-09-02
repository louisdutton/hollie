package hollie

import "core:testing"

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
		collider = {size = {10, 10}, offset = {-5, -5}},
	}
	crate := Holdable {
		transform = {position = {10, 10}},
		collider = {size = {4, 4}, offset = {-2, -2}},
	}
	testing.expect(t, pressure_plate_has_crate(&plate, &crate))

	carrier: Player
	crate.held_by = &carrier
	testing.expect(t, !pressure_plate_has_crate(&plate, &crate))

	crate.held_by = nil
	crate.position = {30, 30}
	testing.expect(t, !pressure_plate_has_crate(&plate, &crate))
}
