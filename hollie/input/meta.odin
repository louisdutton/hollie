package input

import "../graphics"

// returns the current movement input for player 1
get_movement :: proc() -> (input: graphics.Vec2) {
	return get_movement_for_player(.Player_1)
}

// returns the current movement input for a specific player
get_movement_for_player :: proc(id: Player_Index) -> (input: graphics.Vec2) {
	key_x, key_y: f32

	if id == .Player_1 {
		// Player 1: WASD
		key_x = f32(int(is_key_down(.D)) - int(is_key_down(.A)))
		key_y = f32(int(is_key_down(.S)) - int(is_key_down(.W)))
		return vector2_normalize(
			{key_x + gamepad_axis_x(.Player_1), key_y + gamepad_axis_y(.Player_1)},
		)
	} else if id == .Player_2 {
		// Player 2: Arrow keys
		key_x = f32(int(is_key_down(.RIGHT)) - int(is_key_down(.LEFT)))
		key_y = f32(int(is_key_down(.DOWN)) - int(is_key_down(.UP)))
		return vector2_normalize(
			{key_x + gamepad_axis_x(.Player_2), key_y + gamepad_axis_y(.Player_2)},
		)
	}

	return {0, 0}
}

// Right stick up zooms in; down zooms out. Either player can adjust the shared camera.
get_zoom :: proc() -> f32 {
	zoom: f32
	for player in Player_Index {
		if !is_gamepad_available(player) do continue
		axis := get_gamepad_axis_movement(player, .RIGHT_Y)
		if abs(axis) <= JS_DEADZONE do continue
		amount := (abs(axis) - JS_DEADZONE) / (1 - JS_DEADZONE)
		zoom += axis < 0 ? amount : -amount
	}
	return clamp(zoom, -1, 1)
}

Player_Input :: enum {
	Interact,
	Jump,
}

// Returns true if the provided input was just pressed
is_pressed :: proc(input: Player_Input) -> bool {
	return is_pressed_for_player(input, .Player_1) || is_pressed_for_player(input, .Player_2)
}

// Returns true if the provided input was just pressed for a specific player
is_pressed_for_player :: proc(input: Player_Input, player_id: Player_Index) -> bool {
	if player_id == .Player_1 {
		// Player 1: H/J keys and gamepad 1
		switch input {
		case .Jump:
			return(
					is_gamepad_button_pressed(.Player_1, .RIGHT_FACE_RIGHT) ||
					is_key_pressed(settings.jump) \
				)
		case .Interact:
			return(
					is_gamepad_button_pressed(.Player_1, .RIGHT_FACE_UP) ||
					is_key_pressed(settings.interact) \
				)
		case: return false
		}
	} else if player_id == .Player_2 {
		// Player 2: L key and gamepad 2
		switch input {
		case .Jump:
			return(
					is_gamepad_button_pressed(.Player_2, .RIGHT_FACE_RIGHT) ||
					is_key_pressed(.SEMICOLON) \
				)
		case .Interact:
			return is_gamepad_button_pressed(.Player_2, .RIGHT_FACE_UP) || is_key_pressed(.L)
		case: return false
		}
	}
	return false
}
