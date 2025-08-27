package renderer

import "core:c"
import "core:strings"
import rl "vendor:raylib"

DEFAULT_TEXT_COLOR :: rl.WHITE
DEFAULT_TEXT_SIZE :: 20

// TODO: map string to cstring
draw_text :: proc(text: string, x: int, y: int) {
	ctext := strings.clone_to_cstring(text)
	defer delete(ctext)
	rl.DrawText(ctext, c.int(x), c.int(y), DEFAULT_TEXT_SIZE, DEFAULT_TEXT_COLOR)
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

draw_rect_rounded :: #force_inline proc(
	x: f32,
	y: f32,
	w: f32,
	h: f32,
	roundness := Roundness.SMALL,
	color := DEFAULT_BG_COLOR,
) {
	rl.DrawRectangleRounded({x, y, w, h}, ROUNDED_VARIANTS[roundness], ROUNDED_SEGMENTS, color)
}
