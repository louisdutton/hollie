package hollie

import "tilemap"
import rl "vendor:raylib"

// Gameplay Screen
@(private = "file")
gameplay_state := struct {
	is_paused: bool,
} {
	is_paused = false,
}

init_gameplay_screen :: proc() {
	init_player()
	init_camera()
	tilemap.init()
}

update_gameplay_screen :: proc() {
	if rl.IsKeyPressed(.P) {
		gameplay_state.is_paused = !gameplay_state.is_paused
	}

	if !gameplay_state.is_paused {
		update_player()
		update_camera()
	}
}

draw_gameplay_screen :: proc() {
	rl.BeginMode2D(camera)

	tilemap.draw(camera)
	draw_player()

	rl.EndMode2D()

	if gameplay_state.is_paused {
		w := rl.GetScreenWidth()
		h := rl.GetRenderHeight()
		rl.DrawRectangle(0, 0, w, h, rl.Fade(rl.BLACK, 0.75))
		tx := w / 2 - 60
		ty := h / 2 - 30
		rl.DrawText("PAUSED", tx, ty, 20, rl.WHITE)
	}
}

unload_gameplay_screen :: proc() {
	unload_player()
	tilemap.fini()
}

finish_gameplay_screen :: proc() -> int {
	return 0
}
