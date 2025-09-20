package hollie

import rl "vendor:raylib"

PLAYER_1 :: 0

// returns the x component of the current movement input
@(private = "file")
input_get_axis_x :: proc(deadzone: f32 = 0.2) -> f32 {
	value := rl.GetGamepadAxisMovement(PLAYER_1, .LEFT_X)
	return abs(value) >= deadzone ? value : 0
}

// returns the y component of the current movement input
@(private = "file")
input_get_axis_y :: proc(deadzone: f32 = 0.2) -> f32 {
	value := rl.GetGamepadAxisMovement(PLAYER_1, .LEFT_Y)
	return abs(value) >= deadzone ? value : 0
}

// returns the current movement input for player 1
input_get_movement :: proc() -> (input: Vec2) {
	if rl.IsGamepadAvailable(PLAYER_1) {
		input = Vec2{input_get_axis_x(), input_get_axis_y()}
	} else {
		input = Vec2 {
			f32(int(rl.IsKeyDown(.D)) - int(rl.IsKeyDown(.A))),
			f32(int(rl.IsKeyDown(.S)) - int(rl.IsKeyDown(.W))),
		}
	}

	return rl.Vector2Normalize(input)
}

Player_Input :: enum {
	Attack,
	Accept,
	Roll,
}

input_pressed :: proc(input: Player_Input) -> bool {
	switch input {
	case .Roll:
		return rl.IsGamepadButtonPressed(PLAYER_1, .RIGHT_TRIGGER_2) || rl.IsKeyPressed(.K)
	case .Accept:
		return rl.IsGamepadButtonPressed(PLAYER_1, .RIGHT_FACE_RIGHT) || rl.IsKeyPressed(.J)
	case .Attack:
		return rl.IsGamepadButtonPressed(PLAYER_1, .RIGHT_FACE_LEFT) || rl.IsKeyPressed(.J)
	case:
		return false
	}
}
