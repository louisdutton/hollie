#+feature dynamic-literals
package hollie

import "renderer"
import rl "vendor:raylib"

Title_Menu_State :: enum {
	MAIN,
	OPTIONS,
	AUDIO,
	VISUAL,
	CONTROLS,
}

TITLE_MAIN_MENU_ITEMS := [?]string{"1 Player", "2 Players", "Options", "Exit Game"}

@(private = "file")
title_state := struct {
	menu_state: Title_Menu_State,
	focus:      UI_Focus,
} {
	menu_state = .MAIN,
}

init_title_screen :: proc() {
	title_set_menu(.MAIN)
}

unload_title_screen :: proc() {}

update_title_screen :: proc() {
	navigation := ui_focus_update(
		&title_state.focus,
		title_menu_item_count(title_state.menu_state),
		rl.GetFrameTime(),
	)
	title_handle_input(navigation)
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
	ui_menu_action_bar(title_state.menu_state == .AUDIO || title_state.menu_state == .VISUAL)
}

title_handle_input :: proc(navigation: UI_Navigation) {
	if navigation.back {
		switch title_state.menu_state {
		case .MAIN: game.state = .EXITING
		case .OPTIONS: title_set_menu(.MAIN)
		case .AUDIO, .VISUAL, .CONTROLS: title_set_menu(.OPTIONS)
		}
		return
	}

	if navigation.adjust != 0 do title_adjust_selected(navigation.adjust)
	if navigation.confirm do title_activate_selected_item()
}

title_draw_main_menu :: proc() {
	ui_menu_panel("MAIN MENU", TITLE_MAIN_MENU_ITEMS[:], title_state.focus)
}

title_draw_options_menu :: proc() {
	ui_menu_panel("OPTIONS", MENU_OPTIONS_ITEMS[:], title_state.focus)
}

title_draw_audio_menu :: proc() {
	menu_draw_audio_options(title_state.focus)
}

title_draw_visual_menu :: proc() {
	menu_draw_visual_options(title_state.focus)
}

title_draw_controls_menu :: proc() {
	menu_draw_controls(title_state.focus)
}

title_set_menu :: proc(menu_state: Title_Menu_State) {
	title_state.menu_state = menu_state
	ui_focus_reset(&title_state.focus)
}

title_menu_item_count :: proc(menu_state: Title_Menu_State) -> int {
	switch menu_state {
	case .MAIN: return len(TITLE_MAIN_MENU_ITEMS)
	case .OPTIONS: return len(MENU_OPTIONS_ITEMS)
	case .AUDIO, .VISUAL: return 4
	case .CONTROLS: return 1
	}
	return 0
}

title_adjust_selected :: proc(direction: int) {
	switch title_state.menu_state {
	case .AUDIO: menu_adjust_audio(title_state.focus.index, direction, false)
	case .VISUAL: if title_state.focus.index == 1 do menu_cycle_resolution(direction)
	case .MAIN, .OPTIONS, .CONTROLS:
	}
}

title_activate_selected_item :: proc() {
	switch title_state.menu_state {
	case .MAIN: switch title_state.focus.index {
			case 0:
				game.player_count = 1
				set_scene(.GAMEPLAY)
			case 1:
				game.player_count = 2
				set_scene(.GAMEPLAY)
			case 2: title_set_menu(.OPTIONS)
			case 3: game.state = .EXITING
			}
	case .OPTIONS: switch title_state.focus.index {
			case 0: title_set_menu(.AUDIO)
			case 1: title_set_menu(.VISUAL)
			case 2: title_set_menu(.CONTROLS)
			case 3: title_set_menu(.MAIN)
			}
	case .AUDIO: if title_state.focus.index == 3 {
				title_set_menu(.OPTIONS)
			}
	case .VISUAL: if title_state.focus.index == 3 {
				title_set_menu(.OPTIONS)
			} else {
				menu_activate_visual_option(title_state.focus.index)
			}
	case .CONTROLS: title_set_menu(.OPTIONS)
	}
}
