package renderer

import rl "vendor:raylib"

DEFAULT_TEXT_COLOR :: WHITE
DEFAULT_TEXT_SIZE :: 20

load_font :: #force_inline proc(fileName: string) -> Font {
	return rl.LoadFont(cstring(raw_data(fileName)))
}

unload_font :: #force_inline proc(font: Font) {
	rl.UnloadFont(font)
}

draw_text :: #force_inline proc(
	text: string,
	x, y: int,
	size := DEFAULT_TEXT_SIZE,
	color := DEFAULT_TEXT_COLOR,
) {
	rl.DrawText(cstring(raw_data(text)), i32(x), i32(y), i32(size), color)
}

draw_text_ex :: #force_inline proc(
	font: Font,
	text: string,
	position: [2]f32,
	fontSize, spacing: f32,
	tint := WHITE,
) {
	rl.DrawTextEx(font, cstring(raw_data(text)), position, fontSize, spacing, tint)
}

measure_text :: #force_inline proc(text: string, fontSize: i32) -> i32 {
	return rl.MeasureText(cstring(raw_data(text)), fontSize)
}
