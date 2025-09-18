package hollie

import "core:math"
import rl "vendor:raylib"

CAMERA_SMOOTH: f32 : 0.1
BASE_ZOOM: f32 : 2.0

// Camera state
camera := rl.Camera2D {
	zoom = BASE_ZOOM,
}

camera_follow_target :: proc() {
	camera.target.x = math.lerp(
		camera.target.x,
		player.position.x - f32(rl.GetScreenWidth()) / 2 / camera.zoom,
		CAMERA_SMOOTH,
	)
	camera.target.y = math.lerp(
		camera.target.y,
		player.position.y - f32(rl.GetScreenHeight()) / 2 / camera.zoom,
		CAMERA_SMOOTH,
	)
}

init_camera :: proc() {
	update_camera_zoom()
	camera_follow_target()
}

update_camera :: proc() {
	if was_window_resized() {
		update_camera_zoom()
	}
	camera_follow_target()
}

@(private = "file")
screen_scale: f32 = 1.0

update_camera_zoom :: proc() {
	screen_scale := get_screen_scale()
	camera.zoom = BASE_ZOOM * screen_scale
}

was_window_resized :: #force_inline proc() -> bool {
	return rl.IsWindowResized()
}
