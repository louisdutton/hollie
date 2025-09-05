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
	enemy_init()
	player_init()
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
		enemy_update()
		player_update()
		update_camera()
		update_dialog()
	}
}

draw_gameplay_screen :: proc() {
	rl.BeginMode2D(camera)

	tilemap.draw(camera)
	enemy_draw()
	player_draw()
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
	enemy_fini()
	player_fini()
	tilemap.fini()
}

finish_gameplay_screen :: proc() -> int {
	return 0
}
