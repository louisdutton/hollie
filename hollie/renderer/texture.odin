package renderer

import rl "vendor:raylib"

Texture2D :: rl.Texture2D

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
