package renderer

import rl "vendor:raylib"

draw_fps :: proc(x, y: i32) {
	rl.DrawFPS(x, y)
}
