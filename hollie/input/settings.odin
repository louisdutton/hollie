package input

/// Control settings and key bindings
Control_Settings :: struct {
	// Movement keys
	move_up:    Key,
	move_down:  Key,
	move_left:  Key,
	move_right: Key,

	// Action keys
	interact:   Key,
	attack:     Key,
	dodge:      Key,
	pause:      Key,

	// Utility keys
	reload:     Key,
}

@(private)
settings := Control_Settings {
	// Default WASD movement
	move_up    = .W,
	move_down  = .S,
	move_left  = .A,
	move_right = .D,

	// Default action keys
	interact   = .E,
	attack     = .SPACE,
	dodge      = .LEFT_SHIFT,
	pause      = .P,

	// Default utility keys
	reload     = .R,
}

/// Key binding names for display
Control_Binding :: struct {
	name: string,
	key:  ^Key,
}

@(private)
key_bindings := []Control_Binding {
	{"Move Up", &settings.move_up},
	{"Move Down", &settings.move_down},
	{"Move Left", &settings.move_left},
	{"Move Right", &settings.move_right},
	{"Interact", &settings.interact},
	{"Attack", &settings.attack},
	{"Dodge", &settings.dodge},
	{"Pause", &settings.pause},
	{"Reload", &settings.reload},
}

/// Get all key bindings for display in menus
get_key_bindings :: proc() -> []Control_Binding {
	return key_bindings
}

/// Get display name for a key
get_key_name :: proc(key: Key) -> string {
	#partial switch key {
	case .W: return "W"
	case .A: return "A"
	case .S: return "S"
	case .D: return "D"
	case .E: return "E"
	case .R: return "R"
	case .T: return "T"
	case .P: return "P"
	case .SPACE: return "Space"
	case .LEFT_SHIFT: return "Left Shift"
	case .RIGHT_SHIFT: return "Right Shift"
	case .LEFT_CONTROL: return "Left Ctrl"
	case .RIGHT_CONTROL: return "Right Ctrl"
	case .ESCAPE: return "Escape"
	case .ENTER: return "Enter"
	case .TAB: return "Tab"
	case .BACKSPACE: return "Backspace"
	case .UP: return "Up Arrow"
	case .DOWN: return "Down Arrow"
	case .LEFT: return "Left Arrow"
	case .RIGHT: return "Right Arrow"
	case: return "Unknown"
	}
}

/// Movement input using current key bindings
is_move_up_pressed :: proc() -> bool {
	return is_key_down(settings.move_up)
}

is_move_down_pressed :: proc() -> bool {
	return is_key_down(settings.move_down)
}

is_move_left_pressed :: proc() -> bool {
	return is_key_down(settings.move_left)
}

is_move_right_pressed :: proc() -> bool {
	return is_key_down(settings.move_right)
}

/// Action input using current key bindings
is_interact_pressed :: proc() -> bool {
	return is_key_pressed(settings.interact)
}

is_attack_pressed :: proc() -> bool {
	return is_key_pressed(settings.attack)
}

is_dodge_pressed :: proc() -> bool {
	return is_key_pressed(settings.dodge)
}

is_pause_pressed :: proc() -> bool {
	return is_key_pressed(settings.pause)
}

is_reload_pressed :: proc() -> bool {
	return is_key_pressed(settings.reload)
}
