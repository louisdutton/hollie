#+feature dynamic-literals
package hollie

import "graphics"
import "input"

Title_Menu_State :: enum {
	Main,
	Options,
	Audio,
	Visual,
	Controls,
}

title_main_menu_items := [?]string{"1 player", "2 players", "Options", "Exit game"}

@(private = "file")
title_state := struct {
	menu_state: Title_Menu_State,
	focus:      Ui_Focus,
} {
	menu_state = .Main,
}

init_title_screen :: proc() {
	title_meadow_init()
	title_set_menu(.Main)
}

unload_title_screen :: proc() {
	title_meadow_fini()
}

update_title_screen :: proc(dt: f32) {
	title_meadow.time += max(dt, 0)
	navigation := ui_focus_update(
		&title_state.focus,
		title_menu_item_count(title_state.menu_state),
		dt,
	)
	title_handle_input(navigation)
}

draw_title_screen :: proc() {
	title_meadow_draw()
	ui_begin()
	defer ui_end()

	graphics.draw_text_ex(game.font, "Hollie", {43, 67}, 72, 2, {34, 58, 49, 110})
	graphics.draw_text_ex(game.font, "Hollie", {40, 64}, 72, 2, {252, 245, 218, 255})

	switch title_state.menu_state {
	case .Main: title_draw_main_menu()
	case .Options: title_draw_options_menu()
	case .Audio: title_draw_audio_menu()
	case .Visual: title_draw_visual_menu()
	case .Controls: title_draw_controls_menu()
	}
	if title_state.menu_state == .Main {
		x: f32 = 40
		for action in ([]input.Action{.Menu_Navigate, .Menu_Confirm, .Menu_Back}) {
			ui_draw_action_hint(action, x, 410, 11, {246, 241, 218, 255})
			x += ui_action_hint_width(action) + 20
		}
	} else {
		ui_menu_action_bar(title_state.menu_state == .Audio || title_state.menu_state == .Visual)
	}
}

title_handle_input :: proc(navigation: Ui_Navigation) {
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
	for item, index in title_main_menu_items {
		y := f32(184 + index * 36)
		selected := index == title_state.focus.index
		color: graphics.Colour = selected ? {255, 246, 211, 255} : {235, 241, 221, 235}
		if selected do graphics.draw_circle(43, y + 10, 3, color)
		graphics.draw_text_ex(game.font, item, {59, y + 2}, 22, 1, {25, 46, 36, 210})
		graphics.draw_text_ex(game.font, item, {57, y}, 22, 1, color)
	}
}

title_draw_options_menu :: proc() {
	ui_menu_panel("Options", menu_options_items[:], title_state.focus)
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
	case .Main: return len(title_main_menu_items)
	case .Options: return len(menu_options_items)
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
				scene_request(&game, .Gameplay)
			case 1:
				game.player_count = 2
				scene_request(&game, .Gameplay)
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
