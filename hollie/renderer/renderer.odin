package renderer

import rl "vendor:raylib"

DEFAULT_TEXT_COLOR :: rl.WHITE
DEFAULT_TEXT_SIZE :: 20
DEFAULT_THICKNESS :: 1

DEFAULT_BG_COLOR :: rl.BLACK
ROUNDED_SEGMENTS :: 3 // the number of segments used to render the corners of rounded rectangles
ROUNDED_VARIANTS := [?]f32{0.1, 0.25, 0.5, 1.0} // the degree of roundedness for a rectangle (0..1)

Roundness :: enum {
	SMALL,
	MEDIUM,
	LARGE,
	FULL,
}

draw_rect :: #force_inline proc(x, y, w, h: f32, color := DEFAULT_BG_COLOR) {
	rl.DrawRectangleV({x, y}, {w, h}, color)
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

// Helper function to draw level titles or other UI text
draw_text :: #force_inline proc(
	text: string,
	x, y: int,
	size := DEFAULT_TEXT_SIZE,
	color := DEFAULT_TEXT_COLOR,
) {
	rl.DrawText(cstring(raw_data(text)), i32(x), i32(y), i32(size), color)
}

draw_text_ex :: #force_inline proc(
	font: rl.Font,
	text: string,
	position: [2]f32,
	fontSize, spacing: f32,
	tint := rl.WHITE,
) {
	rl.DrawTextEx(font, cstring(raw_data(text)), position, fontSize, spacing, tint)
}
