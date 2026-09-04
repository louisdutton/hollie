package hollie

import "core:time"
import "core:unicode/utf8"
import "input"
import "renderer"
import "tween"

TIME_PER_CHARACTER :: 0.025 * f32(time.Second)

Dialog_Message :: struct {
	text:    string,
	speaker: string,
}

Dialog_State :: struct {
	messages:         []Dialog_Message,
	current_page:     int,
	message_progress: f32,
	is_active:        bool,
	text_complete:    bool,
	current_runes:    []rune,
}

dialog_state: Dialog_State

dialog_init :: proc() {
	dialog_state = {}
}

dialog_start :: proc(npc: ^Npc) {
	dialog_state.messages = npc.dialog_messages
	dialog_state.current_page = 0
	dialog_state.is_active = len(npc.dialog_messages) > 0
	dialog_state.text_complete = false

	if dialog_state.is_active {
		dialog_set_all_busy(true)
		tween.to(
			&camera_base_zoom,
			ZOOM_DIALOG,
			.Quadratic_Out,
			time.Duration(0.5 * f64(time.Second)),
		)
		_dialog_start_current_message()
	}
}

_dialog_start_current_message :: proc() {
	if dialog_state.current_page >= len(dialog_state.messages) {
		dialog_state.is_active = false
		return
	}

	current_msg := dialog_state.messages[dialog_state.current_page]
	dialog_state.current_runes = utf8.string_to_runes(current_msg.text)
	dialog_state.message_progress = 0.0
	dialog_state.text_complete = false

	text_duration := time.Duration(f32(len(dialog_state.current_runes)) * TIME_PER_CHARACTER)
	tween.to(&dialog_state.message_progress, 1.0, .Linear, text_duration)
}

dialog_advance :: proc() {
	if !dialog_state.is_active {
		return
	}

	if !dialog_state.text_complete {
		dialog_state.message_progress = 1.0
		dialog_state.text_complete = true
		return
	}

	dialog_state.current_page += 1

	if dialog_state.current_page >= len(dialog_state.messages) {
		dialog_state.is_active = false
		dialog_set_all_busy(false)
		tween.to(
			&camera_base_zoom,
			ZOOM_DEFAULT,
			.Quadratic_Out,
			time.Duration(0.5 * f64(time.Second)),
		)
		if len(dialog_state.current_runes) > 0 {
			delete(dialog_state.current_runes)
			dialog_state.current_runes = {}
		}
	} else {
		if len(dialog_state.current_runes) > 0 {
			delete(dialog_state.current_runes)
			dialog_state.current_runes = {}
		}
		_dialog_start_current_message()
	}
}

dialog_update :: proc() {
	if !dialog_state.is_active do return

	if dialog_state.text_complete {
		if input.is_pressed(.Accept) do dialog_advance()
	} else {
		if dialog_state.message_progress >= 1.0 {
			dialog_state.text_complete = true
		}
	}
}

dialog_is_active :: proc() -> bool {
	return dialog_state.is_active
}

// TODO: we should only mark participating NPCs as busy
dialog_set_all_busy :: proc(busy: bool) {
	players := entity_get_players()
	defer delete(players)
	for player in players {
		player.is_busy = busy
	}

	npcs := npc_get_all()
	defer delete(npcs)
	for npc in npcs {
		npc.is_busy = busy
	}
}

dialog_draw :: proc() {
	if !dialog_state.is_active || dialog_state.current_page >= len(dialog_state.messages) {
		return
	}

	MARGIN_X :: 90
	MARGIN_Y :: 18
	PADDING_X :: 24
	PANEL_HEIGHT :: 120
	TEXT_SIZE :: 16

	design_w := f32(design_width)
	design_h := f32(design_height)
	panel_bounds := renderer.Rect {
		f32(MARGIN_X),
		design_h - PANEL_HEIGHT - MARGIN_Y,
		design_w - MARGIN_X * 2,
		PANEL_HEIGHT,
	}
	current_msg := dialog_state.messages[dialog_state.current_page]
	ui_panel(
		panel_bounds,
		current_msg.speaker,
		ui_context.theme.panel_border,
		ui_context.theme.value_text,
	)

	if len(dialog_state.current_runes) > 0 {
		visible_chars := clamp(
			int(dialog_state.message_progress * f32(len(dialog_state.current_runes))),
			0,
			len(dialog_state.current_runes),
		)
		str := utf8.runes_to_string(dialog_state.current_runes[:visible_chars])
		defer delete(str)

		full_text_width := f32(renderer.measure_text(current_msg.text, TEXT_SIZE))
		text_x := max(
			panel_bounds.x + PADDING_X,
			panel_bounds.x + (panel_bounds.width - full_text_width) / 2,
		)
		text_y := panel_bounds.y + (current_msg.speaker != "" ? 48 : 30)
		renderer.draw_text(str, int(text_x), int(text_y), TEXT_SIZE, ui_context.theme.text)
	}

	if dialog_state.text_complete {
		label := dialog_state.current_page >= len(dialog_state.messages) - 1 ? "Close" : "Continue"
		prompt := ui_control_prompt_view(.H, .RIGHT_FACE_RIGHT)
		hint_width := ui_prompt_label_width(prompt, label, 12)
		hint_x := panel_bounds.x + panel_bounds.width - PADDING_X - hint_width
		hint_y := panel_bounds.y + panel_bounds.height - 28
		ui_draw_prompt_label(prompt, label, hint_x, hint_y, 12, ui_context.theme.muted_text)
	}
}
