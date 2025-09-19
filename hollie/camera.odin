package hollie

import "core:math"
import rl "vendor:raylib"

CAMERA_SMOOTH: f32 : 0.1
ZOOM_RATE :: 0.01
ZOOM_DEFAULT :: 1.8
ZOOM_MAX :: 10.0
ZOOM_MIN :: 1.0

// Camera state
camera := rl.Camera2D {
	zoom = base_zoom,
}

// this is an internal value that should not be controlled directly by user input
@(private = "file")
screen_scale: f32 = 1.0

// this is the user-controlled zoom value
@(private = "file")
base_zoom: f32 = ZOOM_DEFAULT

camera_follow_target :: proc() {
	scale := 2 * camera.zoom
	x_offset := f32(rl.GetScreenWidth()) / scale
	y_offset := f32(rl.GetScreenHeight()) / scale
	camera.target.x = clamp(
		math.lerp(camera.target.x, player.position.x - x_offset, CAMERA_SMOOTH),
		0,
		1000, // TODO
	)
	camera.target.y = clamp(
		math.lerp(camera.target.y, player.position.y - y_offset, CAMERA_SMOOTH),
		0,
		1000, // TODO,
	)
}

init_camera :: proc() {
	screen_scale := get_screen_scale()
	update_camera()
}

update_camera :: proc() {
	update_camera_zoom()
	camera_follow_target()
}

update_camera_zoom :: proc() {
	if was_window_resized() {
		screen_scale = get_screen_scale()
	}

	if rl.IsKeyDown(.MINUS) {
		base_zoom = max(base_zoom - ZOOM_RATE, ZOOM_MIN)
	} else if rl.IsKeyDown(.EQUAL) {
		base_zoom = min(base_zoom + ZOOM_RATE, ZOOM_MAX)
	}

	camera.zoom = base_zoom * screen_scale
}

was_window_resized :: #force_inline proc() -> bool {
	return rl.IsWindowResized()
}
