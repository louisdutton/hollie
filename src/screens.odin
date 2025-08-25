package hollie

import rl "vendor:raylib"

// Gameplay Screen
gameplay_state := struct {
	is_paused: bool,
} {
	is_paused = false,
}

draw_grid :: proc(size: i32) {
	for x in 0 ..< 10 {
		for y in 0 ..< 10 {
			rl.DrawRectangleLines(i32(x) * size, i32(y) * size, size, size, rl.WHITE)
		}
	}
}

init_gameplay_screen :: proc() {
	init_player()
	init_camera()
}

update_gameplay_screen :: proc() {
	if rl.IsKeyPressed(.P) {
		gameplay_state.is_paused = !gameplay_state.is_paused
	}

	if !gameplay_state.is_paused {
		update_player()
		update_camera()
	}
}

draw_gameplay_screen :: proc() {
	rl.BeginMode2D(camera)

	draw_player()
	draw_grid(16)

	rl.EndMode2D()

	if gameplay_state.is_paused {
		w := rl.GetScreenWidth()
		h := rl.GetRenderHeight()
		rl.DrawRectangle(0, 0, w, h, rl.Fade(rl.BLACK, 0.75))
		tx := w / 2 - 60
		ty := h / 2 - 30
		rl.DrawText("PAUSED", tx, ty, 20, rl.WHITE)
	}
}

unload_gameplay_screen :: proc() {
	unload_player()
}

finish_gameplay_screen :: proc() -> int {
	return 0
}

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
		rl.PlaySound(game_state.fx_coin)
	}
}

draw_title_screen :: proc() {
	rl.DrawRectangle(0, 0, rl.GetScreenWidth(), rl.GetScreenHeight(), rl.GREEN)
	pos := rl.Vector2{20, 10}
	rl.DrawTextEx(
		game_state.font,
		"TITLE SCREEN",
		pos,
		f32(game_state.font.baseSize) * 3.0,
		4,
		rl.DARKGREEN,
	)
	rl.DrawText("PRESS ENTER or TAP to JUMP to GAMEPLAY SCREEN", 120, 220, 20, rl.DARKGREEN)
}

unload_title_screen :: proc() {}

finish_title_screen :: proc() -> bool {
	return title_screen.finish_screen != 0
}

// Options Screen
options_screen := struct {
	frames_counter: int,
	finish_screen:  int,
} {
	frames_counter = 0,
	finish_screen  = 0,
}

init_options_screen :: proc() {
	options_screen.frames_counter = 0
	options_screen.finish_screen = 0
}

update_options_screen :: proc() {
	if rl.IsKeyPressed(.ENTER) {
		options_screen.finish_screen = 1
	}
}

draw_options_screen :: proc() {
	rl.DrawRectangle(0, 0, rl.GetScreenWidth(), rl.GetScreenHeight(), rl.BLUE)
	rl.DrawText("OPTIONS SCREEN", 20, 20, 40, rl.DARKBLUE)
	rl.DrawText("PRESS ENTER to RETURN to TITLE SCREEN", 120, 220, 20, rl.DARKBLUE)
}

unload_options_screen :: proc() {}

finish_options_screen :: proc() -> bool {
	return options_screen.finish_screen != 0
}

// Ending Screen
ending_screen := struct {
	frames_counter: int,
	finish_screen:  int,
} {
	frames_counter = 0,
	finish_screen  = 0,
}

init_ending_screen :: proc() {
	ending_screen.frames_counter = 0
	ending_screen.finish_screen = 0
}

update_ending_screen :: proc() {
	ending_screen.frames_counter += 1
	if rl.IsKeyPressed(.ENTER) {
		ending_screen.finish_screen = 1
	}
}

draw_ending_screen :: proc() {
	rl.DrawRectangle(0, 0, rl.GetScreenWidth(), rl.GetScreenHeight(), rl.BLUE)
	rl.DrawText("ENDING SCREEN", 20, 20, 40, rl.DARKBLUE)
	rl.DrawText("PRESS ENTER to RETURN to TITLE SCREEN", 120, 220, 20, rl.DARKBLUE)
}

unload_ending_screen :: proc() {}

finish_ending_screen :: proc() -> int {
	return ending_screen.finish_screen
}
