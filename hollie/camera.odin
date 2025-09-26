package hollie

import "core:math"
import rl "vendor:raylib"
import "window"

CAMERA_SMOOTH: f32 : 0.1
ZOOM_RATE :: 0.01
ZOOM_DEFAULT :: 1.8
ZOOM_MAX :: 10.0
ZOOM_MIN :: 1.0
ZOOM_DIALOG :: 3.0

// Camera state
camera_bounds: rl.Rectangle
camera := rl.Camera2D {
	zoom = camera_base_zoom,
}

// this is an internal value that should not be controlled directly by user input
screen_scale: f32 = 1.0

// this is the user-controlled zoom value
camera_base_zoom: f32 = ZOOM_DEFAULT

camera_follow_target :: proc() {
	// Get player character
	player_char := character_get_player()
	if player_char == nil do return

	scale := 2 * camera.zoom
	x_offset := f32(rl.GetScreenWidth()) / scale
	y_offset := f32(rl.GetScreenHeight()) / scale

	max_x := camera_bounds.x + camera_bounds.width - x_offset * 2
	max_y := camera_bounds.y + camera_bounds.height - y_offset * 2
	min_x := camera_bounds.x
	min_y := camera_bounds.y

	camera.target.x = clamp(
		math.lerp(camera.target.x, player_char.position.x - x_offset, CAMERA_SMOOTH),
		min_x,
		max_x,
	)
	camera.target.y = clamp(
		math.lerp(camera.target.y, player_char.position.y - y_offset, CAMERA_SMOOTH),
		min_y,
		max_y,
	)
}

camera_init :: proc() {
	screen_scale := window.get_screen_scale(DESIGN_WIDTH, DESIGN_HEIGHT)
	camera_update()
}

camera_update :: proc() {
	camera_update_zoom()
	camera_follow_target()
}

camera_update_zoom :: proc() {
	if window.is_resized() {
		screen_scale = window.get_screen_scale(DESIGN_WIDTH, DESIGN_HEIGHT)
	}

	if rl.IsKeyDown(.MINUS) {
		camera_base_zoom = max(camera_base_zoom - ZOOM_RATE, ZOOM_MIN)
	} else if rl.IsKeyDown(.EQUAL) {
		camera_base_zoom = min(camera_base_zoom + ZOOM_RATE, ZOOM_MAX)
	}

	camera.zoom = camera_base_zoom * screen_scale
}

camera_set_bounds :: proc(bounds: rl.Rectangle) {
	camera_bounds = bounds
}
