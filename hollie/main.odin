package hollie

import "tween"
import rl "vendor:raylib"

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
	scene:   Scene,
	font:    rl.Font,
	music:   rl.Music,
	fx_coin: rl.Sound,
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
	rl.InitAudioDevice()
	rl.SetTargetFPS(60)

	// Load global assets
	game_state.font = rl.LoadFont("res/font/mecha.png")
	game_state.music = rl.LoadMusicStream("res/audio/music/ambient.ogg")
	game_state.fx_coin = rl.LoadSound("res/audio/fx/coin.wav")

	rl.SetMusicVolume(game_state.music, 1.0)
	rl.PlayMusicStream(game_state.music)

	// Initialize first screen
	switch game_state.scene {
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
	rl.UnloadMusicStream(game_state.music)
	rl.UnloadSound(game_state.fx_coin)

	rl.CloseAudioDevice()
	rl.CloseWindow()
}

update :: proc() {
	dt := rl.GetFrameTime()
	tween.update(dt)
	rl.UpdateMusicStream(game_state.music)

	switch game_state.scene {
	case .TITLE:
		update_title_screen()
	case .OPTIONS:
		update_options_screen()
	case .GAMEPLAY:
		update_gameplay_screen()
	case .ENDING:
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
