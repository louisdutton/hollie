package hollie

import "audio"
import "tween"
import rl "vendor:raylib"

Vec2 :: rl.Vector2

DESIGN_WIDTH :: 800
DESIGN_HEIGHT :: 450

get_screen_scale :: proc() -> f32 {
	screen_width := f32(rl.GetScreenWidth())
	screen_height := f32(rl.GetScreenHeight())

	scale_x := screen_width / DESIGN_WIDTH
	scale_y := screen_height / DESIGN_HEIGHT

	// Use the smaller scale to maintain aspect ratio
	return min(scale_x, scale_y)
}

// Global state
game_state := struct {
	scene:  Scene,
	font:   rl.Font,
	music:  audio.Music,
	sounds: audio.Sound_Map,
} {
	scene = .GAMEPLAY,
}

main :: proc() {
	init()
	defer fini()

	for !rl.WindowShouldClose() {
		update()
		draw()
	}
}

init :: proc() {
	rl.SetTraceLogLevel(.WARNING)
	rl.SetWindowState({.WINDOW_RESIZABLE})
	rl.InitWindow(DESIGN_WIDTH, DESIGN_HEIGHT, "hollie")
	audio.init()
	rl.SetTargetFPS(60)

	// Load global assets
	game_state.font = rl.LoadFont("res/font/mecha.png")
	game_state.music = audio.music_init("res/audio/music/ambient.ogg")

	// Initialize sound map
	game_state.sounds = make(audio.Sound_Map)

	// Load sounds into the map
	game_state.sounds["grunt_roll"] = audio.sound_init(
		{
			"res/audio/fx/voices/grunting/female/meghan-christian/grunting_1_meghan.wav",
			"res/audio/fx/voices/grunting/female/meghan-christian/grunting_2_meghan.wav",
		},
	)
	game_state.sounds["grunt_attack"] = audio.sound_init(
		{
			"res/audio/fx/combat/whoosh-short-light.wav",
			"res/audio/fx/impact/whoosh-arm-swing-01-wide.wav",
		},
	)
	game_state.sounds["attack_hit"] = audio.sound_init(
		{
			"res/audio/fx/impact/punch-percussive-heavy-08.wav",
			"res/audio/fx/impact/punch-percussive-heavy-09.wav",
		},
	)
	game_state.sounds["enemy_hit"] = audio.sound_init(
		{"res/audio/fx/impact/punch-squelch-heavy-05.wav"},
	)
	game_state.sounds["enemy_death"] = audio.sound_init({"res/audio/fx/impact/waterplosion.wav"})

	audio.music_set_volume(game_state.music, 1.0)
	audio.music_play(game_state.music)

	// Initialize first screen
	switch game_state.scene {
	case .GAMEPLAY:
		audio.music_stop(game_state.music)
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

fini :: proc() {
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

	// Unload global assets
	rl.UnloadFont(game_state.font)
	audio.music_fini(game_state.music)

	// Cleanup sounds map
	for key, &sound in game_state.sounds {
		audio.sound_fini(&sound)
	}
	delete(game_state.sounds)

	audio.fini()
	rl.CloseWindow()
}

update :: proc() {
	dt := rl.GetFrameTime()
	tween.update(dt)

	switch game_state.scene {
	case .TITLE:
		audio.music_update(game_state.music)
		update_title_screen()
	case .OPTIONS:
		audio.music_update(game_state.music)
		update_options_screen()
	case .GAMEPLAY:
		update_gameplay_screen()
	case .ENDING:
		audio.music_update(game_state.music)
		update_ending_screen()
	case .UNKNOWN:
	// Do nothing
	}
}

draw :: proc() {
	rl.BeginDrawing()
	defer rl.EndDrawing()

	rl.ClearBackground(rl.SKYBLUE)

	switch game_state.scene {
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

	rl.DrawFPS(10, 10)
}
