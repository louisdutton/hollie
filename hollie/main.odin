package hollie

import "asset"
import "audio"
import "input"
import "renderer"
import "tween"
import "window"

Vec2 :: renderer.Vec2

// Global state
design_width: i32
design_height: i32

Game_State :: struct {
	scene:   Scene,
	font:    renderer.Font,
	music:   audio.Music,
	sounds:  audio.Sound_Map,
	running: bool,
}

game: Game_State = {
	scene   = .GAMEPLAY,
	running = true,
}

main :: proc() {
	init()
	defer fini()

	for game.running {
		update()
		draw()
	}
}

init :: proc() {
	window.init(800, 450, "hollie")

	design_width = window.get_design_width()
	design_height = window.get_design_height()

	audio.init()

	game.font = renderer.load_font(asset.path("font/mecha.png"))
	game.music = audio.music_init(asset.path("audio/music/ambient.ogg"))
	game.sounds = audio.sound_init()
	audio.music_set_volume(game.music, audio.get_effective_music_volume())
	audio.music_play(game.music)

	// Initialize first screen
	switch game.scene {
	case .GAMEPLAY:
		audio.music_stop(game.music)
		init_gameplay_screen()
	case .TITLE: init_title_screen()
	}
}

fini :: proc() {
	switch game.scene {
	case .TITLE: unload_title_screen()
	case .GAMEPLAY: unload_gameplay_screen()
	}

	renderer.unload_font(game.font)
	audio.music_fini(game.music)

	audio.fini()
	window.fini()
}

update :: proc() {
	if input.is_key_pressed(.BACKSPACE) {
		game.running = false
	}

	if window.is_resized() {
		design_width = window.get_design_width()
		design_height = window.get_design_height()
	}

	dt := window.get_frame_time()
	tween.update(dt)

	switch game.scene {
	case .TITLE:
		audio.music_update(game.music)
		update_title_screen()
	case .GAMEPLAY: update_gameplay_screen()
	}
}

draw :: proc() {
	renderer.begin_drawing()
	defer renderer.end_drawing()

	renderer.clear_background()

	switch game.scene {
	case .TITLE: draw_title_screen()
	case .GAMEPLAY: draw_gameplay_screen()
	}

	renderer.draw_fps(10, 10)
}
