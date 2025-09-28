package hollie

import "input"
import "renderer"

init_title_screen :: proc() {}
unload_title_screen :: proc() {}

update_title_screen :: proc() {
	if input.is_key_pressed(.ENTER) do set_scene(.GAMEPLAY)
}

draw_title_screen :: proc() {
	ui_begin()
	defer ui_end()

	renderer.draw_rect_i(0, 0, design_width, design_height, renderer.GREEN)

	pos := Vec2{20, 10}
	renderer.draw_text_ex(
		game.font,
		"Hollie",
		pos,
		f32(game.font.baseSize) * 3.0,
		4,
		renderer.WHITE,
	)
	renderer.draw_text("Press ENTER to start", 120, 220, 20, renderer.DARKGREEN)
}
