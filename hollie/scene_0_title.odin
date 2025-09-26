package hollie

import "renderer"
import rl "vendor:raylib"

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
	if rl.IsKeyPressed(.ENTER) || rl.IsGestureDetected(.TAP) {
		title_screen.finish_screen = 2 // GAMEPLAY
	}
}

draw_title_screen :: proc() {
	rl.DrawRectangle(0, 0, rl.GetScreenWidth(), rl.GetScreenHeight(), rl.GREEN)

	// Use unified UI rendering
	ui_begin()
	defer ui_end()

	pos := Vec2{20, 10}
	renderer.draw_text_ex(
		game_state.font,
		"TITLE SCREEN",
		pos,
		f32(game_state.font.baseSize) * 3.0,
		4,
		rl.DARKGREEN,
	)
	renderer.draw_text("PRESS ENTER or TAP to JUMP to GAMEPLAY SCREEN", 120, 220, 20, rl.DARKGREEN)
}

unload_title_screen :: proc() {}

finish_title_screen :: proc() -> bool {
	return title_screen.finish_screen != 0
}
