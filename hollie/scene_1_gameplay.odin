package hollie

import "audio"
import "core:fmt"
import "core:slice"
import "core:time"
import "gui"
import "input"
import "renderer"
import "tilemap"
import "tween"
import "window"

Drawable_Entity :: struct {
	position:    Vec2,
	type:        Character_Type,
	enemy_index: int, // only used for enemies
}

// Draw all characters sorted by y position
// we can potentially avoid double iteration with a custom sort
draw_entities_sorted :: proc() {
	slice.sort_by(characters[:], proc(a, b: Character) -> bool {
		return a.position.y < b.position.y
	})

	for &character in characters {
		character_draw(&character)
	}
}

Pause_Menu_State :: enum {
	HIDDEN,
	MAIN,
	OPTIONS,
	AUDIO,
	VISUAL,
	CONTROLS,
}

// Gameplay Screen
@(private = "file")
gameplay_state := struct {
	is_paused:          bool,
	pause_menu_state:   Pause_Menu_State,
	grass_level:        LevelResource,
	sand_level:         LevelResource,
	current_level:      int, // 0 = grass, 1 = sand
	is_transitioning:   bool,
	transition_opacity: f32,
	pending_level:      int,
	pending_player_pos: Vec2,
} {
	is_paused          = false,
	pause_menu_state   = .HIDDEN,
	current_level      = 0,
	is_transitioning   = false,
	transition_opacity = 0.0,
	pending_level      = -1,
}

init_gameplay_screen :: proc() {
	camera_init()
	dialog_init()
	character_system_init()
	particle_system_init()
	shader_init()
	gui.init()

	gameplay_state.grass_level = level_new()
	gameplay_state.sand_level = level_new_sand()
	level_init(&gameplay_state.grass_level)
}

// FIXME: putting this in stack memory causes uaf in dialog
test_messages := []Dialog_Message {
	{text = "Hi there Hollie! It's me, Basil!", speaker = "Basil"},
	{text = "Greetings Basil.", speaker = "Hollie"},
	{text = "Good luck on your journey.", speaker = "Basil"},
	{text = "Thanks!", speaker = "Hollie"},
}

update_gameplay_screen :: proc() {
	// Handle pause toggle
	if input.is_key_pressed(.P) || input.is_gamepad_button_pressed(input.PLAYER_1, .MIDDLE_RIGHT) {
		if gameplay_state.is_paused {
			gameplay_state.is_paused = false
			gameplay_state.pause_menu_state = .HIDDEN
			audio.music_set_volume(game.music, audio.get_effective_music_volume())
		} else {
			gameplay_state.is_paused = true
			gameplay_state.pause_menu_state = .MAIN
			audio.music_set_volume(game.music, audio.get_effective_music_volume() * 0.2)
		}
	}

	// Handle pause menu navigation
	if gameplay_state.is_paused {
		handle_pause_menu_input()
	}

	if input.is_key_pressed(.R) {
		level_reload()
	}

	if input.is_key_pressed(.T) && !dialog_is_active() {
		dialog_start(test_messages)
	}

	// Check for level transitions based on player position
	current_player := character_get_player()
	if current_player != nil && !gameplay_state.is_transitioning {
		player_pos := current_player.position
		level_width := f32(50 * 16) // 50 tiles * 16 pixels per tile

		// Transition to sand level (right side) - trigger just before camera bounds
		if gameplay_state.current_level == 0 && player_pos.x >= 785 {
			gameplay_state.is_transitioning = true
			gameplay_state.pending_level = 1
			gameplay_state.pending_player_pos = {50, player_pos.y}
			tween.to(
				&gameplay_state.transition_opacity,
				1.0,
				.Quadratic_Out,
				300 * time.Millisecond,
			)
		} else if gameplay_state.current_level == 1 && player_pos.x <= 15 {
			// Transition to grass level (left side) - trigger near left edge
			gameplay_state.is_transitioning = true
			gameplay_state.pending_level = 0
			gameplay_state.pending_player_pos = {level_width - 60, player_pos.y}
			tween.to(
				&gameplay_state.transition_opacity,
				1.0,
				.Quadratic_Out,
				300 * time.Millisecond,
			)
		}
	}

	// Handle transition state - switch level at peak opacity
	if gameplay_state.is_transitioning &&
	   gameplay_state.transition_opacity >= 0.99 &&
	   gameplay_state.pending_level >= 0 {
		gameplay_state.current_level = gameplay_state.pending_level

		// Load appropriate level
		switch gameplay_state.current_level {
		case 0: level_init(&gameplay_state.grass_level)
		case 1: level_init(&gameplay_state.sand_level)
		}

		// Position player
		transition_player := character_get_player()
		if transition_player != nil {
			transition_player.position = gameplay_state.pending_player_pos
		}
		gameplay_state.pending_level = -1

		// Start fade out
		tween.to(&gameplay_state.transition_opacity, 0.0, .Quadratic_In, 300 * time.Millisecond)
		audio.music_play(game.music)
	}

	// End transition when fade out completes
	if gameplay_state.is_transitioning &&
	   gameplay_state.transition_opacity <= 0.01 &&
	   gameplay_state.pending_level < 0 {
		gameplay_state.is_transitioning = false
		gameplay_state.transition_opacity = 0.0
	}

	if !gameplay_state.is_paused {
		level_update()
		character_system_update() // Handles all characters (player, enemies, NPCs)
		particle_system_update()
		camera_update()
		dialog_update()
	}
}

draw_gameplay_screen :: proc() {
	// world
	{
		renderer.begin_mode_2d(camera)
		defer renderer.end_mode_2d()

		tilemap.draw(camera)
		draw_entities_sorted()
		particle_system_draw()
	}

	// ui
	{
		ui_begin()
		defer ui_end()

		level_draw_name()
		dialog_draw()
		draw_transition_overlay()

		if gameplay_state.is_paused {
			draw_pause_menu()
		}
	}
}

unload_gameplay_screen :: proc() {
	shader_fini()
	level_fini()
	character_system_fini()
	particle_system_fini()
}

/// Handle pause menu input and navigation
handle_pause_menu_input :: proc() {
	// Handle escape key to go back or close menu
	if input.is_key_pressed(.ESCAPE) {
		switch gameplay_state.pause_menu_state {
		case .MAIN:
			gameplay_state.is_paused = false
			gameplay_state.pause_menu_state = .HIDDEN
			audio.music_set_volume(game.music, audio.get_effective_music_volume())
		case .OPTIONS, .AUDIO, .VISUAL, .CONTROLS: gameplay_state.pause_menu_state = .MAIN
		case .HIDDEN:
		// Do nothing
		}
	}
}

/// Draw the pause menu based on current state
draw_pause_menu :: proc() {
	// Draw semi-transparent background
	renderer.draw_rect_i(0, 0, design_width, design_height, renderer.fade(renderer.BLACK, 0.75))

	gui.begin()
	defer gui.end()

	switch gameplay_state.pause_menu_state {
	case .MAIN: draw_pause_main_menu()
	case .OPTIONS: draw_pause_options_menu()
	case .AUDIO: draw_pause_audio_menu()
	case .VISUAL: draw_pause_visual_menu()
	case .CONTROLS: draw_pause_controls_menu()
	case .HIDDEN:
	// Do nothing
	}
}

/// Draw the main pause menu
draw_pause_main_menu :: proc() {
	design_w := f32(design_width)
	design_h := f32(design_height)

	menu_width: f32 = 300
	menu_height: f32 = 350
	menu_x := (design_w - menu_width) / 2
	menu_y := (design_h - menu_height) / 2

	// Main menu panel
	menu_rect := renderer.Rectangle{menu_x, menu_y, menu_width, menu_height}
	gui.panel(menu_rect, "PAUSED")

	button_width: f32 = 200
	button_height: f32 = 40
	button_x := menu_x + (menu_width - button_width) / 2
	start_y := menu_y + 60

	// Resume button
	resume_rect := renderer.Rectangle{button_x, start_y, button_width, button_height}
	if gui.button(resume_rect, "Resume") {
		gameplay_state.is_paused = false
		gameplay_state.pause_menu_state = .HIDDEN
		audio.music_set_volume(game.music, audio.get_effective_music_volume())
	}

	// Options button
	options_rect := renderer.Rectangle{button_x, start_y + 60, button_width, button_height}
	if gui.button(options_rect, "Options") {
		gameplay_state.pause_menu_state = .OPTIONS
	}

	// Return to Menu button
	menu_button_rect := renderer.Rectangle{button_x, start_y + 120, button_width, button_height}
	if gui.button(menu_button_rect, "Return to Menu") {
		set_scene(.TITLE)
	}

	// Quit button
	quit_rect := renderer.Rectangle{button_x, start_y + 180, button_width, button_height}
	if gui.button(quit_rect, "Quit Game") {
		// TODO: Add quit confirmation dialog
		quit_game()
	}
}

/// Draw the options submenu
draw_pause_options_menu :: proc() {
	design_w := f32(design_width)
	design_h := f32(design_height)

	menu_width: f32 = 300
	menu_height: f32 = 350
	menu_x := (design_w - menu_width) / 2
	menu_y := (design_h - menu_height) / 2

	// Options menu panel
	menu_rect := renderer.Rectangle{menu_x, menu_y, menu_width, menu_height}
	gui.panel(menu_rect, "OPTIONS")

	button_width: f32 = 200
	button_height: f32 = 40
	button_x := menu_x + (menu_width - button_width) / 2
	start_y := menu_y + 60

	// Audio options button
	audio_rect := renderer.Rectangle{button_x, start_y, button_width, button_height}
	if gui.button(audio_rect, "Audio") {
		gameplay_state.pause_menu_state = .AUDIO
	}

	// Visual options button
	visual_rect := renderer.Rectangle{button_x, start_y + 60, button_width, button_height}
	if gui.button(visual_rect, "Visual") {
		gameplay_state.pause_menu_state = .VISUAL
	}

	// Controls options button
	controls_rect := renderer.Rectangle{button_x, start_y + 120, button_width, button_height}
	if gui.button(controls_rect, "Controls") {
		gameplay_state.pause_menu_state = .CONTROLS
	}

	// Back button
	back_rect := renderer.Rectangle{button_x, start_y + 200, button_width, button_height}
	if gui.button(back_rect, "Back") {
		gameplay_state.pause_menu_state = .MAIN
	}
}

/// Audio options menu with volume controls
draw_pause_audio_menu :: proc() {
	design_w := f32(design_width)
	design_h := f32(design_height)

	menu_width: f32 = 350
	menu_height: f32 = 280
	menu_x := (design_w - menu_width) / 2
	menu_y := (design_h - menu_height) / 2

	menu_rect := renderer.Rectangle{menu_x, menu_y, menu_width, menu_height}
	gui.panel(menu_rect, "AUDIO OPTIONS")

	slider_width: f32 = 200
	slider_height: f32 = 20
	slider_x := menu_x + 20
	start_y := menu_y + 60

	// Master volume slider
	master_volume := audio.get_master_volume()
	master_rect := renderer.Rectangle{slider_x, start_y, slider_width, slider_height}
	if gui.slider(master_rect, "Master Volume:", &master_volume, 0.0, 1.0) {
		audio.set_master_volume(master_volume)
		// Update currently playing music
		if !gameplay_state.is_paused {
			audio.music_set_volume(game.music, audio.get_effective_music_volume())
		} else {
			audio.music_set_volume(game.music, audio.get_effective_music_volume() * 0.2)
		}
	}

	// Music volume slider
	music_volume := audio.get_music_volume()
	music_rect := renderer.Rectangle{slider_x, start_y + 60, slider_width, slider_height}
	if gui.slider(music_rect, "Music Volume:", &music_volume, 0.0, 1.0) {
		audio.set_music_volume(music_volume)
		// Update currently playing music
		if !gameplay_state.is_paused {
			audio.music_set_volume(game.music, audio.get_effective_music_volume())
		} else {
			audio.music_set_volume(game.music, audio.get_effective_music_volume() * 0.2)
		}
	}

	// SFX volume slider
	sfx_volume := audio.get_sfx_volume()
	sfx_rect := renderer.Rectangle{slider_x, start_y + 120, slider_width, slider_height}
	if gui.slider(sfx_rect, "SFX Volume:", &sfx_volume, 0.0, 1.0) {
		audio.set_sfx_volume(sfx_volume)
	}

	// Back button
	button_width: f32 = 100
	button_height: f32 = 30
	back_rect := renderer.Rectangle {
		menu_x + 20,
		menu_y + menu_height - 50,
		button_width,
		button_height,
	}
	if gui.button(back_rect, "Back") {
		gameplay_state.pause_menu_state = .OPTIONS
	}
}

/// Visual options menu with display settings
draw_pause_visual_menu :: proc() {
	design_w := f32(design_width)
	design_h := f32(design_height)

	menu_width: f32 = 400
	menu_height: f32 = 350
	menu_x := (design_w - menu_width) / 2
	menu_y := (design_h - menu_height) / 2

	menu_rect := renderer.Rectangle{menu_x, menu_y, menu_width, menu_height}
	gui.panel(menu_rect, "VISUAL OPTIONS")

	button_width: f32 = 150
	button_height: f32 = 30
	option_x := menu_x + 20
	start_y := menu_y + 60

	// Fullscreen toggle
	fullscreen_rect := renderer.Rectangle{option_x, start_y, button_width, button_height}
	fullscreen_text := window.is_fullscreen() ? "Fullscreen: ON" : "Fullscreen: OFF"
	if gui.button(fullscreen_rect, fullscreen_text) {
		window.toggle_fullscreen()
	}

	// Resolution buttons (only available in windowed mode)
	if !window.is_fullscreen() {
		gui.label(renderer.Rectangle{option_x, start_y + 50, 200, 20}, "Resolution:")

		resolutions := window.get_available_resolutions()
		current_width, current_height := window.get_window_size()

		y_offset := start_y + 80
		for resolution in resolutions {
			res_rect := renderer.Rectangle{option_x, y_offset, button_width + 50, 25}

			// Highlight current resolution
			is_current := resolution.width == current_width && resolution.height == current_height
			text := is_current ? fmt.tprintf("* %s", resolution.name) : resolution.name

			if gui.button(res_rect, text) {
				window.set_resolution(resolution.width, resolution.height)
			}

			y_offset += 30

			// Only show first few resolutions to fit in menu
			if y_offset > menu_y + menu_height - 100 do break
		}
	}

	// VSync toggle
	vsync_y := window.is_fullscreen() ? start_y + 50 : start_y + 200
	vsync_rect := renderer.Rectangle{option_x, vsync_y, button_width, button_height}
	vsync_text := window.is_vsync_enabled() ? "VSync: ON" : "VSync: OFF"
	if gui.button(vsync_rect, vsync_text) {
		window.toggle_vsync()
	}

	// Back button
	back_rect := renderer.Rectangle{menu_x + 20, menu_y + menu_height - 50, 100, 30}
	if gui.button(back_rect, "Back") {
		gameplay_state.pause_menu_state = .OPTIONS
	}
}

/// Controls menu showing current key bindings
draw_pause_controls_menu :: proc() {
	design_w := f32(design_width)
	design_h := f32(design_height)

	menu_width: f32 = 400
	menu_height: f32 = 450
	menu_x := (design_w - menu_width) / 2
	menu_y := (design_h - menu_height) / 2

	menu_rect := renderer.Rectangle{menu_x, menu_y, menu_width, menu_height}
	gui.panel(menu_rect, "CONTROLS")

	start_y := menu_y + 60
	label_x := menu_x + 20
	key_x := menu_x + 180

	// Display current key bindings
	bindings := input.get_key_bindings()
	for binding, i in bindings {
		y_pos := start_y + f32(i) * 30

		// Action name
		name_rect := renderer.Rectangle{label_x, y_pos, 150, 25}
		gui.label(name_rect, fmt.tprintf("%s:", binding.name))

		// Key name
		key_name := input.get_key_name(binding.key^)
		key_rect := renderer.Rectangle{key_x, y_pos, 100, 25}
		gui.label(key_rect, key_name)

		// Don't overflow the menu
		if y_pos > menu_y + menu_height - 100 do break
	}

	// Instructions
	info_y := menu_y + menu_height - 80
	info_rect := renderer.Rectangle{menu_x + 20, info_y, menu_width - 40, 20}
	gui.label(info_rect, "Key remapping coming soon!")

	// Back button
	back_rect := renderer.Rectangle{menu_x + 20, menu_y + menu_height - 50, 100, 30}
	if gui.button(back_rect, "Back") {
		gameplay_state.pause_menu_state = .OPTIONS
	}
}

/// Quit the game
quit_game :: proc() {
	window.fini()
}

draw_transition_overlay :: proc() {
	if gameplay_state.is_transitioning && gameplay_state.transition_opacity > 0.01 {
		alpha := u8(gameplay_state.transition_opacity * 255)
		renderer.draw_rect_i(0, 0, design_width, design_height, renderer.Colour{0, 0, 0, alpha})
	}
}
