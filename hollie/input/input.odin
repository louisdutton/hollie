package input

import "../renderer"
import rl "vendor:raylib"

Key :: rl.KeyboardKey

// Input state functions
is_key_pressed :: proc(key: Key) -> bool {
	return rl.IsKeyPressed(key)
}

is_key_down :: proc(key: Key) -> bool {
	return rl.IsKeyDown(key)
}

vector2_normalize :: proc(v: renderer.Vec2) -> renderer.Vec2 {
	return rl.Vector2Normalize(v)
}
