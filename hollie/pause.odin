#+feature dynamic-literals
package hollie

import "audio"
import "core:fmt"
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

PAUSE_MAIN_MENU_ITEMS := [?]string{"Resume", "Options", "Return to Menu", "Quit Game"}
MENU_OPTIONS_ITEMS := [?]string{"Audio", "Visual", "Controls", "Back"}

@(private = "file")
pause_state := struct {
	menu_state: Pause_Menu_State,
	focus:      UI_Focus,
} {
	menu_state = .HIDDEN,
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
	pause_set_menu(.MAIN)
	audio.music_set_volume(game.music, audio.get_effective_music_volume() * 0.2)
}

// Close the pause menu
pause_close :: proc() {
	pause_state.menu_state = .HIDDEN
	audio.music_set_volume(game.music, audio.get_effective_music_volume())
}

// Handle pause menu input and navigation
pause_handle_input :: proc(delta_time: f32) {
	if !pause_is_active() do return

	navigation := ui_focus_update(
		&pause_state.focus,
		pause_menu_item_count(pause_state.menu_state),
		delta_time,
	)
	if navigation.back {
		switch pause_state.menu_state {
		case .MAIN: pause_close()
		case .OPTIONS: pause_set_menu(.MAIN)
		case .AUDIO, .VISUAL, .CONTROLS: pause_set_menu(.OPTIONS)
		case .HIDDEN:
		}
		return
	}

	if navigation.adjust != 0 do pause_adjust_selected(navigation.adjust)
	if navigation.confirm do pause_activate_selected_item()
}

// Draw the pause menu based on current state
pause_draw :: proc() {
	if !pause_is_active() do return

	// Draw semi-transparent background
	renderer.draw_rect_i(0, 0, design_width, design_height, renderer.fade(renderer.BLACK, 0.75))

	switch pause_state.menu_state {
	case .MAIN: pause_draw_main_menu()
	case .OPTIONS: pause_draw_options_menu()
	case .AUDIO: pause_draw_audio_menu()
	case .VISUAL: pause_draw_visual_menu()
	case .CONTROLS: pause_draw_controls_menu()
	case .HIDDEN:
	// Do nothing
	}
	ui_menu_action_bar(pause_state.menu_state == .AUDIO || pause_state.menu_state == .VISUAL)
}

// Draw the main pause menu
pause_draw_main_menu :: proc() {
	ui_menu_panel("PAUSED", PAUSE_MAIN_MENU_ITEMS[:], pause_state.focus)
}

// Draw the options submenu
pause_draw_options_menu :: proc() {
	ui_menu_panel("OPTIONS", MENU_OPTIONS_ITEMS[:], pause_state.focus)
}

// Audio options menu with volume controls
pause_draw_audio_menu :: proc() {
	menu_draw_audio_options(pause_state.focus)
}

menu_draw_audio_options :: proc(focus: UI_Focus) {
	menu_width: f32 = 350
	menu_height: f32 = 280
	menu_rect := ui_centered_rect(menu_width, menu_height)
	menu_x, menu_y := menu_rect.x, menu_rect.y
	ui_begin_panel("AUDIO OPTIONS", menu_rect)

	slider_width: f32 = 200
	slider_height: f32 = 20
	slider_x := menu_x + 20
	start_y := menu_y + 60
	ui_begin_layout(.Column, {slider_x, start_y, slider_width, 180}, 15)

	master_volume := audio.get_master_volume()
	master_row := ui_next_rect(slider_width, 45)
	master_rect := renderer.Rect{master_row.x, master_row.y, slider_width, slider_height}
	ui_slider(master_rect, "Master Volume:", master_volume, 0.0, 1.0, focus.index == 0)

	music_volume := audio.get_music_volume()
	music_row := ui_next_rect(slider_width, 45)
	music_rect := renderer.Rect{music_row.x, music_row.y, slider_width, slider_height}
	ui_slider(music_rect, "Music Volume:", music_volume, 0.0, 1.0, focus.index == 1)

	sfx_volume := audio.get_sfx_volume()
	sfx_row := ui_next_rect(slider_width, 45)
	sfx_rect := renderer.Rect{sfx_row.x, sfx_row.y, slider_width, slider_height}
	ui_slider(sfx_rect, "SFX Volume:", sfx_volume, 0.0, 1.0, focus.index == 2)
	ui_end_layout()

	button_width: f32 = 100
	button_height: f32 = 30
	back_rect := renderer.Rect{menu_x + 20, menu_y + menu_height - 50, button_width, button_height}
	ui_button(back_rect, "Back", focus.index == 3)
	ui_end_panel()
}

// Visual options menu with display settings
pause_draw_visual_menu :: proc() {
	menu_draw_visual_options(pause_state.focus)
}

menu_draw_visual_options :: proc(focus: UI_Focus) {
	fullscreen_text := window.is_fullscreen() ? "Fullscreen: ON" : "Fullscreen: OFF"
	current_width, current_height := window.get_window_size()
	resolution_text := fmt.tprintf("Resolution: %dx%d", current_width, current_height)
	vsync_text := window.is_vsync_enabled() ? "VSync: ON" : "VSync: OFF"
	items := [?]string{fullscreen_text, resolution_text, vsync_text, "Back"}
	ui_menu_panel("VISUAL OPTIONS", items[:], focus)
}

// Controls menu showing current key bindings
pause_draw_controls_menu :: proc() {
	menu_draw_controls(pause_state.focus)
}

menu_draw_controls :: proc(focus: UI_Focus) {
	menu_width: f32 = 400
	menu_height: f32 = 350
	menu_rect := ui_centered_rect(menu_width, menu_height)
	menu_x, menu_y := menu_rect.x, menu_rect.y
	ui_begin_panel("CONTROLS", menu_rect)

	start_y := menu_y + 45
	ui_begin_layout(.Column, {menu_x + 20, start_y, menu_width - 40, 210}, 3)

	// Display current key bindings
	bindings := input.get_key_bindings()
	for binding, i in bindings {
		row_rect := ui_next_rect(menu_width - 40, 20)
		ui_begin_layout(.Row, row_rect, 10)
		name_rect := ui_next_rect(150, 20)
		ui_label(name_rect, fmt.tprintf("%s:", binding.name))

		key_name := input.get_key_name(binding.key^)
		key_rect := ui_next_rect(120, 20)
		ui_keycap(key_rect, key_name)
		ui_end_layout()

		if i >= 8 do break
	}
	ui_end_layout()

	// Instructions
	info_y := menu_y + menu_height - 70
	info_rect := renderer.Rect{menu_x + 20, info_y, menu_width - 40, 20}
	ui_label(info_rect, "Key remapping coming soon!")

	// Back button
	back_rect := renderer.Rect{menu_x + 20, menu_y + menu_height - 45, 100, 30}
	ui_button(back_rect, "Back", focus.index == 0)
	ui_end_panel()
}

menu_adjust_audio :: proc(selected_index, direction: int, paused: bool) {
	delta := f32(direction) * 0.05
	switch selected_index {
	case 0: audio.set_master_volume(audio.get_master_volume() + delta)
	case 1: audio.set_music_volume(audio.get_music_volume() + delta)
	case 2: audio.set_sfx_volume(audio.get_sfx_volume() + delta)
	case 3:
	}

	if selected_index == 0 || selected_index == 1 {
		music_volume := audio.get_effective_music_volume()
		if paused do music_volume *= 0.2
		audio.music_set_volume(game.music, music_volume)
	}
}

menu_activate_visual_option :: proc(selected_index: int) {
	switch selected_index {
	case 0: window.toggle_fullscreen()
	case 1: menu_cycle_resolution(1)
	case 2: window.toggle_vsync()
	case 3:
	}
}

menu_cycle_resolution :: proc(direction: int) {
	if window.is_fullscreen() do return
	resolutions := window.get_available_resolutions()
	if len(resolutions) == 0 do return

	current_width, current_height := window.get_window_size()
	current_index := direction > 0 ? -1 : 0
	for resolution, index in resolutions {
		if resolution.width == current_width && resolution.height == current_height {
			current_index = index
			break
		}
	}

	next_index := (current_index + direction + len(resolutions)) % len(resolutions)
	next := resolutions[next_index]
	window.set_resolution(next.width, next.height)
}

pause_set_menu :: proc(menu_state: Pause_Menu_State) {
	pause_state.menu_state = menu_state
	ui_focus_reset(&pause_state.focus)
}

pause_menu_item_count :: proc(menu_state: Pause_Menu_State) -> int {
	switch menu_state {
	case .HIDDEN: return 0
	case .MAIN: return len(PAUSE_MAIN_MENU_ITEMS)
	case .OPTIONS: return len(MENU_OPTIONS_ITEMS)
	case .AUDIO, .VISUAL: return 4
	case .CONTROLS: return 1
	}
	return 0
}

pause_adjust_selected :: proc(direction: int) {
	switch pause_state.menu_state {
	case .AUDIO: menu_adjust_audio(pause_state.focus.index, direction, true)
	case .VISUAL: if pause_state.focus.index == 1 do menu_cycle_resolution(direction)
	case .HIDDEN, .MAIN, .OPTIONS, .CONTROLS:
	}
}

// Activate the currently selected menu item
pause_activate_selected_item :: proc() {
	switch pause_state.menu_state {
	case .MAIN: switch pause_state.focus.index {
			case 0: pause_close()
			case 1: pause_set_menu(.OPTIONS)
			case 2: set_scene(.TITLE)
			case 3: pause_quit_game()
			}
	case .OPTIONS: switch pause_state.focus.index {
			case 0: pause_set_menu(.AUDIO)
			case 1: pause_set_menu(.VISUAL)
			case 2: pause_set_menu(.CONTROLS)
			case 3: pause_set_menu(.MAIN)
			}
	case .AUDIO: if pause_state.focus.index == 3 {
				pause_set_menu(.OPTIONS)
			}
	case .VISUAL: if pause_state.focus.index == 3 {
				pause_set_menu(.OPTIONS)
			} else {
				menu_activate_visual_option(pause_state.focus.index)
			}
	case .CONTROLS: pause_set_menu(.OPTIONS)
	case .HIDDEN:
	// Do nothing
	}
}

// Quit the game
pause_quit_game :: proc() {
	game.state = .EXITING
}
