package input

import "../renderer"

// returns the current movement input for player 1
get_movement :: proc() -> (input: renderer.Vec2) {
	key_x := f32(int(is_key_down(.D)) - int(is_key_down(.A)))
	key_y := f32(int(is_key_down(.S)) - int(is_key_down(.W)))

	return vector2_normalize({key_x + gamepad_axis_x(), key_y + gamepad_axis_y()})
}

Player_Input :: enum {
	Attack,
	Accept,
	Roll,
}

// Returns true if the provided input was just pressed
is_pressed :: proc(input: Player_Input) -> bool {
	switch input {
	case .Roll: return is_gamepad_button_pressed(PLAYER_1, .RIGHT_TRIGGER_2) || is_key_pressed(.K)
	case .Accept:
		return is_gamepad_button_pressed(PLAYER_1, .RIGHT_FACE_RIGHT) || is_key_pressed(.J)
	case .Attack:
		return is_gamepad_button_pressed(PLAYER_1, .RIGHT_FACE_LEFT) || is_key_pressed(.J)
	case: return false
	}
}
