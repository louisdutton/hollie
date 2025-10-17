package renderer

import rl "vendor:raylib"

Vec2 :: rl.Vector2
Colour :: rl.Color
Font :: rl.Font
Rect :: rl.Rectangle
Camera2D :: rl.Camera2D

begin_mode_2d :: #force_inline proc(camera: Camera2D) {
	rl.BeginMode2D(camera)
}

end_mode_2d :: #force_inline proc() {
	rl.EndMode2D()
}

get_screen_to_world_2d :: #force_inline proc(position: Vec2, camera: Camera2D) -> Vec2 {
	return rl.GetScreenToWorld2D(position, camera)
}

get_world_to_screen_2d :: #force_inline proc(position: Vec2, camera: Camera2D) -> Vec2 {
	return rl.GetWorldToScreen2D(position, camera)
}

begin_drawing :: proc() {
	rl.BeginDrawing()
}

end_drawing :: proc() {
	rl.EndDrawing()
}

clear_background :: proc(colour := BLACK) {
	rl.ClearBackground(colour)
}
