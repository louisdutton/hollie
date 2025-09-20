package hollie

import "tilemap"
import rl "vendor:raylib"

// Gameplay Screen
@(private = "file")
gameplay_state := struct {
	is_paused:  bool,
	test_level: LevelResource,
} {
	is_paused = false,
}

init_gameplay_screen :: proc() {
	init_camera()
	dialog_init()

	gameplay_state.test_level = level_new()
	level_init(&gameplay_state.test_level)
}

// FIXME: putting this in stack memory causes uaf in dialog
test_messages := []Dialog_Message {
	{text = "Hi there Hollie! It's me, Basil!", speaker = "Basil"},
	{text = "Greetings Basil.", speaker = "Hollie"},
	{text = "Good luck on your journey.", speaker = "Basil"},
	{text = "Thanks!", speaker = "Hollie"},
}

update_gameplay_screen :: proc() {
	if rl.IsKeyPressed(.P) || rl.IsGamepadButtonPressed(PLAYER_1, .MIDDLE_RIGHT) {
		if gameplay_state.is_paused {
			gameplay_state.is_paused = false
			music_set_volume(game_state.music, 1)
		} else {
			gameplay_state.is_paused = true
			music_set_volume(game_state.music, 0.2)
		}
	}

	if rl.IsKeyPressed(.R) {
		level_reload()
	}

	if rl.IsKeyPressed(.T) && !dialog_is_active() {
		dialog_start(test_messages)
	}

	if !gameplay_state.is_paused {
		level_update()
		enemy_update()
		player_update()
		update_camera()
		dialog_update()
	}
}

draw_gameplay_screen :: proc() {
	rl.BeginMode2D(camera)

	tilemap.draw(camera)
	enemy_draw()
	player_draw()
	rl.EndMode2D()

	// ui
	dialog_draw()

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
	level_fini()
}

finish_gameplay_screen :: proc() -> int {
	return 0
}
