package graphics

import rl "vendor:raylib"

Texture2D :: rl.Texture2D
Texture_Filter :: rl.TextureFilter

POINT :: rl.TextureFilter.POINT
TRILINEAR :: rl.TextureFilter.TRILINEAR

draw_texture :: #force_inline proc(texture: Texture2D, x, y: i32, tint: Colour) {
	rl.DrawTexture(texture, x, y, tint)
}

draw_texture_rec :: #force_inline proc(
	texture: Texture2D,
	source: Rect,
	position: Vec2,
	tint := WHITE,
) {
	rl.DrawTextureRec(texture, source, position, tint)
}

draw_texture_pro :: #force_inline proc(
	texture: Texture2D,
	source: Rect,
	dest: Rect,
	origin: Vec2,
	rotation: f32,
	tint: Colour,
) {
	rl.DrawTexturePro(texture, source, dest, origin, rotation, tint)
}

load_texture :: #force_inline proc(path: string) -> Texture2D {
	return rl.LoadTexture(cstring(raw_data(path)))
}

unload_texture :: #force_inline proc(texture: Texture2D) {
	rl.UnloadTexture(texture)
}

set_texture_filter :: #force_inline proc(texture: Texture2D, filter: Texture_Filter) {
	rl.SetTextureFilter(texture, filter)
}

generate_texture_mipmaps :: #force_inline proc(texture: ^Texture2D) {
	rl.GenTextureMipmaps(texture)
}

draw_nine_patch :: #force_inline proc(
	texture: Texture2D,
	bounds: Rect,
	left, top, right, bottom: i32,
	tint: Colour,
) {
	patch := rl.NPatchInfo {
		source = {0, 0, f32(texture.width), f32(texture.height)},
		left   = left,
		top    = top,
		right  = right,
		bottom = bottom,
		layout = .NINE_PATCH,
	}
	rl.DrawTextureNPatch(texture, patch, bounds, {}, 0, tint)
}
