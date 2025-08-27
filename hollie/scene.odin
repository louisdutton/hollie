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
		init_title_screen()
	case .OPTIONS:
		init_options_screen()
	case .GAMEPLAY:
		init_gameplay_screen()
	case .ENDING:
		init_ending_screen()
	case .UNKNOWN:
	// Do nothing
	}

	game_state.scene = screen
}

transition_to_scene :: proc(screen: Scene) {
	game_state.is_transitioning = true
	game_state.trans_has_fade = false
	game_state.trans_from_screen = game_state.scene
	game_state.trans_to_screen = screen
	game_state.trans_alpha = 0.0
}

update_scene_transition :: proc() {
	if !game_state.trans_has_fade {
		game_state.trans_alpha += 0.05

		if game_state.trans_alpha > 1.01 {
			game_state.trans_alpha = 1.0

			// Unload current screen
			switch game_state.trans_from_screen {
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

			// Load next screen
			switch game_state.trans_to_screen {
			case .TITLE:
				init_title_screen()
			case .OPTIONS:
				init_options_screen()
			case .GAMEPLAY:
				init_gameplay_screen()
			case .ENDING:
				init_ending_screen()
			case .UNKNOWN:
			// Do nothing
			}

			game_state.scene = game_state.trans_to_screen
			game_state.trans_has_fade = true
		}
	} else {
		game_state.trans_alpha -= 0.02

		if game_state.trans_alpha < -0.01 {
			game_state.trans_alpha = 0.0
			game_state.trans_has_fade = false
			game_state.is_transitioning = false
			game_state.trans_from_screen = .UNKNOWN
			game_state.trans_to_screen = .UNKNOWN
		}
	}
}

draw_scene_transition :: proc() {
	rl.DrawRectangle(
		0,
		0,
		rl.GetScreenWidth(),
		rl.GetScreenHeight(),
		rl.Fade(rl.BLACK, game_state.trans_alpha),
	)
}
