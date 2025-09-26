package hollie

import rl "vendor:raylib"
import "window"

ui_begin :: proc() {
	rl.BeginMode2D({zoom = screen_scale})
}

ui_end :: proc() {
	rl.EndMode2D()
}

// Returns the width of the provided text at the provided size.
ui_measure_text :: proc(text: string, size: int) -> int {
	return int(rl.MeasureText(cstring(raw_data(text)), i32(size)))
}
