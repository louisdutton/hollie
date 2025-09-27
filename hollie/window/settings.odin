package window

import rl "vendor:raylib"

/// Visual/window settings
Visual_Settings :: struct {
	fullscreen:    bool,
	vsync:         bool,
	target_fps:    int,
	window_width:  i32,
	window_height: i32,
}

@(private)
settings := Visual_Settings {
	fullscreen    = false,
	vsync         = true,
	target_fps    = 60,
	window_width  = 800,
	window_height = 450,
}

/// Common resolution presets
Resolution :: struct {
	width:  i32,
	height: i32,
	name:   string,
}

RESOLUTIONS := []Resolution {
	{800, 450, "800x450"},
	{1024, 576, "1024x576"},
	{1280, 720, "1280x720"},
	{1600, 900, "1600x900"},
	{1920, 1080, "1920x1080"},
}

/// Get current fullscreen state
is_fullscreen :: proc() -> bool {
	return settings.fullscreen
}

/// Toggle fullscreen mode
toggle_fullscreen :: proc() {
	if settings.fullscreen {
		rl.ToggleFullscreen()
		rl.SetWindowSize(settings.window_width, settings.window_height)
		settings.fullscreen = false
	} else {
		// Store current window size before going fullscreen
		settings.window_width = get_screen_width()
		settings.window_height = get_screen_height()
		rl.ToggleFullscreen()
		settings.fullscreen = true
	}
}

/// Set specific resolution (only works in windowed mode)
set_resolution :: proc(width, height: i32) {
	if !settings.fullscreen {
		settings.window_width = width
		settings.window_height = height
		rl.SetWindowSize(width, height)
	}
}

/// Get current window size
get_window_size :: proc() -> (i32, i32) {
	return settings.window_width, settings.window_height
}

/// Get available resolutions
get_available_resolutions :: proc() -> []Resolution {
	return RESOLUTIONS
}

/// Get current VSync state
is_vsync_enabled :: proc() -> bool {
	return settings.vsync
}

/// Toggle VSync
toggle_vsync :: proc() {
	settings.vsync = !settings.vsync
	// Note: Raylib doesn't have a direct VSync toggle, this would need platform-specific code
}

/// Get current target FPS
get_target_fps :: proc() -> int {
	return settings.target_fps
}

/// Set target FPS
set_target_fps :: proc(fps: int) {
	settings.target_fps = fps
	rl.SetTargetFPS(i32(fps))
}
