package hollie

import rl "vendor:raylib"

// Unified UI rendering with consistent scaling
ui_begin :: proc() {
	ui_camera := rl.Camera2D {
		zoom = get_screen_scale(),
	}
	rl.BeginMode2D(ui_camera)
}

ui_end :: proc() {
	rl.EndMode2D()
}

// Returns the width of the provided text at the provided size.
ui_measure_text :: proc(text: string, size: int) -> int {
	return int(rl.MeasureText(cstring(raw_data(text)), i32(size)))
}
