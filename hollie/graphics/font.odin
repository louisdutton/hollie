package graphics

import rl "vendor:raylib"

DEFAULT_TEXT_COLOR :: WHITE
DEFAULT_TEXT_SIZE :: 20
DEFAULT_TEXT_SPACING :: 0.5
FONT_ATLAS_SIZE :: 64 // source size used to rasterize the font atlas

@(private)
default_font: Font

load_font :: #force_inline proc(file_name: string, atlas_size: i32 = FONT_ATLAS_SIZE) -> Font {
	font := rl.LoadFontEx(cstring(raw_data(file_name)), atlas_size, nil, 0)
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
	font_size, spacing: f32,
	tint := WHITE,
) {
	rl.DrawTextEx(font, cstring(raw_data(text)), position, font_size, spacing, tint)
}

measure_text_ex :: #force_inline proc(font: Font, text: string, font_size, spacing: f32) -> Vec2 {
	return rl.MeasureTextEx(font, cstring(raw_data(text)), font_size, spacing)
}

measure_text :: #force_inline proc(text: string, font_size: i32) -> i32 {
	size := rl.MeasureTextEx(
		default_font,
		cstring(raw_data(text)),
		f32(font_size),
		DEFAULT_TEXT_SPACING,
	)
	return i32(size.x)
}

// Visible vertical centre of a single-line label, including the font's bearings.
// Half the font size centres the line box, not necessarily the drawn letters.
text_ink_center_y :: proc(font: Font, text: string, font_size: f32) -> f32 {
	if font.baseSize <= 0 do return font_size * 0.5
	top, bottom: f32
	found := false
	for codepoint in text {
		if codepoint == ' ' do continue
		index := rl.GetGlyphIndex(font, codepoint)
		glyph_top := f32(font.glyphs[index].offsetY)
		glyph_bottom := glyph_top + font.recs[index].height
		if !found {
			top, bottom = glyph_top, glyph_bottom
			found = true
		} else {
			top = min(top, glyph_top)
			bottom = max(bottom, glyph_bottom)
		}
	}
	return found ? (top + bottom) * 0.5 * font_size / f32(font.baseSize) : font_size * 0.5
}
