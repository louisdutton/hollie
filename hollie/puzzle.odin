package hollie

import "audio"
import rl "vendor:raylib"

pressure_plate_has_required_weight :: proc(
	player_count, crate_count: int,
	requires_both: bool,
) -> bool {
	required_weight := requires_both ? 2 : 1
	return player_count + crate_count >= required_weight
}

pressure_plate_has_crate :: proc(plate: ^Pressure_Plate, holdable: ^Holdable) -> bool {
	if holdable.held_by != nil do return false
	return rects_intersect(
		collider_rect_at(plate.position, plate.collider),
		collider_rect_at(holdable.position, holdable.collider),
	)
}

entity_update_puzzle_logic :: proc() {
	delta_time := rl.GetFrameTime()

	// Update pressure plate states
	pressure_plates := entity_get_pressure_plates()
	defer delete(pressure_plates)

	players := entity_get_players()
	defer delete(players)
	holdables := entity_get_holdables()
	defer delete(holdables)

	for plate in pressure_plates {
		was_active := plate.active
		// Reset activation state
		plate.activated_by = {}
		plate.active = false

		// Players and dropped crates each contribute one unit of pressure.
		for player in players {
			player_rect := collider_rect_at(player.position, player.collider)
			plate_rect := collider_rect_at(plate.position, plate.collider)

			if rects_intersect(player_rect, plate_rect) {
				plate.activated_by += {player.index}
			}
		}

		crate_count := 0
		for holdable in holdables {
			if pressure_plate_has_crate(plate, holdable) do crate_count += 1
		}
		plate.active = pressure_plate_has_required_weight(
			card(plate.activated_by),
			crate_count,
			plate.requires_both,
		)

		if plate.active != was_active {
			plate.animation_time = 0
			audio.sound_play(game.sounds["pressure_plate_toggle"])
		} else {
			plate.animation_time += delta_time
		}
	}

	// Update gate states based on trigger requirements
	gates := entity_get_gates()
	defer delete(gates)

	for gate in gates {
		assert(len(gate.required_triggers) > 0)

		all_triggers_active := true
		for trigger_id in gate.required_triggers {
			trigger_active := false

			// Check if this trigger ID matches any pressure plate
			for plate in pressure_plates {
				if plate.trigger_id == trigger_id {
					trigger_active = plate.active
					break
				}
			}

			if !trigger_active {
				all_triggers_active = false
				break
			}
		}

		// Apply inverted logic if needed
		new_open_state := gate.inverted ? !all_triggers_active : all_triggers_active

		gate.open = new_open_state
	}
}
