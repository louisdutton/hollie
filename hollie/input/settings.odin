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
