package input

import "../renderer"
import rl "vendor:raylib"

Key :: rl.KeyboardKey

// Input state functions
is_key_pressed :: proc(key: Key) -> bool {
	pressed := rl.IsKeyPressed(key)
	if pressed do note_device_input(.Keyboard)
	return pressed
}

is_key_down :: proc(key: Key) -> bool {
	down := rl.IsKeyDown(key)
	if down do note_device_input(.Keyboard)
	return down
}

vector2_normalize :: proc(v: renderer.Vec2) -> renderer.Vec2 {
	return rl.Vector2Normalize(v)
}
