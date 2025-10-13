package hollie

import "audio"

// Puzzle primitive types for 2-player async coordination

Puzzle_State :: enum {
	INACTIVE,
	PARTIAL, // One player has contributed
	COMPLETE, // Both players have contributed
}

Trigger_Type :: enum {
	BUTTON, // Momentary press
	SWITCH, // Toggle state
	PRESSURE_PLATE, // Requires standing on
}

Player_ID :: enum {
	PLAYER_1,
	PLAYER_2,
}

// Core puzzle trigger - something players can interact with
Puzzle_Trigger :: struct {
	id:            int,
	type:          Trigger_Type,
	position:      Vec2,
	size:          Vec2,
	active:        bool,
	requires_both: bool, // Requires both players to activate
	activated_by:  bit_set[Player_ID], // Which players have activated this
	target_gates:  [dynamic]int, // IDs of gates this trigger controls
}

// Puzzle gate - responds to trigger states
Puzzle_Gate :: struct {
	id:                int,
	position:          Vec2,
	size:              Vec2,
	open:              bool,
	previous_open:     bool, // Track previous state for SFX
	required_triggers: [dynamic]int, // Trigger IDs that must be active
	inverted:          bool, // Opens when triggers are inactive
}

// Overall puzzle system state
Puzzle_System :: struct {
	triggers: [dynamic]Puzzle_Trigger,
	gates:    [dynamic]Puzzle_Gate,
}

// Global puzzle system
puzzle_system: Puzzle_System

// Initialize the puzzle system
puzzle_init :: proc() {
	puzzle_system.triggers = make([dynamic]Puzzle_Trigger)
	puzzle_system.gates = make([dynamic]Puzzle_Gate)
}

// Clean up puzzle system
puzzle_fini :: proc() {
	for &trigger in puzzle_system.triggers {
		delete(trigger.target_gates)
	}
	for &gate in puzzle_system.gates {
		delete(gate.required_triggers)
	}
	delete(puzzle_system.triggers)
	delete(puzzle_system.gates)
}

// Create a new trigger
puzzle_trigger_create :: proc(
	id: int,
	type: Trigger_Type,
	position: Vec2,
	size: Vec2,
	requires_both: bool = false,
) -> ^Puzzle_Trigger {
	trigger := Puzzle_Trigger {
		id            = id,
		type          = type,
		position      = position,
		size          = size,
		requires_both = requires_both,
		target_gates  = make([dynamic]int),
	}
	append(&puzzle_system.triggers, trigger)
	return &puzzle_system.triggers[len(puzzle_system.triggers) - 1]
}

// Create a new gate
puzzle_gate_create :: proc(
	id: int,
	position: Vec2,
	size: Vec2,
	inverted: bool = false,
) -> ^Puzzle_Gate {
	gate := Puzzle_Gate {
		id                = id,
		position          = position,
		size              = size,
		inverted          = inverted,
		required_triggers = make([dynamic]int),
	}
	append(&puzzle_system.gates, gate)
	return &puzzle_system.gates[len(puzzle_system.gates) - 1]
}

// Link a trigger to control a gate
puzzle_link_trigger_to_gate :: proc(trigger_id: int, gate_id: int) {
	trigger := puzzle_get_trigger(trigger_id)
	gate := puzzle_get_gate(gate_id)

	if trigger != nil {
		append(&trigger.target_gates, gate_id)
	}
	if gate != nil {
		append(&gate.required_triggers, trigger_id)
	}
}

// Get trigger by ID
puzzle_get_trigger :: proc(id: int) -> ^Puzzle_Trigger {
	for &trigger in puzzle_system.triggers {
		if trigger.id == id {
			return &trigger
		}
	}
	return nil
}

// Get gate by ID
puzzle_get_gate :: proc(id: int) -> ^Puzzle_Gate {
	for &gate in puzzle_system.gates {
		if gate.id == id {
			return &gate
		}
	}
	return nil
}

// Check if position overlaps with trigger
puzzle_check_trigger_collision :: proc(position: Vec2, player_id: Player_ID) -> ^Puzzle_Trigger {
	for &trigger in puzzle_system.triggers {
		if position.x >= trigger.position.x &&
		   position.x <= trigger.position.x + trigger.size.x &&
		   position.y >= trigger.position.y &&
		   position.y <= trigger.position.y + trigger.size.y {
			return &trigger
		}
	}
	return nil
}

// Activate a trigger by a specific player
puzzle_trigger_activate :: proc(trigger: ^Puzzle_Trigger, player_id: Player_ID) {
	if trigger == nil do return

	switch trigger.type {
	case .BUTTON:
		// Momentary activation
		trigger.activated_by = {player_id}
		puzzle_trigger_update_state(trigger)
		audio.sound_play(game.sounds["button_press"])

	case .SWITCH:
		// Toggle state for this player
		was_active := trigger.active
		if player_id in trigger.activated_by {
			trigger.activated_by -= {player_id}
		} else {
			trigger.activated_by += {player_id}
		}
		puzzle_trigger_update_state(trigger)

		if trigger.active != was_active {
			if trigger.active {
				audio.sound_play(game.sounds["switch_on"])
			} else {
				audio.sound_play(game.sounds["switch_off"])
			}
		}

	case .PRESSURE_PLATE:
		// Standing on plate
		trigger.activated_by += {player_id}
		puzzle_trigger_update_state(trigger)
	}
}

// Deactivate a trigger by a specific player (for pressure plates)
puzzle_trigger_deactivate :: proc(trigger: ^Puzzle_Trigger, player_id: Player_ID) {
	if trigger == nil do return

	if trigger.type == .PRESSURE_PLATE {
		trigger.activated_by -= {player_id}
		puzzle_trigger_update_state(trigger)
	}
}

// Update trigger active state based on requirements
puzzle_trigger_update_state :: proc(trigger: ^Puzzle_Trigger) {
	switch trigger.type {
	case .PRESSURE_PLATE: // Pressure plates require continuous presence
			if trigger.requires_both {
				trigger.active = card(trigger.activated_by) == 2
			} else {
				trigger.active = card(trigger.activated_by) > 0
			}
	case .BUTTON, .SWITCH: // Buttons and switches use toggle logic
			if trigger.requires_both {
				trigger.active = card(trigger.activated_by) == 2
			} else {
				trigger.active = card(trigger.activated_by) > 0
			}
	}
}

// Update all puzzle elements
puzzle_update :: proc() {
	// Reset button states (momentary)
	for &trigger in puzzle_system.triggers {
		if trigger.type == .BUTTON {
			trigger.activated_by = {}
			trigger.active = false
		}
	}

	// Handle pressure plate collision detection using entities (continuous presence)

	// Reset all pressure plates first
	pressure_plates := entity_get_pressure_plates()
	defer delete(pressure_plates)

	for plate in pressure_plates {
		plate.activated_by = {}
		plate.active = false
	}

	// Get all players using new entity system
	players := entity_get_players()
	defer delete(players)

	// Check which players are currently standing on pressure plates
	for player in players {
		player_id: Player_ID
		switch player.player_index {
		case .PLAYER_1: player_id = .PLAYER_1
		case .PLAYER_2: player_id = .PLAYER_2
		}

		// Check collision with all pressure plates using proper entity collision
		player_entity := Entity(player^)
		for plate in pressure_plates {
			plate_entity := Entity(plate^)
			if entity_check_collision(&player_entity, &plate_entity) {
				plate.activated_by += {player_id}
			}
		}
	}

	// Update pressure plate active states
	for plate in pressure_plates {
		if plate.requires_both {
			plate.active = card(plate.activated_by) == 2
		} else {
			plate.active = card(plate.activated_by) > 0
		}
	}

	// Update gate states based on triggers
	gates := entity_get_gates()
	defer delete(gates)

	for gate in gates {
		gate_should_open := true

		// Check if all required triggers (pressure plates) are active
		for trigger_id in gate.required_triggers {
			// Find the pressure plate with this trigger_id
			trigger_active := false
			for plate in pressure_plates {
				if plate.trigger_id == trigger_id && plate.active {
					trigger_active = true
					break
				}
			}

			if !trigger_active {
				gate_should_open = false
				break
			}
		}

		// Apply inversion if needed
		if gate.inverted {
			gate_should_open = !gate_should_open
		}

		// Play SFX when gate state changes
		if gate.open != gate_should_open {
			if gate_should_open {
				audio.sound_play(game.sounds["gate_open"])
			} else {
				audio.sound_play(game.sounds["gate_close"])
			}
		}

		gate.open = gate_should_open
	}
}

// Check if position collides with any closed gates using union entities
puzzle_check_gate_collision :: proc(position: Vec2, size: Vec2 = {16, 16}) -> bool {
	gates := entity_get_gates()
	defer delete(gates)

	for gate in gates {
		if !gate.open {
			gate_pos := gate.position + gate.collider.offset
			// Character position needs offset to get collision box position
			char_pos := position + Vec2{-size.x / 2, -size.y / 2}
			// Check collision between character collision box and gate
			if char_pos.x < gate_pos.x + gate.collider.size.x &&
			   char_pos.x + size.x > gate_pos.x &&
			   char_pos.y < gate_pos.y + gate.collider.size.y &&
			   char_pos.y + size.y > gate_pos.y {
				return true
			}
		}
	}
	return false
}

// Get current puzzle completion state
puzzle_get_state :: proc() -> Puzzle_State {
	active_triggers := 0
	total_triggers := len(puzzle_system.triggers)

	for trigger in puzzle_system.triggers {
		if trigger.active {
			active_triggers += 1
		}
	}

	if active_triggers == 0 {
		return .INACTIVE
	} else if active_triggers == total_triggers {
		return .COMPLETE
	} else {
		return .PARTIAL
	}
}
