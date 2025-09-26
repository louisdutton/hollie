package window

import rl "vendor:raylib"

// Window management functions
init :: proc(width, height: i32, title: string) {
	rl.SetTraceLogLevel(.WARNING)
	rl.SetWindowState({.WINDOW_RESIZABLE})
	rl.InitWindow(width, height, cstring(raw_data(title)))
	rl.SetTargetFPS(60)
}

fini :: proc() {
	rl.CloseWindow()
}

// Returns true if the user has requested for the window session to be terminated
should_close :: proc() -> bool {
	return rl.WindowShouldClose()
}

// Returns true if the window was resized this frame
is_resized :: proc() -> bool {
	return rl.IsWindowResized()
}

get_screen_width :: proc() -> i32 {
	return rl.GetScreenWidth()
}

get_screen_height :: proc() -> i32 {
	return rl.GetScreenHeight()
}

get_frame_time :: proc() -> f32 {
	return rl.GetFrameTime()
}

get_screen_scale :: proc(x, y: int) -> f32 {
	screen_width := f32(get_screen_width())
	screen_height := f32(get_screen_height())

	scale_x := screen_width / f32(x)
	scale_y := screen_height / f32(y)

	// Use the smaller scale to maintain aspect ratio
	return min(scale_x, scale_y)
}
