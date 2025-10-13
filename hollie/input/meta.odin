package input

import "../renderer"

// returns the current movement input for player 1
get_movement :: proc() -> (input: renderer.Vec2) {
	return get_movement_for_player(.PLAYER_1)
}

// returns the current movement input for a specific player
get_movement_for_player :: proc(id: Player_Index) -> (input: renderer.Vec2) {
	key_x, key_y: f32

	if id == .PLAYER_1 {
		// Player 1: WASD
		key_x = f32(int(is_key_down(.D)) - int(is_key_down(.A)))
		key_y = f32(int(is_key_down(.S)) - int(is_key_down(.W)))
		return vector2_normalize(
			{key_x + gamepad_axis_x(.PLAYER_1), key_y + gamepad_axis_y(.PLAYER_1)},
		)
	} else if id == .PLAYER_2 {
		// Player 2: Arrow keys
		key_x = f32(int(is_key_down(.RIGHT)) - int(is_key_down(.LEFT)))
		key_y = f32(int(is_key_down(.DOWN)) - int(is_key_down(.UP)))
		return vector2_normalize(
			{key_x + gamepad_axis_x(.PLAYER_2), key_y + gamepad_axis_y(.PLAYER_2)},
		)
	}

	return {0, 0}
}

Player_Input :: enum {
	Attack,
	Accept,
	Roll,
}

// Returns true if the provided input was just pressed
is_pressed :: proc(input: Player_Input) -> bool {
	return is_pressed_for_player(input, .PLAYER_1) || is_pressed_for_player(input, .PLAYER_2)
}

// Returns true if the provided input was just pressed for a specific player
is_pressed_for_player :: proc(input: Player_Input, player_id: Player_Index) -> bool {
	if player_id == .PLAYER_1 {
		// Player 1: J/K keys and gamepad 1
		switch input {
		case .Roll:
			return is_gamepad_button_pressed(.PLAYER_1, .RIGHT_TRIGGER_2) || is_key_pressed(.K)
		case .Accept:
			return is_gamepad_button_pressed(.PLAYER_1, .RIGHT_FACE_RIGHT) || is_key_pressed(.H)
		case .Attack:
			return is_gamepad_button_pressed(.PLAYER_1, .RIGHT_FACE_LEFT) || is_key_pressed(.J)
		case: return false
		}
	} else if player_id == .PLAYER_2 {
		// Player 2: L/; keys and gamepad 2
		switch input {
		case .Roll:
			return(
					is_gamepad_button_pressed(.PLAYER_2, .RIGHT_TRIGGER_2) ||
					is_key_pressed(.SEMICOLON) \
				)
		case .Accept:
			return is_gamepad_button_pressed(.PLAYER_2, .RIGHT_FACE_RIGHT) || is_key_pressed(.L)
		case .Attack:
			return is_gamepad_button_pressed(.PLAYER_2, .RIGHT_FACE_LEFT) || is_key_pressed(.L)
		case: return false
		}
	}
	return false
}
