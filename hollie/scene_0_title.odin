#+feature dynamic-literals
package hollie

import "renderer"
import rl "vendor:raylib"

Title_Menu_State :: enum {
	Main,
	Options,
	Audio,
	Visual,
	Controls,
}

TITLE_MAIN_MENU_ITEMS := [?]string{"1 player", "2 players", "Options", "Exit game"}

@(private = "file")
title_state := struct {
	menu_state: Title_Menu_State,
	focus:      UI_Focus,
} {
	menu_state = .Main,
}

init_title_screen :: proc() {
	title_set_menu(.Main)
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

	renderer.draw_rect_i(0, 0, design_width, design_height, renderer.Colour{20, 29, 35, 255})

	pos := Vec2{20, 10}
	renderer.draw_text_ex(game.font, "Hollie", pos, 64, 2, renderer.WHITE)

	switch title_state.menu_state {
	case .Main: title_draw_main_menu()
	case .Options: title_draw_options_menu()
	case .Audio: title_draw_audio_menu()
	case .Visual: title_draw_visual_menu()
	case .Controls: title_draw_controls_menu()
	}
	ui_menu_action_bar(title_state.menu_state == .Audio || title_state.menu_state == .Visual)
}

title_handle_input :: proc(navigation: UI_Navigation) {
	if navigation.back {
		switch title_state.menu_state {
		case .Main: game.state = .Exiting
		case .Options: title_set_menu(.Main)
		case .Audio, .Visual, .Controls: title_set_menu(.Options)
		}
		return
	}

	if navigation.adjust != 0 do title_adjust_selected(navigation.adjust)
	if navigation.confirm do title_activate_selected_item()
}

title_draw_main_menu :: proc() {
	ui_menu_panel("Main menu", TITLE_MAIN_MENU_ITEMS[:], title_state.focus)
}

title_draw_options_menu :: proc() {
	ui_menu_panel("Options", MENU_OPTIONS_ITEMS[:], title_state.focus)
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
	case .Main: return len(TITLE_MAIN_MENU_ITEMS)
	case .Options: return len(MENU_OPTIONS_ITEMS)
	case .Audio, .Visual: return 4
	case .Controls: return 1
	}
	return 0
}

title_adjust_selected :: proc(direction: int) {
	switch title_state.menu_state {
	case .Audio: menu_adjust_audio(title_state.focus.index, direction, false)
	case .Visual: if title_state.focus.index == 1 do menu_cycle_resolution(direction)
	case .Main, .Options, .Controls:
	}
}

title_activate_selected_item :: proc() {
	switch title_state.menu_state {
	case .Main: switch title_state.focus.index {
			case 0:
				game.player_count = 1
				set_scene(.Gameplay)
			case 1:
				game.player_count = 2
				set_scene(.Gameplay)
			case 2: title_set_menu(.Options)
			case 3: game.state = .Exiting
			}
	case .Options: switch title_state.focus.index {
			case 0: title_set_menu(.Audio)
			case 1: title_set_menu(.Visual)
			case 2: title_set_menu(.Controls)
			case 3: title_set_menu(.Main)
			}
	case .Audio: if title_state.focus.index == 3 {
				title_set_menu(.Options)
			}
	case .Visual: if title_state.focus.index == 3 {
				title_set_menu(.Options)
			} else {
				menu_activate_visual_option(title_state.focus.index)
			}
	case .Controls: title_set_menu(.Options)
	}
}
