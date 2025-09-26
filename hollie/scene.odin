package hollie

import "audio"

Scene :: enum {
	TITLE = 0,
	GAMEPLAY,
}

set_scene :: proc(screen: Scene) {
	// Unload current screen
	switch game_state.scene {
	case .TITLE:
		unload_title_screen()
	case .GAMEPLAY:
		unload_gameplay_screen()
	}

	// Init next screen
	switch screen {
	case .TITLE:
		audio.music_play(game_state.music)
		init_title_screen()
	case .GAMEPLAY:
		audio.music_stop(game_state.music)
		init_gameplay_screen()
	}

	game_state.scene = screen
}
