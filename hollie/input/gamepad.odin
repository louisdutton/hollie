package input

import rl "vendor:raylib"

Gamepad_Button :: rl.GamepadButton
Gamepad_Axis :: rl.GamepadAxis
Player_Index :: enum {
	Player_1,
	Player_2,
}

JS_DEADZONE: f32 : 0.2 // minimum joystick magnitude registered as input

is_gamepad_available :: proc(gamepad: Player_Index) -> bool {
	when ODIN_DEBUG || ODIN_TEST {
		if automation_enabled do return automation_current.available[gamepad]
	}
	return rl.IsGamepadAvailable(i32(gamepad))
}

is_gamepad_button_pressed :: proc(gamepad: Player_Index, button: Gamepad_Button) -> bool {
	when ODIN_DEBUG || ODIN_TEST {
		if automation_enabled {
			pressed :=
				automation_current.buttons[gamepad][int(button)] &&
				!automation_previous.buttons[gamepad][int(button)]
			if pressed do note_device_input(.Gamepad)
			return pressed
		}
	}
	pressed := rl.IsGamepadButtonPressed(i32(gamepad), button)
	if pressed do note_device_input(.Gamepad)
	return pressed
}

is_gamepad_button_down :: proc(gamepad: Player_Index, button: Gamepad_Button) -> bool {
	when ODIN_DEBUG || ODIN_TEST {
		if automation_enabled {
			down := automation_current.buttons[gamepad][int(button)]
			if down do note_device_input(.Gamepad)
			return down
		}
	}
	down := rl.IsGamepadButtonDown(i32(gamepad), button)
	if down do note_device_input(.Gamepad)
	return down
}

get_gamepad_axis_movement :: proc(gamepad: Player_Index, axis: Gamepad_Axis) -> f32 {
	when ODIN_DEBUG || ODIN_TEST {
		if automation_enabled {
			value := automation_current.axes[gamepad][int(axis)]
			if abs(value) >= JS_DEADZONE do note_device_input(.Gamepad)
			return value
		}
	}
	value := rl.GetGamepadAxisMovement(i32(gamepad), axis)
	if abs(value) >= JS_DEADZONE do note_device_input(.Gamepad)
	return value
}

@(private)
gamepad_axis_x :: proc(gamepad: Player_Index = .Player_1, deadzone := JS_DEADZONE) -> f32 {
	value := get_gamepad_axis_movement(gamepad, .LEFT_X)
	return abs(value) >= deadzone ? value : 0
}

@(private)
gamepad_axis_y :: proc(gamepad: Player_Index = .Player_1, deadzone := JS_DEADZONE) -> f32 {
	value := get_gamepad_axis_movement(gamepad, .LEFT_Y)
	return abs(value) >= deadzone ? value : 0
}
