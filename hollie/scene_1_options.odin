package hollie

import rl "vendor:raylib"

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
