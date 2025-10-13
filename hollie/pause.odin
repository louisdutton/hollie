#+feature dynamic-literals
package hollie

import "audio"
import "core:fmt"
import "gui"
import "input"
import "renderer"
import "window"

Pause_Menu_State :: enum {
	HIDDEN,
	MAIN,
	OPTIONS,
	AUDIO,
	VISUAL,
	CONTROLS,
}

@(private = "file")
pause_state := struct {
	menu_state:        Pause_Menu_State,
	selected_index:    int,
	menu_item_counts:  map[Pause_Menu_State]int,
	gamepad_nav_timer: f32,
} {
	menu_state = .HIDDEN,
	selected_index = 0,
	gamepad_nav_timer = 0.0,
	menu_item_counts = {
		.MAIN     = 4, // Resume, Options, Return to Menu, Quit
		.OPTIONS  = 4, // Audio, Visual, Controls, Back
		.AUDIO    = 4, // Master Volume, Music Volume, SFX Volume, Back
		.VISUAL   = 1, // Back (non-interactive elements don't count for navigation)
		.CONTROLS = 1, // Back
	},
}

// Check if the game is currently paused
pause_is_active :: proc() -> bool {
	return pause_state.menu_state != .HIDDEN
}

// Toggle pause state
pause_toggle :: proc() {
	if pause_is_active() {
		pause_close()
	} else {
		pause_open()
	}
}

// Open the pause menu
pause_open :: proc() {
	pause_state.menu_state = .MAIN
	pause_state.selected_index = 0
	audio.music_set_volume(game.music, audio.get_effective_music_volume() * 0.2)
}

// Close the pause menu
pause_close :: proc() {
	pause_state.menu_state = .HIDDEN
	audio.music_set_volume(game.music, audio.get_effective_music_volume())
}

// Handle pause menu input and navigation
pause_handle_input :: proc() {
	if !pause_is_active() do return

	// Handle escape key to go back or close menu
	if input.is_key_pressed(.ESCAPE) ||
	   input.is_gamepad_button_pressed(input.PLAYER_1, .RIGHT_FACE_DOWN) {
		switch pause_state.menu_state {
		case .MAIN: pause_close()
		case .OPTIONS, .AUDIO, .VISUAL, .CONTROLS:
			pause_state.menu_state = .MAIN
			pause_state.selected_index = 0
		case .HIDDEN:
		// Do nothing
		}
	}

	// Handle gamepad navigation
	if input.is_gamepad_available(input.PLAYER_1) {
		// Navigate up/down with D-pad or left stick
		menu_count := pause_state.menu_item_counts[pause_state.menu_state]

		if input.is_gamepad_button_pressed(input.PLAYER_1, .LEFT_FACE_UP) ||
		   (input.get_gamepad_axis_movement(input.PLAYER_1, .LEFT_Y) < -0.5 &&
				   pause_gamepad_can_navigate()) {
			pause_state.selected_index = (pause_state.selected_index - 1 + menu_count) % menu_count
			pause_reset_navigation_timer()
		}

		if input.is_gamepad_button_pressed(input.PLAYER_1, .LEFT_FACE_DOWN) ||
		   (input.get_gamepad_axis_movement(input.PLAYER_1, .LEFT_Y) > 0.5 &&
				   pause_gamepad_can_navigate()) {
			pause_state.selected_index = (pause_state.selected_index + 1) % menu_count
			pause_reset_navigation_timer()
		}

		// Select with A button
		if input.is_gamepad_button_pressed(input.PLAYER_1, .RIGHT_FACE_RIGHT) {
			pause_activate_selected_item()
		}
	}

	// Also handle keyboard navigation
	if input.is_key_pressed(.UP) || input.is_key_pressed(.W) {
		menu_count := pause_state.menu_item_counts[pause_state.menu_state]
		pause_state.selected_index = (pause_state.selected_index - 1 + menu_count) % menu_count
	}

	if input.is_key_pressed(.DOWN) || input.is_key_pressed(.S) {
		menu_count := pause_state.menu_item_counts[pause_state.menu_state]
		pause_state.selected_index = (pause_state.selected_index + 1) % menu_count
	}

	// Select with Enter or Space
	if input.is_key_pressed(.ENTER) || input.is_key_pressed(.SPACE) {
		pause_activate_selected_item()
	}
}

// Draw the pause menu based on current state
pause_draw :: proc() {
	if !pause_is_active() do return

	// Draw semi-transparent background
	renderer.draw_rect_i(0, 0, design_width, design_height, renderer.fade(renderer.BLACK, 0.75))

	gui.begin()
	defer gui.end()

	switch pause_state.menu_state {
	case .MAIN: pause_draw_main_menu()
	case .OPTIONS: pause_draw_options_menu()
	case .AUDIO: pause_draw_audio_menu()
	case .VISUAL: pause_draw_visual_menu()
	case .CONTROLS: pause_draw_controls_menu()
	case .HIDDEN:
	// Do nothing
	}
}

// Draw the main pause menu
pause_draw_main_menu :: proc() {
	design_w := f32(design_width)
	design_h := f32(design_height)

	menu_width: f32 = 300
	menu_height: f32 = 350
	menu_x := (design_w - menu_width) / 2
	menu_y := (design_h - menu_height) / 2

	// Main menu panel
	menu_rect := renderer.Rect{menu_x, menu_y, menu_width, menu_height}
	gui.panel(menu_rect, "PAUSED")

	button_width: f32 = 200
	button_height: f32 = 40
	button_x := menu_x + (menu_width - button_width) / 2
	start_y := menu_y + 60

	// Resume button
	resume_rect := renderer.Rect{button_x, start_y, button_width, button_height}
	if gui.button(resume_rect, "Resume", pause_state.selected_index == 0) {
		pause_close()
	}

	// Options button
	options_rect := renderer.Rect{button_x, start_y + 60, button_width, button_height}
	if gui.button(options_rect, "Options", pause_state.selected_index == 1) {
		pause_state.menu_state = .OPTIONS
		pause_state.selected_index = 0
	}

	// Return to Menu button
	menu_button_rect := renderer.Rect{button_x, start_y + 120, button_width, button_height}
	if gui.button(menu_button_rect, "Return to Menu", pause_state.selected_index == 2) {
		set_scene(.TITLE)
	}

	// Quit button
	quit_rect := renderer.Rect{button_x, start_y + 180, button_width, button_height}
	if gui.button(quit_rect, "Quit Game", pause_state.selected_index == 3) {
		pause_quit_game()
	}
}

// Draw the options submenu
pause_draw_options_menu :: proc() {
	design_w := f32(design_width)
	design_h := f32(design_height)

	menu_width: f32 = 300
	menu_height: f32 = 350
	menu_x := (design_w - menu_width) / 2
	menu_y := (design_h - menu_height) / 2

	// Options menu panel
	menu_rect := renderer.Rect{menu_x, menu_y, menu_width, menu_height}
	gui.panel(menu_rect, "OPTIONS")

	button_width: f32 = 200
	button_height: f32 = 40
	button_x := menu_x + (menu_width - button_width) / 2
	start_y := menu_y + 60

	// Audio options button
	audio_rect := renderer.Rect{button_x, start_y, button_width, button_height}
	if gui.button(audio_rect, "Audio", pause_state.selected_index == 0) {
		pause_state.menu_state = .AUDIO
		pause_state.selected_index = 0
	}

	// Visual options button
	visual_rect := renderer.Rect{button_x, start_y + 60, button_width, button_height}
	if gui.button(visual_rect, "Visual", pause_state.selected_index == 1) {
		pause_state.menu_state = .VISUAL
		pause_state.selected_index = 0
	}

	// Controls options button
	controls_rect := renderer.Rect{button_x, start_y + 120, button_width, button_height}
	if gui.button(controls_rect, "Controls", pause_state.selected_index == 2) {
		pause_state.menu_state = .CONTROLS
		pause_state.selected_index = 0
	}

	// Back button
	back_rect := renderer.Rect{button_x, start_y + 200, button_width, button_height}
	if gui.button(back_rect, "Back", pause_state.selected_index == 3) {
		pause_state.menu_state = .MAIN
		pause_state.selected_index = 0
	}
}

// Audio options menu with volume controls
pause_draw_audio_menu :: proc() {
	design_w := f32(design_width)
	design_h := f32(design_height)

	menu_width: f32 = 350
	menu_height: f32 = 280
	menu_x := (design_w - menu_width) / 2
	menu_y := (design_h - menu_height) / 2

	menu_rect := renderer.Rect{menu_x, menu_y, menu_width, menu_height}
	gui.panel(menu_rect, "AUDIO OPTIONS")

	slider_width: f32 = 200
	slider_height: f32 = 20
	slider_x := menu_x + 20
	start_y := menu_y + 60

	// Master volume slider
	master_volume := audio.get_master_volume()
	master_rect := renderer.Rect{slider_x, start_y, slider_width, slider_height}
	if gui.slider(master_rect, "Master Volume:", &master_volume, 0.0, 1.0) {
		audio.set_master_volume(master_volume)
		// Update currently playing music
		if !pause_is_active() {
			audio.music_set_volume(game.music, audio.get_effective_music_volume())
		} else {
			audio.music_set_volume(game.music, audio.get_effective_music_volume() * 0.2)
		}
	}

	// Music volume slider
	music_volume := audio.get_music_volume()
	music_rect := renderer.Rect{slider_x, start_y + 60, slider_width, slider_height}
	if gui.slider(music_rect, "Music Volume:", &music_volume, 0.0, 1.0) {
		audio.set_music_volume(music_volume)
		// Update currently playing music
		if !pause_is_active() {
			audio.music_set_volume(game.music, audio.get_effective_music_volume())
		} else {
			audio.music_set_volume(game.music, audio.get_effective_music_volume() * 0.2)
		}
	}

	// SFX volume slider
	sfx_volume := audio.get_sfx_volume()
	sfx_rect := renderer.Rect{slider_x, start_y + 120, slider_width, slider_height}
	if gui.slider(sfx_rect, "SFX Volume:", &sfx_volume, 0.0, 1.0) {
		audio.set_sfx_volume(sfx_volume)
	}

	// Back button
	button_width: f32 = 100
	button_height: f32 = 30
	back_rect := renderer.Rect{menu_x + 20, menu_y + menu_height - 50, button_width, button_height}
	if gui.button(back_rect, "Back", pause_state.selected_index == 3) {
		pause_state.menu_state = .OPTIONS
		pause_state.selected_index = 0
	}
}

// Visual options menu with display settings
pause_draw_visual_menu :: proc() {
	design_w := f32(design_width)
	design_h := f32(design_height)

	menu_width: f32 = 400
	menu_height: f32 = 350
	menu_x := (design_w - menu_width) / 2
	menu_y := (design_h - menu_height) / 2

	menu_rect := renderer.Rect{menu_x, menu_y, menu_width, menu_height}
	gui.panel(menu_rect, "VISUAL OPTIONS")

	button_width: f32 = 150
	button_height: f32 = 30
	option_x := menu_x + 20
	start_y := menu_y + 60

	// Fullscreen toggle
	fullscreen_rect := renderer.Rect{option_x, start_y, button_width, button_height}
	fullscreen_text := window.is_fullscreen() ? "Fullscreen: ON" : "Fullscreen: OFF"
	if gui.button(fullscreen_rect, fullscreen_text) {
		window.toggle_fullscreen()
	}

	// Resolution buttons (only available in windowed mode)
	if !window.is_fullscreen() {
		gui.label(renderer.Rect{option_x, start_y + 50, 200, 20}, "Resolution:")

		resolutions := window.get_available_resolutions()
		current_width, current_height := window.get_window_size()

		y_offset := start_y + 80
		for resolution in resolutions {
			res_rect := renderer.Rect{option_x, y_offset, button_width + 50, 25}

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
	vsync_rect := renderer.Rect{option_x, vsync_y, button_width, button_height}
	vsync_text := window.is_vsync_enabled() ? "VSync: ON" : "VSync: OFF"
	if gui.button(vsync_rect, vsync_text) {
		window.toggle_vsync()
	}

	// Back button
	back_rect := renderer.Rect{menu_x + 20, menu_y + menu_height - 50, 100, 30}
	if gui.button(back_rect, "Back", pause_state.selected_index == 0) {
		pause_state.menu_state = .OPTIONS
		pause_state.selected_index = 0
	}
}

// Controls menu showing current key bindings
pause_draw_controls_menu :: proc() {
	design_w := f32(design_width)
	design_h := f32(design_height)

	menu_width: f32 = 400
	menu_height: f32 = 450
	menu_x := (design_w - menu_width) / 2
	menu_y := (design_h - menu_height) / 2

	menu_rect := renderer.Rect{menu_x, menu_y, menu_width, menu_height}
	gui.panel(menu_rect, "CONTROLS")

	start_y := menu_y + 60
	label_x := menu_x + 20
	key_x := menu_x + 180

	// Display current key bindings
	bindings := input.get_key_bindings()
	for binding, i in bindings {
		y_pos := start_y + f32(i) * 30

		// Action name
		name_rect := renderer.Rect{label_x, y_pos, 150, 25}
		gui.label(name_rect, fmt.tprintf("%s:", binding.name))

		// Key name
		key_name := input.get_key_name(binding.key^)
		key_rect := renderer.Rect{key_x, y_pos, 100, 25}
		gui.label(key_rect, key_name)

		// Don't overflow the menu
		if y_pos > menu_y + menu_height - 100 do break
	}

	// Instructions
	info_y := menu_y + menu_height - 80
	info_rect := renderer.Rect{menu_x + 20, info_y, menu_width - 40, 20}
	gui.label(info_rect, "Key remapping coming soon!")

	// Back button
	back_rect := renderer.Rect{menu_x + 20, menu_y + menu_height - 50, 100, 30}
	if gui.button(back_rect, "Back", pause_state.selected_index == 0) {
		pause_state.menu_state = .OPTIONS
		pause_state.selected_index = 0
	}
}

// Helper functions for gamepad navigation timing
pause_gamepad_can_navigate :: proc() -> bool {
	return pause_state.gamepad_nav_timer <= 0.0
}

pause_reset_navigation_timer :: proc() {
	pause_state.gamepad_nav_timer = 0.2 // 200ms delay between analog stick navigation
}

// Update gamepad navigation timer
pause_update :: proc(delta_time: f32) {
	if pause_state.gamepad_nav_timer > 0.0 {
		pause_state.gamepad_nav_timer -= delta_time
	}
}

// Activate the currently selected menu item
pause_activate_selected_item :: proc() {
	switch pause_state.menu_state {
	case .MAIN: switch pause_state.selected_index {
			case 0: pause_close()
			case 1:
				pause_state.menu_state = .OPTIONS
				pause_state.selected_index = 0
			case 2: set_scene(.TITLE)
			case 3: pause_quit_game()
			}
	case .OPTIONS: switch pause_state.selected_index {
			case 0:
				pause_state.menu_state = .AUDIO
				pause_state.selected_index = 0
			case 1:
				pause_state.menu_state = .VISUAL
				pause_state.selected_index = 0
			case 2:
				pause_state.menu_state = .CONTROLS
				pause_state.selected_index = 0
			case 3:
				pause_state.menu_state = .MAIN
				pause_state.selected_index = 0
			}
	case .AUDIO, .VISUAL, .CONTROLS:
		// For these menus, the only selectable item is Back
		pause_state.menu_state = .OPTIONS
		pause_state.selected_index = 0
	case .HIDDEN:
	// Do nothing
	}
}

// Quit the game
pause_quit_game :: proc() {
	game.running = false
}
