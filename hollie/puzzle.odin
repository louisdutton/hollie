package hollie

import "audio"
import "renderer"

Player_ID :: enum {
	PLAYER_1,
	PLAYER_2,
}

entity_update_puzzle_logic :: proc() {
	// Update pressure plate states
	pressure_plates := entity_get_pressure_plates()
	defer delete(pressure_plates)

	players := entity_get_players()
	defer delete(players)

	for plate in pressure_plates {
		// Reset activation state
		plate.activated_by = {}
		plate.active = false

		// Check if any player is standing on the plate
		for player in players {
			player_rect := renderer.Rect{player.position.x - 8, player.position.y - 8, 16, 16}
			plate_pos := plate.position + plate.collider.offset
			plate_rect := renderer.Rect {
				plate_pos.x,
				plate_pos.y,
				plate.collider.size.x,
				plate.collider.size.y,
			}

			if rects_intersect(player_rect, plate_rect) {
				if player.index == .PLAYER_1 {
					plate.activated_by += {.PLAYER_1}
				} else {
					plate.activated_by += {.PLAYER_2}
				}
			}
		}

		// Update active state based on requirements
		if plate.requires_both {
			plate.active = .PLAYER_1 in plate.activated_by && .PLAYER_2 in plate.activated_by
		} else {
			plate.active = card(plate.activated_by) > 0
		}
	}

	// Update gate states based on trigger requirements
	gates := entity_get_gates()
	defer delete(gates)

	for gate in gates {
		if len(gate.required_triggers) == 0 {
			continue // Gate with no requirements stays as-is
		}

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

		// Play sound effect when gate state changes
		if new_open_state != gate.open {
			audio.sound_play(game.sounds["gate_close"])
		}

		gate.open = new_open_state
	}
}
