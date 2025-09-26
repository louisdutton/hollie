package hollie

import "renderer"
import rl "vendor:raylib"

PLAYER_1 :: 0

// Keyboard key abstraction
Key :: rl.KeyboardKey

// Gamepad button abstraction
GamepadButton :: rl.GamepadButton
GamepadAxis :: rl.GamepadAxis

// Input state functions
is_key_pressed :: proc(key: Key) -> bool {
	return rl.IsKeyPressed(key)
}

is_key_down :: proc(key: Key) -> bool {
	return rl.IsKeyDown(key)
}

is_gamepad_available :: proc(gamepad: i32) -> bool {
	return rl.IsGamepadAvailable(gamepad)
}

is_gamepad_button_pressed :: proc(gamepad: i32, button: GamepadButton) -> bool {
	return rl.IsGamepadButtonPressed(gamepad, button)
}

get_gamepad_axis_movement :: proc(gamepad: i32, axis: GamepadAxis) -> f32 {
	return rl.GetGamepadAxisMovement(gamepad, axis)
}

// Gesture input
GestureType :: rl.Gesture

is_gesture_detected :: proc(gesture: GestureType) -> bool {
	return rl.IsGestureDetected(gesture)
}

// Vector utility
vector2_normalize :: proc(v: renderer.Vec2) -> renderer.Vec2 {
	return rl.Vector2Normalize(v)
}

// returns the x component of the current movement input
@(private = "file")
input_get_axis_x :: proc(deadzone: f32 = 0.2) -> f32 {
	value := get_gamepad_axis_movement(PLAYER_1, .LEFT_X)
	return abs(value) >= deadzone ? value : 0
}

// returns the y component of the current movement input
@(private = "file")
input_get_axis_y :: proc(deadzone: f32 = 0.2) -> f32 {
	value := get_gamepad_axis_movement(PLAYER_1, .LEFT_Y)
	return abs(value) >= deadzone ? value : 0
}

// returns the current movement input for player 1
input_get_movement :: proc() -> (input: renderer.Vec2) {
	if is_gamepad_available(PLAYER_1) {
		input = renderer.Vec2{input_get_axis_x(), input_get_axis_y()}
	} else {
		input = renderer.Vec2 {
			f32(int(is_key_down(.D)) - int(is_key_down(.A))),
			f32(int(is_key_down(.S)) - int(is_key_down(.W))),
		}
	}

	return vector2_normalize(input)
}

Player_Input :: enum {
	Attack,
	Accept,
	Roll,
}

input_pressed :: proc(input: Player_Input) -> bool {
	switch input {
	case .Roll:
		return is_gamepad_button_pressed(PLAYER_1, .RIGHT_TRIGGER_2) || is_key_pressed(.K)
	case .Accept:
		return is_gamepad_button_pressed(PLAYER_1, .RIGHT_FACE_RIGHT) || is_key_pressed(.J)
	case .Attack:
		return is_gamepad_button_pressed(PLAYER_1, .RIGHT_FACE_LEFT) || is_key_pressed(.J)
	case:
		return false
	}
}
