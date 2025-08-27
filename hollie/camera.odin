package hollie

import "core:math"
import rl "vendor:raylib"

CAMERA_SMOOTH: f32 : 0.1

// Camera state
camera := rl.Camera2D {
	zoom = 2.0,
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
	camera_follow_target()
}

update_camera :: proc() {
	camera_follow_target()
}
