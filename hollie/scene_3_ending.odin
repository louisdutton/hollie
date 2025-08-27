package hollie

import rl "vendor:raylib"

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
