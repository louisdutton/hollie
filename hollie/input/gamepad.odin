package input

import rl "vendor:raylib"

GamepadButton :: rl.GamepadButton
GamepadAxis :: rl.GamepadAxis

PLAYER_1 :: 0

is_gamepad_available :: proc(gamepad: i32) -> bool {
	return rl.IsGamepadAvailable(gamepad)
}

is_gamepad_button_pressed :: proc(gamepad: i32, button: GamepadButton) -> bool {
	return rl.IsGamepadButtonPressed(gamepad, button)
}

get_gamepad_axis_movement :: proc(gamepad: i32, axis: GamepadAxis) -> f32 {
	return rl.GetGamepadAxisMovement(gamepad, axis)
}

@(private)
get_axis_x :: proc(deadzone: f32 = 0.2) -> f32 {
	value := get_gamepad_axis_movement(PLAYER_1, .LEFT_X)
	return abs(value) >= deadzone ? value : 0
}

@(private)
get_axis_y :: proc(deadzone: f32 = 0.2) -> f32 {
	value := get_gamepad_axis_movement(PLAYER_1, .LEFT_Y)
	return abs(value) >= deadzone ? value : 0
}
