package renderer

import rl "vendor:raylib"

DEFAULT_TEXT_COLOR :: rl.WHITE
DEFAULT_TEXT_SIZE :: 20

// TODO: map string to cstring
draw_text :: proc(
	text: string,
	x, y: int,
	size: i32 = DEFAULT_TEXT_SIZE,
	color := DEFAULT_TEXT_COLOR,
) {
	rl.DrawText(cstring(raw_data(text)), i32(x), i32(y), size, color)
}

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
	thickness: f32 = 2,
	color := DEFAULT_TEXT_COLOR,
) {
	rl.DrawRectangleLinesEx({x, y, w, h}, thickness, color)
}
