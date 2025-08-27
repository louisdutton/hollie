package hollie

import rl "vendor:raylib"

// Camera state
camera := rl.Camera2D {
	zoom = 2.0,
}

camera_follow_target :: proc() {
	camera.target.x = player.position.x - f32(rl.GetScreenWidth()) / 2 / camera.zoom
	camera.target.y = player.position.y - f32(rl.GetScreenHeight()) / 2 / camera.zoom
}

init_camera :: proc() {
	camera_follow_target()
}

update_camera :: proc() {
	camera_follow_target()
}
