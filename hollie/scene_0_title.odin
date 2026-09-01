#+feature dynamic-literals
package hollie

import "audio"
import "input"
import "renderer"
import rl "vendor:raylib"

Title_Menu_State :: enum {
	MAIN,
	OPTIONS,
	AUDIO,
	VISUAL,
	CONTROLS,
}

@(private = "file")
title_state := struct {
	menu_state:        Title_Menu_State,
	selected_index:    int,
	menu_item_counts:  map[Title_Menu_State]int,
	gamepad_nav_timer: f32,
} {
	menu_state = .MAIN,
	selected_index = 0,
	gamepad_nav_timer = 0.0,
	menu_item_counts = {
		.MAIN     = 4, // 1 Player, 2 Players, Options, Exit Game
		.OPTIONS  = 4, // Audio, Visual, Controls, Back
		.AUDIO    = 4, // Master Volume, Music Volume, SFX Volume, Back
		.VISUAL   = 4, // Fullscreen, resolution, VSync, Back
		.CONTROLS = 1, // Back
	},
}

init_title_screen :: proc() {
	title_state.menu_state = .MAIN
	title_state.selected_index = 0
}

unload_title_screen :: proc() {}

update_title_screen :: proc() {
	title_handle_input()
	title_update(rl.GetFrameTime())
}

draw_title_screen :: proc() {
	ui_begin()
	defer ui_end()

	renderer.draw_rect_i(0, 0, design_width, design_height, renderer.GREEN)

	pos := Vec2{20, 10}
	renderer.draw_text_ex(
		game.font,
		"Hollie",
		pos,
		f32(game.font.baseSize) * 3.0,
		4,
		renderer.WHITE,
	)

	switch title_state.menu_state {
	case .MAIN: title_draw_main_menu()
	case .OPTIONS: title_draw_options_menu()
	case .AUDIO: title_draw_audio_menu()
	case .VISUAL: title_draw_visual_menu()
	case .CONTROLS: title_draw_controls_menu()
	}
}

title_handle_input :: proc() {
	// Handle escape key to go back
	if input.is_key_pressed(.ESCAPE) ||
	   input.is_gamepad_button_pressed(.PLAYER_1, .RIGHT_FACE_DOWN) {
		switch title_state.menu_state {
		case .MAIN: // Exit game on escape from main menu
				game.state = .EXITING
		case .OPTIONS, .AUDIO, .VISUAL, .CONTROLS:
			title_state.menu_state = .MAIN
			title_state.selected_index = 0
		}
	}

	// Handle gamepad navigation
	if input.is_gamepad_available(.PLAYER_1) {
		// Navigate up/down with D-pad or left stick
		menu_count := title_state.menu_item_counts[title_state.menu_state]

		if input.is_gamepad_button_pressed(.PLAYER_1, .LEFT_FACE_UP) ||
		   (input.get_gamepad_axis_movement(.PLAYER_1, .LEFT_Y) < -0.5 &&
				   title_gamepad_can_navigate()) {
			title_state.selected_index = (title_state.selected_index - 1 + menu_count) % menu_count
			title_reset_navigation_timer()
		}

		if input.is_gamepad_button_pressed(.PLAYER_1, .LEFT_FACE_DOWN) ||
		   (input.get_gamepad_axis_movement(.PLAYER_1, .LEFT_Y) > 0.5 &&
				   title_gamepad_can_navigate()) {
			title_state.selected_index = (title_state.selected_index + 1) % menu_count
			title_reset_navigation_timer()
		}

		if input.is_gamepad_button_pressed(.PLAYER_1, .LEFT_FACE_LEFT) ||
		   (input.get_gamepad_axis_movement(.PLAYER_1, .LEFT_X) < -0.5 &&
				   title_gamepad_can_navigate()) {
			title_adjust_selected(-1)
			title_reset_navigation_timer()
		}

		if input.is_gamepad_button_pressed(.PLAYER_1, .LEFT_FACE_RIGHT) ||
		   (input.get_gamepad_axis_movement(.PLAYER_1, .LEFT_X) > 0.5 &&
				   title_gamepad_can_navigate()) {
			title_adjust_selected(1)
			title_reset_navigation_timer()
		}

		// Select with A button
		if input.is_gamepad_button_pressed(.PLAYER_1, .RIGHT_FACE_RIGHT) {
			title_activate_selected_item()
		}
	}

	// Also handle keyboard navigation
	if input.is_key_pressed(.UP) || input.is_key_pressed(.W) {
		menu_count := title_state.menu_item_counts[title_state.menu_state]
		title_state.selected_index = (title_state.selected_index - 1 + menu_count) % menu_count
	}

	if input.is_key_pressed(.DOWN) || input.is_key_pressed(.S) {
		menu_count := title_state.menu_item_counts[title_state.menu_state]
		title_state.selected_index = (title_state.selected_index + 1) % menu_count
	}

	if input.is_key_pressed(.LEFT) || input.is_key_pressed(.A) do title_adjust_selected(-1)
	if input.is_key_pressed(.RIGHT) || input.is_key_pressed(.D) do title_adjust_selected(1)

	// Select with Enter or Space
	if input.is_key_pressed(.ENTER) || input.is_key_pressed(.SPACE) {
		title_activate_selected_item()
	}
}

title_draw_main_menu :: proc() {
	design_w := f32(design_width)
	design_h := f32(design_height)

	menu_width: f32 = 300
	menu_height: f32 = 350
	menu_x := (design_w - menu_width) / 2
	menu_y := (design_h - menu_height) / 2

	// Main menu panel
	menu_rect := renderer.Rect{menu_x, menu_y, menu_width, menu_height}
	ui_panel(menu_rect, "MAIN MENU")

	button_width: f32 = 200
	button_height: f32 = 40
	button_x := menu_x + (menu_width - button_width) / 2
	start_y := menu_y + 60

	// Game mode buttons
	one_player_rect := renderer.Rect{button_x, start_y, button_width, button_height}
	ui_button(one_player_rect, "1 Player", title_state.selected_index == 0)

	two_player_rect := renderer.Rect{button_x, start_y + 60, button_width, button_height}
	ui_button(two_player_rect, "2 Players", title_state.selected_index == 1)

	// Options button
	options_rect := renderer.Rect{button_x, start_y + 120, button_width, button_height}
	ui_button(options_rect, "Options", title_state.selected_index == 2)

	// Exit Game button
	exit_rect := renderer.Rect{button_x, start_y + 180, button_width, button_height}
	ui_button(exit_rect, "Exit Game", title_state.selected_index == 3)
}

title_draw_options_menu :: proc() {
	design_w := f32(design_width)
	design_h := f32(design_height)

	menu_width: f32 = 300
	menu_height: f32 = 350
	menu_x := (design_w - menu_width) / 2
	menu_y := (design_h - menu_height) / 2

	// Options menu panel
	menu_rect := renderer.Rect{menu_x, menu_y, menu_width, menu_height}
	ui_panel(menu_rect, "OPTIONS")

	button_width: f32 = 200
	button_height: f32 = 40
	button_x := menu_x + (menu_width - button_width) / 2
	start_y := menu_y + 60

	// Audio options button
	audio_rect := renderer.Rect{button_x, start_y, button_width, button_height}
	ui_button(audio_rect, "Audio", title_state.selected_index == 0)

	// Visual options button
	visual_rect := renderer.Rect{button_x, start_y + 60, button_width, button_height}
	ui_button(visual_rect, "Visual", title_state.selected_index == 1)

	// Controls options button
	controls_rect := renderer.Rect{button_x, start_y + 120, button_width, button_height}
	ui_button(controls_rect, "Controls", title_state.selected_index == 2)

	// Back button
	back_rect := renderer.Rect{button_x, start_y + 200, button_width, button_height}
	ui_button(back_rect, "Back", title_state.selected_index == 3)
}

title_draw_audio_menu :: proc() {
	design_w := f32(design_width)
	design_h := f32(design_height)

	menu_width: f32 = 350
	menu_height: f32 = 280
	menu_x := (design_w - menu_width) / 2
	menu_y := (design_h - menu_height) / 2

	menu_rect := renderer.Rect{menu_x, menu_y, menu_width, menu_height}
	ui_panel(menu_rect, "AUDIO OPTIONS")

	slider_width: f32 = 200
	slider_height: f32 = 20
	slider_x := menu_x + 20
	start_y := menu_y + 60

	// Master volume slider
	master_volume := audio.get_master_volume()
	master_rect := renderer.Rect{slider_x, start_y, slider_width, slider_height}
	ui_slider(
		master_rect,
		"Master Volume:",
		master_volume,
		0.0,
		1.0,
		title_state.selected_index == 0,
	)

	// Music volume slider
	music_volume := audio.get_music_volume()
	music_rect := renderer.Rect{slider_x, start_y + 60, slider_width, slider_height}
	ui_slider(music_rect, "Music Volume:", music_volume, 0.0, 1.0, title_state.selected_index == 1)

	// SFX volume slider
	sfx_volume := audio.get_sfx_volume()
	sfx_rect := renderer.Rect{slider_x, start_y + 120, slider_width, slider_height}
	ui_slider(sfx_rect, "SFX Volume:", sfx_volume, 0.0, 1.0, title_state.selected_index == 2)

	// Back button
	button_width: f32 = 100
	button_height: f32 = 30
	back_rect := renderer.Rect{menu_x + 20, menu_y + menu_height - 50, button_width, button_height}
	ui_button(back_rect, "Back", title_state.selected_index == 3)
}

title_draw_visual_menu :: proc() {
	menu_draw_visual_options(title_state.selected_index)
}

title_draw_controls_menu :: proc() {
	menu_draw_controls(title_state.selected_index)
}

title_gamepad_can_navigate :: proc() -> bool {
	return title_state.gamepad_nav_timer <= 0.0
}

title_reset_navigation_timer :: proc() {
	title_state.gamepad_nav_timer = 0.2 // 200ms delay between analog stick navigation
}

title_update :: proc(delta_time: f32) {
	if title_state.gamepad_nav_timer > 0.0 {
		title_state.gamepad_nav_timer -= delta_time
	}
}

title_adjust_selected :: proc(direction: int) {
	switch title_state.menu_state {
	case .AUDIO: menu_adjust_audio(title_state.selected_index, direction, false)
	case .VISUAL: if title_state.selected_index == 1 do menu_cycle_resolution(direction)
	case .MAIN, .OPTIONS, .CONTROLS:
	}
}

title_activate_selected_item :: proc() {
	switch title_state.menu_state {
	case .MAIN: switch title_state.selected_index {
			case 0:
				game.player_count = 1
				set_scene(.GAMEPLAY)
			case 1:
				game.player_count = 2
				set_scene(.GAMEPLAY)
			case 2:
				title_state.menu_state = .OPTIONS
				title_state.selected_index = 0
			case 3: game.state = .EXITING
			}
	case .OPTIONS: switch title_state.selected_index {
			case 0:
				title_state.menu_state = .AUDIO
				title_state.selected_index = 0
			case 1:
				title_state.menu_state = .VISUAL
				title_state.selected_index = 0
			case 2:
				title_state.menu_state = .CONTROLS
				title_state.selected_index = 0
			case 3:
				title_state.menu_state = .MAIN
				title_state.selected_index = 0
			}
	case .AUDIO: if title_state.selected_index == 3 {
				title_state.menu_state = .OPTIONS
				title_state.selected_index = 0
			}
	case .VISUAL: if title_state.selected_index == 3 {
				title_state.menu_state = .OPTIONS
				title_state.selected_index = 0
			} else {
				menu_activate_visual_option(title_state.selected_index)
			}
	case .CONTROLS:
		title_state.menu_state = .OPTIONS
		title_state.selected_index = 0
	}
}
