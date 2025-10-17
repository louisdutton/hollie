package renderer

import rl "vendor:raylib"

DEFAULT_THICKNESS :: 1
DEFAULT_BG_COLOR :: BLACK
ROUNDED_SEGMENTS :: 3 // the number of segments used to render the corners of rounded rectangles
ROUNDED_VARIANTS := [?]f32{0.1, 0.25, 0.5, 1.0} // the degree of roundedness for a rectangle (0..1)

Roundness :: enum {
	SMALL,
	MEDIUM,
	LARGE,
	FULL,
}

// Basic drawing functions
draw_rect :: #force_inline proc(x, y, w, h: f32, color := DEFAULT_BG_COLOR) {
	rl.DrawRectangleV({x, y}, {w, h}, color)
}

draw_rect_v :: #force_inline proc(position, size: Vec2, color: Colour) {
	rl.DrawRectangleV(position, size, color)
}

draw_rect_i :: #force_inline proc(x, y, width, height: i32, color: Colour) {
	rl.DrawRectangle(x, y, width, height, color)
}

draw_rect_outline :: #force_inline proc(
	x, y, w, h: f32,
	thickness: f32 = DEFAULT_THICKNESS,
	color := DEFAULT_TEXT_COLOR,
) {
	rl.DrawRectangleLinesEx({x, y, w, h}, thickness, color)
}

draw_circle :: #force_inline proc(x, y, radius: f32, color := DEFAULT_TEXT_COLOR) {
	rl.DrawCircleV({x, y}, radius, color)
}

draw_ellipse :: #force_inline proc(x, y, radius_h, radius_v: f32, color := DEFAULT_TEXT_COLOR) {
	rl.DrawEllipse(i32(x), i32(y), radius_h, radius_v, color)
}

draw_rect_rounded :: #force_inline proc(
	x, y, w, h: f32,
	roundness: Roundness = .MEDIUM,
	color := DEFAULT_BG_COLOR,
) {
	rect := rl.Rectangle{x, y, w, h}
	rl.DrawRectangleRounded(rect, ROUNDED_VARIANTS[roundness], ROUNDED_SEGMENTS, color)
}

draw_line :: #force_inline proc(start_x, start_y, end_x, end_y: f32, color: Colour) {
	rl.DrawLine(i32(start_x), i32(start_y), i32(end_x), i32(end_y), color)
}
