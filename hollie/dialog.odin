package hollie

import "core:time"
import "core:unicode/utf8"
import "renderer"
import "tween"
import rl "vendor:raylib"

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

dialog_start :: proc(messages: []Dialog_Message) {
	dialog_state.messages = messages
	dialog_state.current_page = 0
	dialog_state.is_active = len(messages) > 0
	dialog_state.text_complete = false

	if dialog_state.is_active {
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

		// unlock dialog target
		// TODO: this is crude, we should have a reference to the target
		for &character in characters {
			if character.state.is_busy {
				character.state.is_busy = false
			}
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
		if input_pressed(.Accept) do dialog_advance()
	} else {
		if dialog_state.message_progress >= 1.0 {
			dialog_state.text_complete = true
		}
	}
}

dialog_is_active :: proc() -> bool {
	return dialog_state.is_active
}

dialog_draw :: proc() {
	if !dialog_state.is_active || dialog_state.current_page >= len(dialog_state.messages) {
		return
	}

	MARGIN_X :: 100
	MARGIN_Y :: 10
	PADDING_X :: 15
	PADDING_Y :: 15
	SPEAKER_OFFSET :: 25

	screen_w := rl.GetScreenWidth()
	screen_h := rl.GetScreenHeight()

	bg_height :: 200
	bg_x := f32(MARGIN_X)
	bg_y := f32(screen_h - bg_height - MARGIN_Y)
	renderer.draw_rect(bg_x, bg_y, f32(screen_w - MARGIN_X * 2), bg_height)
	renderer.draw_rect_outline(bg_x, bg_y, f32(screen_w - MARGIN_X * 2), bg_height)

	current_msg := dialog_state.messages[dialog_state.current_page]

	if current_msg.speaker != "" {
		renderer.draw_text(current_msg.speaker, MARGIN_X + PADDING_X, int(bg_y) + PADDING_Y)
	}

	if len(dialog_state.current_runes) > 0 {
		visible_chars := int(dialog_state.message_progress * f32(len(dialog_state.current_runes)))
		str := utf8.runes_to_string(dialog_state.current_runes[:visible_chars])
		defer delete(str)

		text_y := int(bg_y) + PADDING_Y
		if current_msg.speaker != "" {
			text_y += SPEAKER_OFFSET
		}

		renderer.draw_text(str, MARGIN_X + PADDING_X, text_y)
	}

	if dialog_state.text_complete {
		continue_text := "[continue]"
		if dialog_state.current_page >= len(dialog_state.messages) - 1 {
			continue_text = "[close]"
		}

		text_w := rl.MeasureText(cstring(raw_data(continue_text)), 20)
		continue_x := screen_w - MARGIN_X - PADDING_X - text_w
		continue_y := int(bg_y) + bg_height - PADDING_Y - 20

		renderer.draw_text(continue_text, int(continue_x), continue_y)
	}
}
