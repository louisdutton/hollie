package input

import "core:strings"
import rl "vendor:raylib"

Action :: enum {
	Menu_Navigate,
	Menu_Adjust,
	Menu_Confirm,
	Menu_Back,
	Editor_Move_Cursor,
	Editor_Move_Camera,
	Editor_Paint,
	Editor_Erase,
	Editor_Change_Layer,
	Editor_Edit_Entity,
	Editor_Value_Previous,
	Editor_Value_Next,
	Editor_Value_Toggle,
	Editor_Select_Previous,
	Editor_Select_Next,
	Editor_Zoom_Out,
	Editor_Zoom_In,
	Editor_Toggle_Grid,
	Editor_Save,
	Editor_Toggle,
}

Key_Modifier :: enum {
	None,
	Control,
}

Action_Binding :: struct {
	label:          string,
	key:            Key,
	key_modifier:   Key_Modifier,
	gamepad_button: Gamepad_Button,
}

ACTION_BINDINGS := [Action]Action_Binding {
	.Menu_Navigate = {label = "Navigate"},
	.Menu_Adjust = {label = "Adjust"},
	.Menu_Confirm = {label = "Select", key = .ENTER, gamepad_button = .RIGHT_FACE_RIGHT},
	.Menu_Back = {label = "Back", key = .ESCAPE, gamepad_button = .RIGHT_FACE_DOWN},
	.Editor_Move_Cursor = {label = "Move"},
	.Editor_Move_Camera = {label = "Camera"},
	.Editor_Paint = {label = "Paint", gamepad_button = .RIGHT_FACE_RIGHT},
	.Editor_Erase = {label = "Erase", gamepad_button = .RIGHT_FACE_DOWN},
	.Editor_Change_Layer = {label = "Layer", key = .TAB, gamepad_button = .RIGHT_FACE_LEFT},
	.Editor_Edit_Entity = {label = "Edit mode", gamepad_button = .RIGHT_FACE_UP},
	.Editor_Value_Previous = {label = "Previous", gamepad_button = .RIGHT_FACE_DOWN},
	.Editor_Value_Next = {label = "Next", gamepad_button = .RIGHT_FACE_RIGHT},
	.Editor_Value_Toggle = {label = "Toggle", gamepad_button = .RIGHT_FACE_LEFT},
	.Editor_Select_Previous = {label = "Previous", key = .LEFT, gamepad_button = .LEFT_TRIGGER_1},
	.Editor_Select_Next = {label = "Next", key = .RIGHT, gamepad_button = .RIGHT_TRIGGER_1},
	.Editor_Zoom_Out = {label = "Zoom out", gamepad_button = .LEFT_TRIGGER_2},
	.Editor_Zoom_In = {label = "Zoom in", gamepad_button = .RIGHT_TRIGGER_2},
	.Editor_Toggle_Grid = {label = "Grid", key = .G, gamepad_button = .LEFT_THUMB},
	.Editor_Save = {
		label = "Save",
		key = .S,
		key_modifier = .Control,
		gamepad_button = .RIGHT_THUMB,
	},
	.Editor_Toggle = {label = "Exit", key = .F1, gamepad_button = .MIDDLE_LEFT},
}

action_binding :: proc(action: Action) -> Action_Binding {
	return ACTION_BINDINGS[action]
}

action_pressed :: proc(action: Action) -> bool {
	binding := action_binding(action)
	key_pressed :=
		binding.key != .KEY_NULL &&
		action_modifier_down(binding.key_modifier) &&
		is_key_pressed(binding.key)
	gamepad_pressed :=
		binding.gamepad_button != .UNKNOWN &&
		is_gamepad_button_pressed(.PLAYER_1, binding.gamepad_button)
	return key_pressed || gamepad_pressed
}

action_down :: proc(action: Action) -> bool {
	binding := action_binding(action)
	key_down :=
		binding.key != .KEY_NULL &&
		action_modifier_down(binding.key_modifier) &&
		is_key_down(binding.key)
	gamepad_down :=
		binding.gamepad_button != .UNKNOWN &&
		is_gamepad_button_down(.PLAYER_1, binding.gamepad_button)
	return key_down || gamepad_down
}

active_gamepad_layout :: proc() -> Gamepad_Layout {
	return gamepad_layout()
}

@(private)
action_modifier_down :: proc(modifier: Key_Modifier) -> bool {
	switch modifier {
	case .None: return true
	case .Control: return is_key_down(.LEFT_CONTROL) || is_key_down(.RIGHT_CONTROL)
	}
	return false
}

Gamepad_Layout :: enum {
	Xbox,
	Playstation,
	Nintendo,
}

@(private)
gamepad_layout :: proc() -> Gamepad_Layout {
	if !is_gamepad_available(.PLAYER_1) do return .Xbox
	name := string(rl.GetGamepadName(i32(Player_Index.PLAYER_1)))

	if strings.contains(name, "Nintendo") ||
	   strings.contains(name, "Switch") ||
	   strings.contains(name, "Joy-Con") {
		return .Nintendo
	}
	if strings.contains(name, "PlayStation") ||
	   strings.contains(name, "DualShock") ||
	   strings.contains(name, "DualSense") ||
	   strings.contains(name, "PS4") ||
	   strings.contains(name, "PS5") {
		return .Playstation
	}
	return .Xbox
}
