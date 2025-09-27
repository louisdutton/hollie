package hollie

import "audio"

Scene :: enum {
	TITLE = 0,
	GAMEPLAY,
}

set_scene :: proc(screen: Scene) {
	// Unload current screen
	switch game.scene {
	case .TITLE:
		unload_title_screen()
	case .GAMEPLAY:
		unload_gameplay_screen()
	}

	// Init next screen
	switch screen {
	case .TITLE:
		audio.music_play(game.music)
		init_title_screen()
	case .GAMEPLAY:
		audio.music_stop(game.music)
		init_gameplay_screen()
	}

	game.scene = screen
}
