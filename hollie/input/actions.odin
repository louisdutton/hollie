package input

import "core:fmt"
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
	label:            string,
	key:              Key,
	key_modifier:     Key_Modifier,
	gamepad_button:   Gamepad_Button,
	keyboard_display: string,
	gamepad_display:  string,
}

ACTION_BINDINGS := [Action]Action_Binding {
	.Menu_Navigate = {
		label = "Navigate",
		keyboard_display = "Arrows / WASD",
		gamepad_display = "LS / D-pad",
	},
	.Menu_Adjust = {
		label = "Adjust",
		keyboard_display = "Left / Right",
		gamepad_display = "Left / Right",
	},
	.Menu_Confirm = {label = "Select", key = .ENTER, gamepad_button = .RIGHT_FACE_DOWN},
	.Menu_Back = {label = "Back", key = .ESCAPE, gamepad_button = .RIGHT_FACE_RIGHT},
	.Editor_Move_Cursor = {label = "Move", gamepad_display = "LS / D-pad"},
	.Editor_Move_Camera = {label = "Camera", keyboard_display = "WASD", gamepad_display = "RS"},
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

action_control_name_for :: proc(action: Action) -> string {
	return action_control_name(action_binding(action))
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

@(private)
action_control_name :: proc(binding: Action_Binding) -> string {
	if active_device() == .Gamepad && is_gamepad_available(.PLAYER_1) {
		if binding.gamepad_display != "" do return binding.gamepad_display
		if binding.gamepad_button != .UNKNOWN {
			return gamepad_button_name(binding.gamepad_button, gamepad_layout())
		}
	}

	if binding.keyboard_display != "" do return binding.keyboard_display
	if binding.key == .KEY_NULL do return ""

	key_name := get_key_name(binding.key)
	if binding.key_modifier == .Control do return fmt.tprintf("Ctrl+%s", key_name)
	return key_name
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

@(private)
gamepad_button_name :: proc(button: Gamepad_Button, layout: Gamepad_Layout) -> string {
	switch layout {
	case .Xbox: #partial switch button {
			case .RIGHT_FACE_UP: return "Y"
			case .RIGHT_FACE_RIGHT: return "B"
			case .RIGHT_FACE_DOWN: return "A"
			case .RIGHT_FACE_LEFT: return "X"
			case .LEFT_TRIGGER_1: return "LB"
			case .LEFT_TRIGGER_2: return "LT"
			case .RIGHT_TRIGGER_1: return "RB"
			case .RIGHT_TRIGGER_2: return "RT"
			case .MIDDLE_LEFT: return "View"
			case .MIDDLE_RIGHT: return "Menu"
			case .LEFT_THUMB: return "L3"
			case .RIGHT_THUMB: return "R3"
			case: return "Gamepad"
			}
	case .Playstation: #partial switch button {
			case .RIGHT_FACE_UP: return "Triangle"
			case .RIGHT_FACE_RIGHT: return "Circle"
			case .RIGHT_FACE_DOWN: return "Cross"
			case .RIGHT_FACE_LEFT: return "Square"
			case .LEFT_TRIGGER_1: return "L1"
			case .LEFT_TRIGGER_2: return "L2"
			case .RIGHT_TRIGGER_1: return "R1"
			case .RIGHT_TRIGGER_2: return "R2"
			case .MIDDLE_LEFT: return "Create"
			case .MIDDLE_RIGHT: return "Options"
			case .LEFT_THUMB: return "L3"
			case .RIGHT_THUMB: return "R3"
			case: return "Gamepad"
			}
	case .Nintendo: #partial switch button {
			case .RIGHT_FACE_UP: return "X"
			case .RIGHT_FACE_RIGHT: return "A"
			case .RIGHT_FACE_DOWN: return "B"
			case .RIGHT_FACE_LEFT: return "Y"
			case .LEFT_TRIGGER_1: return "L"
			case .LEFT_TRIGGER_2: return "ZL"
			case .RIGHT_TRIGGER_1: return "R"
			case .RIGHT_TRIGGER_2: return "ZR"
			case .MIDDLE_LEFT: return "Minus"
			case .MIDDLE_RIGHT: return "Plus"
			case .LEFT_THUMB: return "L3"
			case .RIGHT_THUMB: return "R3"
			case: return "Gamepad"
			}
	}
	return "Gamepad"
}
