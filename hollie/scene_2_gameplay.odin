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
	init_dialog()
	tilemap.init()
}

update_gameplay_screen :: proc() {
	if rl.IsKeyPressed(.P) {
		if gameplay_state.is_paused {
			gameplay_state.is_paused = false
			rl.SetMusicVolume(game_state.music, 1)
		} else {
			gameplay_state.is_paused = true
			rl.SetMusicVolume(game_state.music, 0.2)
		}
	}

	if !gameplay_state.is_paused {
		update_player()
		update_camera()
		update_dialog()
	}
}

draw_gameplay_screen :: proc() {
	rl.BeginMode2D(camera)

	tilemap.draw(camera)
	draw_player()
	rl.EndMode2D()

	// ui
	draw_dialog()

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
