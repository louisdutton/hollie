package renderer

import rl "vendor:raylib"

draw_texture :: #force_inline proc(texture: Texture2D, x, y: i32, tint: Colour) {
	rl.DrawTexture(texture, x, y, tint)
}

draw_texture_rec :: #force_inline proc(
	texture: Texture2D,
	source: Rectangle,
	position: Vec2,
	tint: Colour,
) {
	rl.DrawTextureRec(texture, source, position, tint)
}

draw_texture_pro :: #force_inline proc(
	texture: Texture2D,
	source: Rectangle,
	dest: Rectangle,
	origin: Vec2,
	rotation: f32,
	tint: Colour,
) {
	rl.DrawTexturePro(texture, source, dest, origin, rotation, tint)
}
