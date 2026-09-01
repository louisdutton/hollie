package hollie

import "asset"
import "audio"
import "input"
import "renderer"
import "tween"
import rl "vendor:raylib"
import "window"

Vec2 :: renderer.Vec2

// Global state
design_width: i32
design_height: i32

App_State :: enum {
	ACTIVE,
	SUSPENDED,
	EXITING,
}

Game_State :: struct {
	state:        App_State,
	scene:        Scene,
	player_count: int,
	font:         renderer.Font,
	music:        audio.Music,
	sounds:       audio.Sound_Map,
}

game: Game_State = {
	state        = .ACTIVE,
	scene        = .TITLE,
	player_count = 1,
}

main :: proc() {
	init()
	defer fini()

	for game.state != .EXITING {
		update()
		draw()
	}
}

init :: proc() {
	window.init(800, 450, "hollie")
	tween.init()

	design_width = window.get_design_width()
	design_height = window.get_design_height()
	ui_assets_init()

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
	defer tween.destroy()
	switch game.scene {
	case .TITLE: unload_title_screen()
	case .GAMEPLAY: unload_gameplay_screen()
	}

	renderer.unload_font(game.font)
	audio.music_fini(game.music)

	audio.fini()
	ui_assets_fini()
	window.fini()
}

update :: proc() {
	if update_app_suspension() do return

	if input.is_key_pressed(.BACKSPACE) {
		game.state = .EXITING
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

// Handle external interruptions before any scene, menu, editor, tween, or
// gameplay update can consume input.
update_app_suspension :: proc() -> bool {
	if !rl.IsWindowFocused() {
		game.state = .SUSPENDED
		return true
	}

	if game.state == .SUSPENDED {
		game.state = .ACTIVE
		// Consume the first focused frame so stale input cannot reach the scene.
		return true
	}

	return false
}

draw :: proc() {
	renderer.begin_drawing()
	defer renderer.end_drawing()

	renderer.clear_background()
	if game.state == .SUSPENDED do return

	switch game.scene {
	case .TITLE: draw_title_screen()
	case .GAMEPLAY: draw_gameplay_screen()
	}

	renderer.draw_fps(10, 10)
}
