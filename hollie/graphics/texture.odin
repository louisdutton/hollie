package graphics

import rl "vendor:raylib"

Texture_2D :: rl.Texture2D
Texture_Filter :: rl.TextureFilter

POINT :: rl.TextureFilter.POINT
TRILINEAR :: rl.TextureFilter.TRILINEAR

draw_texture :: #force_inline proc(texture: Texture_2D, x, y: i32, tint: Colour) {
	rl.DrawTexture(texture, x, y, tint)
}

draw_texture_rec :: #force_inline proc(
	texture: Texture_2D,
	source: Rect,
	position: Vec2,
	tint := WHITE,
) {
	rl.DrawTextureRec(texture, source, position, tint)
}

draw_texture_pro :: #force_inline proc(
	texture: Texture_2D,
	source: Rect,
	dest: Rect,
	origin: Vec2,
	rotation: f32,
	tint: Colour,
) {
	rl.DrawTexturePro(texture, source, dest, origin, rotation, tint)
}

load_texture :: #force_inline proc(path: string) -> Texture_2D {
	return rl.LoadTexture(cstring(raw_data(path)))
}

// LoadTextureFromImage copies pixels to the GPU; the caller retains the slice.
load_texture_colors :: proc(pixels: []Colour, width, height: int) -> Texture_2D {
	assert(len(pixels) == width * height)
	image := rl.Image {
		data    = raw_data(pixels),
		width   = i32(width),
		height  = i32(height),
		mipmaps = 1,
		format  = .UNCOMPRESSED_R8G8B8A8,
	}
	texture := rl.LoadTextureFromImage(image)
	rl.SetTextureFilter(texture, .BILINEAR)
	rl.SetTextureWrap(texture, .CLAMP)
	return texture
}

unload_texture :: #force_inline proc(texture: Texture_2D) {
	rl.UnloadTexture(texture)
}


set_texture_filter :: #force_inline proc(texture: Texture_2D, filter: Texture_Filter) {
	rl.SetTextureFilter(texture, filter)
}

generate_texture_mipmaps :: #force_inline proc(texture: ^Texture_2D) {
	rl.GenTextureMipmaps(texture)
}

draw_nine_patch :: #force_inline proc(
	texture: Texture_2D,
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
