package hollie

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
	scene:        Scene,
	font:         rl.Font,
	music:        Music,
	grunt_roll:      Sound_Collection,
	grunt_attack:    Sound_Collection,
	attack_hit:      Sound_Collection,
	enemy_hit:       Sound_Collection,
	enemy_death:     Sound,
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
	rl.SetWindowState({.WINDOW_RESIZABLE})
	rl.InitWindow(DESIGN_WIDTH, DESIGN_HEIGHT, "hollie")
	audio_init()
	rl.SetTargetFPS(60)

	// Load global assets
	game_state.font = rl.LoadFont("res/font/mecha.png")
	game_state.music = music_load("res/audio/music/ambient.ogg")

	// Load grunt sounds - using first few Meghan Christian grunts for roll and attack
	roll_grunt_paths := []string {
		"res/audio/fx/voices/grunting/female/meghan-christian/grunting_1_meghan.wav",
		"res/audio/fx/voices/grunting/female/meghan-christian/grunting_2_meghan.wav",
		"res/audio/fx/voices/grunting/female/meghan-christian/grunting_3_meghan.wav",
	}

	attack_grunt_paths := []string {
		"res/audio/fx/voices/grunting/female/meghan-christian/grunting_4_meghan.wav",
		"res/audio/fx/voices/grunting/female/meghan-christian/grunting_5_meghan.wav",
		"res/audio/fx/voices/grunting/female/meghan-christian/grunting_6_meghan.wav",
	}

	game_state.grunt_roll = sound_collection_create(roll_grunt_paths)
	game_state.grunt_attack = sound_collection_create(attack_grunt_paths)

	// Load attack collision/hit sounds
	attack_hit_paths := []string {
		"res/audio/fx/impact/punch-clean-heavy-10.wav",
		"res/audio/fx/impact/punch-designed-heavy-23.wav",
		"res/audio/fx/impact/punch-designed-heavy-74.wav",
		"res/audio/fx/impact/hit-short-04.wav",
	}

	// Load enemy hit sounds (damage/pain sounds)
	enemy_hit_paths := []string {
		"res/audio/fx/voices/damage/female/Meghan Christian/damage_1_meghan.wav",
		"res/audio/fx/voices/damage/female/Meghan Christian/damage_2_meghan.wav",
		"res/audio/fx/voices/damage/female/Meghan Christian/damage_3_meghan.wav",
	}

	game_state.attack_hit = sound_collection_create(attack_hit_paths)
	game_state.enemy_hit = sound_collection_create(enemy_hit_paths)

	// Load enemy death sound
	game_state.enemy_death = sound_load("res/audio/fx/impact/waterplosion.wav")

	music_set_volume(game_state.music, 1.0)
	music_play(game_state.music)

	// Initialize first screen
	switch game_state.scene {
	case .GAMEPLAY:
		music_stop(game_state.music)
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
	music_unload(game_state.music)
	sound_collection_destroy(&game_state.grunt_roll)
	sound_collection_destroy(&game_state.grunt_attack)
	sound_collection_destroy(&game_state.attack_hit)
	sound_collection_destroy(&game_state.enemy_hit)
	sound_unload(game_state.enemy_death)

	audio_close()
	rl.CloseWindow()
}

update :: proc() {
	dt := rl.GetFrameTime()
	tween.update(dt)

	switch game_state.scene {
	case .TITLE:
		music_update(game_state.music)
		update_title_screen()
	case .OPTIONS:
		music_update(game_state.music)
		update_options_screen()
	case .GAMEPLAY:
		update_gameplay_screen()
	case .ENDING:
		music_update(game_state.music)
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
