package hollie

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

	case .SWITCH:
		// Toggle state for this player
		if player_id in trigger.activated_by {
			trigger.activated_by -= {player_id}
		} else {
			trigger.activated_by += {player_id}
		}
		puzzle_trigger_update_state(trigger)

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

	// Handle pressure plate collision detection (continuous presence)
	player1 := character_get_player(.PLAYER_1)
	player2 := character_get_player(.PLAYER_2)

	// Reset all pressure plates first
	for &trigger in puzzle_system.triggers {
		if trigger.type == .PRESSURE_PLATE {
			trigger.activated_by = {}
		}
	}

	// Check which players are currently standing on pressure plates
	if player1 != nil {
		for &trigger in puzzle_system.triggers {
			if trigger.type == .PRESSURE_PLATE &&
			   player1.position.x >= trigger.position.x &&
			   player1.position.x <= trigger.position.x + trigger.size.x &&
			   player1.position.y >= trigger.position.y &&
			   player1.position.y <= trigger.position.y + trigger.size.y {
				trigger.activated_by += {.PLAYER_1}
			}
		}
	}

	if player2 != nil {
		for &trigger in puzzle_system.triggers {
			if trigger.type == .PRESSURE_PLATE &&
			   player2.position.x >= trigger.position.x &&
			   player2.position.x <= trigger.position.x + trigger.size.x &&
			   player2.position.y >= trigger.position.y &&
			   player2.position.y <= trigger.position.y + trigger.size.y {
				trigger.activated_by += {.PLAYER_2}
			}
		}
	}

	// Update pressure plate active states
	for &trigger in puzzle_system.triggers {
		if trigger.type == .PRESSURE_PLATE {
			puzzle_trigger_update_state(&trigger)
		}
	}

	// Update gate states based on triggers
	for &gate in puzzle_system.gates {
		gate_should_open := true

		// Check if all required triggers are active
		for trigger_id in gate.required_triggers {
			trigger := puzzle_get_trigger(trigger_id)
			if trigger == nil || !trigger.active {
				gate_should_open = false
				break
			}
		}

		// Apply inversion if needed
		if gate.inverted {
			gate_should_open = !gate_should_open
		}

		gate.open = gate_should_open
	}
}

// Check if position collides with any closed gates
puzzle_check_gate_collision :: proc(position: Vec2, size: Vec2 = {16, 16}) -> bool {
	for gate in puzzle_system.gates {
		if !gate.open {
			// Check collision between position+size and gate
			if position.x < gate.position.x + gate.size.x &&
			   position.x + size.x > gate.position.x &&
			   position.y < gate.position.y + gate.size.y &&
			   position.y + size.y > gate.position.y {
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
