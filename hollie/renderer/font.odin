package renderer

import rl "vendor:raylib"

DEFAULT_TEXT_COLOR :: WHITE
DEFAULT_TEXT_SIZE :: 20
DEFAULT_TEXT_SPACING :: 0.5
FONT_ATLAS_SIZE :: 64

@(private)
default_font: Font

load_font :: #force_inline proc(fileName: string) -> Font {
	font := rl.LoadFontEx(cstring(raw_data(fileName)), FONT_ATLAS_SIZE, nil, 0)
	rl.GenTextureMipmaps(&font.texture)
	rl.SetTextureFilter(font.texture, .TRILINEAR)
	return font
}

unload_font :: #force_inline proc(font: Font) {
	rl.UnloadFont(font)
}

set_default_font :: proc(font: Font) {
	default_font = font
}

draw_text :: #force_inline proc(
	text: string,
	x, y: int,
	size := DEFAULT_TEXT_SIZE,
	color := DEFAULT_TEXT_COLOR,
) {
	rl.DrawTextEx(
		default_font,
		cstring(raw_data(text)),
		{f32(x), f32(y)},
		f32(size),
		DEFAULT_TEXT_SPACING,
		color,
	)
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
	size := rl.MeasureTextEx(
		default_font,
		cstring(raw_data(text)),
		f32(fontSize),
		DEFAULT_TEXT_SPACING,
	)
	return i32(size.x)
}
