package hollie

import "renderer"

// Title Screen
title_screen := struct {
	frames_counter: int,
	finish_screen:  int,
} {
	frames_counter = 0,
	finish_screen  = 0,
}

init_title_screen :: proc() {
	title_screen.frames_counter = 0
	title_screen.finish_screen = 0
}

update_title_screen :: proc() {
	if is_key_pressed(.ENTER) {
		title_screen.finish_screen = 2 // GAMEPLAY
	}
}

draw_title_screen :: proc() {
	ui_begin()
	defer ui_end()

	renderer.draw_rect_i(0, 0, DESIGN_WIDTH, DESIGN_HEIGHT, renderer.GREEN)

	pos := Vec2{20, 10}
	renderer.draw_text_ex(
		game_state.font,
		"TITLE SCREEN",
		pos,
		f32(game_state.font.baseSize) * 3.0,
		4,
		renderer.DARKGREEN,
	)
	renderer.draw_text(
		"PRESS ENTER or TAP to JUMP to GAMEPLAY SCREEN",
		120,
		220,
		20,
		renderer.DARKGREEN,
	)
}

unload_title_screen :: proc() {}

finish_title_screen :: proc() -> bool {
	return title_screen.finish_screen != 0
}
