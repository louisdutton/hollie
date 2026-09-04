package hollie

import "audio"

Scene :: enum {
	Title = 0,
	Gameplay,
}

set_scene :: proc(screen: Scene) {
	// Unload current screen
	switch game.scene {
	case .Title: unload_title_screen()
	case .Gameplay: gameplay_fini()
	}

	// Init next screen
	switch screen {
	case .Title:
		audio.music_play(game.music)
		init_title_screen()
	case .Gameplay:
		audio.music_stop(game.music)
		gameplay_init()
	}

	game.scene = screen
}
