package hollie

import "audio"
import "core:fmt"
import "core:os"
import "core:path/filepath"
import "renderer"
import "tween"
import "window"

Vec2 :: renderer.Vec2

/// Returns the full path to an asset file
asset_path :: proc(relative_path: string) -> string {
	return filepath.join({asset_base_path, relative_path})
}

// Global state
design_width: i32
design_height: i32
asset_base_path := os.get_env("RES_ROOT")

game_state := struct {
	scene:  Scene,
	font:   renderer.Font,
	music:  audio.Music,
	sounds: audio.Sound_Map,
} {
	scene = .GAMEPLAY,
}

main :: proc() {
	init()
	defer fini()

	for !window.should_close() {
		update()
		draw()
	}
}

init :: proc() {
	window.init(800, 450, "hollie")

	design_width = window.get_design_width()
	design_height = window.get_design_height()

	audio.init()

	game_state.font = renderer.load_font(asset_path("font/mecha.png"))
	game_state.music = audio.music_init(asset_path("audio/music/ambient.ogg"))

	game_state.sounds = make(audio.Sound_Map)
	game_state.sounds["grunt_roll"] = audio.sound_init(
		{
			asset_path("audio/fx/voices/grunting/female/meghan-christian/grunting_1_meghan.wav"),
			asset_path("audio/fx/voices/grunting/female/meghan-christian/grunting_2_meghan.wav"),
		},
	)
	game_state.sounds["grunt_attack"] = audio.sound_init(
		{
			asset_path("audio/fx/combat/whoosh-short-light.wav"),
			asset_path("audio/fx/impact/whoosh-arm-swing-01-wide.wav"),
		},
	)
	game_state.sounds["attack_hit"] = audio.sound_init(
		{
			asset_path("audio/fx/impact/punch-percussive-heavy-08.wav"),
			asset_path("audio/fx/impact/punch-percussive-heavy-09.wav"),
		},
	)
	game_state.sounds["enemy_hit"] = audio.sound_init(
		{asset_path("audio/fx/impact/punch-squelch-heavy-05.wav")},
	)
	game_state.sounds["enemy_death"] = audio.sound_init(
		{asset_path("audio/fx/impact/waterplosion.wav")},
	)

	audio.music_set_volume(game_state.music, 1.0)
	audio.music_play(game_state.music)

	// Initialize first screen
	switch game_state.scene {
	case .GAMEPLAY:
		audio.music_stop(game_state.music)
		init_gameplay_screen()
	case .TITLE:
		init_title_screen()
	// Do nothing
	}
}

fini :: proc() {
	// Unload current screen
	switch game_state.scene {
	case .TITLE:
		unload_title_screen()
	case .GAMEPLAY:
		unload_gameplay_screen()
	}

	// Unload global assets
	renderer.unload_font(game_state.font)
	audio.music_fini(game_state.music)

	// Cleanup sounds map
	for _, &sound in game_state.sounds {
		audio.sound_fini(&sound)
	}
	delete(game_state.sounds)

	audio.fini()
	window.fini()
}

update :: proc() {
	// Update design dimensions if window was resized
	if window.is_resized() {
		design_width = window.get_design_width()
		design_height = window.get_design_height()
	}

	dt := window.get_frame_time()
	tween.update(dt)

	switch game_state.scene {
	case .TITLE:
		audio.music_update(game_state.music)
		update_title_screen()
	case .GAMEPLAY:
		update_gameplay_screen()
	}
}

draw :: proc() {
	renderer.begin_drawing()
	defer renderer.end_drawing()

	renderer.clear_background()

	switch game_state.scene {
	case .TITLE:
		draw_title_screen()
	case .GAMEPLAY:
		draw_gameplay_screen()
	}

	renderer.draw_fps(10, 10)
}
