package hollie

import rl "vendor:raylib"

Scene :: enum {
	UNKNOWN = -1,
	TITLE = 0,
	OPTIONS,
	GAMEPLAY,
	ENDING,
}

set_scene :: proc(screen: Scene) {
	// Unload current screen
	switch game_state.scene {
	case .TITLE:
		unload_title_screen()
	case .OPTIONS:
		unload_options_screen()
	case .GAMEPLAY:
		unload_gameplay_screen()
	case .ENDING:
		unload_ending_screen()
	case .UNKNOWN:
	// Do nothing
	}

	// Init next screen
	switch screen {
	case .TITLE:
		music_play(game_state.music)
		init_title_screen()
	case .OPTIONS:
		music_play(game_state.music)
		init_options_screen()
	case .GAMEPLAY:
		music_stop(game_state.music)
		init_gameplay_screen()
	case .ENDING:
		music_play(game_state.music)
		init_ending_screen()
	case .UNKNOWN:
	// Do nothing
	}

	game_state.scene = screen
}
