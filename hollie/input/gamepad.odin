package input

import rl "vendor:raylib"

Gamepad_Button :: rl.GamepadButton
Gamepad_Axis :: rl.GamepadAxis
Player_Index :: enum {
	PLAYER_1,
	PLAYER_2,
}

JS_DEADZONE: f32 : 0.2 // the minimum joystick value for input to be registered

is_gamepad_available :: proc(gamepad: Player_Index) -> bool {
	return rl.IsGamepadAvailable(i32(gamepad))
}

is_gamepad_button_pressed :: proc(gamepad: Player_Index, button: Gamepad_Button) -> bool {
	pressed := rl.IsGamepadButtonPressed(i32(gamepad), button)
	if pressed do note_device_input(.Gamepad)
	return pressed
}

is_gamepad_button_down :: proc(gamepad: Player_Index, button: Gamepad_Button) -> bool {
	down := rl.IsGamepadButtonDown(i32(gamepad), button)
	if down do note_device_input(.Gamepad)
	return down
}

get_gamepad_axis_movement :: proc(gamepad: Player_Index, axis: Gamepad_Axis) -> f32 {
	value := rl.GetGamepadAxisMovement(i32(gamepad), axis)
	if abs(value) >= JS_DEADZONE do note_device_input(.Gamepad)
	return value
}

@(private)
gamepad_axis_x :: proc(gamepad: Player_Index = .PLAYER_1, deadzone := JS_DEADZONE) -> f32 {
	value := get_gamepad_axis_movement(gamepad, .LEFT_X)
	return abs(value) >= deadzone ? value : 0
}

@(private)
gamepad_axis_y :: proc(gamepad: Player_Index = .PLAYER_1, deadzone := JS_DEADZONE) -> f32 {
	value := get_gamepad_axis_movement(gamepad, .LEFT_Y)
	return abs(value) >= deadzone ? value : 0
}
