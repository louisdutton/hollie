package hollie

import rl "vendor:raylib"
import "window"

// Ensure ui scale is proportional to window size
ui_begin :: proc() {
	ui_scale := window.get_ui_scale()
	rl.BeginMode2D({zoom = ui_scale})
}

ui_end :: proc() {
	rl.EndMode2D()
}

// Returns the width of the provided text at the provided size.
ui_measure_text :: proc(text: string, size: int) -> int {
	return int(rl.MeasureText(cstring(raw_data(text)), i32(size)))
}

// Convert design coordinates to screen coordinates
ui_scale_x :: proc(design_x: f32) -> f32 {
	window_width := f32(rl.GetScreenWidth())
	return design_x * (window_width / f32(design_width))
}

ui_scale_y :: proc(design_y: f32) -> f32 {
	window_height := f32(rl.GetScreenHeight())
	return design_y * (window_height / f32(design_height))
}

ui_scale_size :: proc(design_size: int) -> int {
	// Scale size based on average of x/y scaling
	scale_x := f32(rl.GetScreenWidth()) / f32(design_width)
	scale_y := f32(rl.GetScreenHeight()) / f32(design_height)
	avg_scale := (scale_x + scale_y) / 2.0
	return int(f32(design_size) * avg_scale)
}
