package hollie

import "audio"

Scene :: enum {
	TITLE = 0,
	GAMEPLAY,
}

set_scene :: proc(screen: Scene) {
	// Unload current screen
	switch game.scene {
	case .TITLE: unload_title_screen()
	case .GAMEPLAY: gameplay_fini()
	}

	// Init next screen
	switch screen {
	case .TITLE:
		audio.music_play(game.music)
		init_title_screen()
	case .GAMEPLAY:
		audio.music_stop(game.music)
		gameplay_init()
	}

	game.scene = screen
}
