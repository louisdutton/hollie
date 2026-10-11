package input

import "../graphics"
import rl "vendor:raylib"

Key :: rl.KeyboardKey

// Input state functions
is_key_pressed :: proc(key: Key) -> bool {
	when ODIN_DEBUG || ODIN_TEST {
		if automation_enabled {
			pressed := automation_current.keys[int(key)] && !automation_previous.keys[int(key)]
			if pressed do note_device_input(.Keyboard)
			return pressed
		}
	}
	pressed := rl.IsKeyPressed(key)
	if pressed do note_device_input(.Keyboard)
	return pressed
}

is_key_down :: proc(key: Key) -> bool {
	when ODIN_DEBUG || ODIN_TEST {
		if automation_enabled {
			down := automation_current.keys[int(key)]
			if down do note_device_input(.Keyboard)
			return down
		}
	}
	down := rl.IsKeyDown(key)
	if down do note_device_input(.Keyboard)
	return down
}

vector2_normalize :: proc(v: graphics.Vec2) -> graphics.Vec2 {
	return rl.Vector2Normalize(v)
}
