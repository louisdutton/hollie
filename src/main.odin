package hollie

import rl "vendor:raylib"

SCREEN_WIDTH :: 800
SCREEN_HEIGHT :: 450

GameScreen :: enum {
	UNKNOWN = -1,
	TITLE = 0,
	OPTIONS,
	GAMEPLAY,
	ENDING,
}

// Global state
game_state := struct {
	screen:            GameScreen,
	font:              rl.Font,
	music:             rl.Music,
	fx_coin:           rl.Sound,

	// Transition state
	trans_alpha:       f32,
	is_transitioning:  bool,
	trans_has_fade:    bool,
	trans_from_screen: GameScreen,
	trans_to_screen:   GameScreen,
} {
	screen            = .GAMEPLAY,
	trans_alpha       = 0.0,
	is_transitioning  = false,
	trans_has_fade    = false,
	trans_from_screen = .UNKNOWN,
	trans_to_screen   = .UNKNOWN,
}

main :: proc() {
	init_game()
	defer dispose_game()

	for !rl.WindowShouldClose() {
		update_game()
		draw_game()
	}
}

init_game :: proc() {
	rl.InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "hollie")
	rl.InitAudioDevice()
	rl.SetTargetFPS(60)

	// Load global assets
	game_state.font = rl.LoadFont("resources/mecha.png")
	game_state.music = rl.LoadMusicStream("resources/ambient.ogg")
	game_state.fx_coin = rl.LoadSound("resources/coin.wav")

	rl.SetMusicVolume(game_state.music, 1.0)
	rl.PlayMusicStream(game_state.music)

	// Initialize first screen
	switch game_state.screen {
	case .GAMEPLAY:
		init_gameplay_screen()
	case .TITLE:
		init_title_screen()
	case .OPTIONS:
		init_options_screen()
	case .ENDING:
		init_ending_screen()
	case .UNKNOWN:
	// Do nothing
	}
}

dispose_game :: proc() {
	// Unload current screen
	switch game_state.screen {
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

	// Unload global assets
	rl.UnloadFont(game_state.font)
	rl.UnloadMusicStream(game_state.music)
	rl.UnloadSound(game_state.fx_coin)

	rl.CloseAudioDevice()
	rl.CloseWindow()
}

change_to_screen :: proc(screen: GameScreen) {
	// Unload current screen
	switch game_state.screen {
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

	game_state.screen = screen
}

transition_to_screen :: proc(screen: GameScreen) {
	game_state.is_transitioning = true
	game_state.trans_has_fade = false
	game_state.trans_from_screen = game_state.screen
	game_state.trans_to_screen = screen
	game_state.trans_alpha = 0.0
}

update_transition :: proc() {
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

			game_state.screen = game_state.trans_to_screen
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

draw_transition :: proc() {
	rl.DrawRectangle(
		0,
		0,
		rl.GetScreenWidth(),
		rl.GetScreenHeight(),
		rl.Fade(rl.BLACK, game_state.trans_alpha),
	)
}

update_game :: proc() {
	rl.UpdateMusicStream(game_state.music)

	if !game_state.is_transitioning {
		switch game_state.screen {
		case .TITLE:
			update_title_screen()
			if finish_title_screen() {
				transition_to_screen(.GAMEPLAY)
			}
		case .OPTIONS:
			update_options_screen()
			if finish_options_screen() {
				transition_to_screen(.TITLE)
			}
		case .GAMEPLAY:
			update_gameplay_screen()
			if finish_gameplay_screen() == 1 {
				transition_to_screen(.ENDING)
			}
		case .ENDING:
			update_ending_screen()
			if finish_ending_screen() == 1 {
				transition_to_screen(.TITLE)
			}
		case .UNKNOWN:
		// Do nothing
		}
	} else {
		update_transition()
	}
}

draw_game :: proc() {
	rl.BeginDrawing()
	defer rl.EndDrawing()

	rl.ClearBackground(rl.SKYBLUE)

	switch game_state.screen {
	case .TITLE:
		draw_title_screen()
	case .OPTIONS:
		draw_options_screen()
	case .GAMEPLAY:
		draw_gameplay_screen()
	case .ENDING:
		draw_ending_screen()
	case .UNKNOWN:
	// Do nothing
	}

	if game_state.is_transitioning {
		draw_transition()
	}

	rl.DrawFPS(10, 10)
}
