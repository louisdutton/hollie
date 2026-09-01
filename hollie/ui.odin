package hollie

import "core:fmt"
import "input"
import "renderer"
import rl "vendor:raylib"
import "window"

UI_Anchor :: enum {
	Top_Left,
	Top_Right,
}

UI_Layout_Direction :: enum {
	Column,
	Row,
}

UI_Focus :: struct {
	index:        int,
	repeat_timer: f32,
}

UI_Navigation :: struct {
	adjust:  int,
	confirm: bool,
	back:    bool,
}

UI_Theme :: struct {
	panel_background: renderer.Colour,
	panel_border:     renderer.Colour,
	text:             renderer.Colour,
	muted_text:       renderer.Colour,
	value_text:       renderer.Colour,
	padding:          f32,
	line_height:      f32,
}

UI_Layout :: struct {
	bounds:    renderer.Rect,
	cursor_x:  f32,
	cursor_y:  f32,
	direction: UI_Layout_Direction,
	gap:       f32,
}

UI_Context :: struct {
	layouts: [8]UI_Layout,
	depth:   int,
	theme:   UI_Theme,
}

@(private)
ui_context := UI_Context {
	theme = {
		panel_background = {0, 0, 0, 210},
		panel_border = {255, 255, 255, 120},
		text = {255, 255, 255, 255},
		muted_text = {165, 165, 165, 255},
		value_text = {165, 210, 255, 255},
		padding = 8,
		line_height = 20,
	},
}

// Ensure ui scale is proportional to window size
ui_begin :: proc() {
	ui_context.depth = 0
	ui_scale := window.get_ui_scale()
	rl.BeginMode2D({zoom = ui_scale})
}

ui_end :: proc() {
	rl.EndMode2D()
}

// Returns the width of the provided text at the provided size.
ui_measure_text :: proc(text: string, size: int) -> int {
	return int(renderer.measure_text(text, i32(size)))
}

ui_anchored_rect :: proc(
	anchor: UI_Anchor,
	width, height: f32,
	margin: f32 = 10,
) -> renderer.Rect {
	switch anchor {
	case .Top_Left: return {margin, margin, width, height}
	case .Top_Right:
		return{f32(window.get_design_width()) - width - margin, margin, width, height}
	}
	return {}
}

ui_centered_rect :: proc(width, height: f32) -> renderer.Rect {
	design_width := f32(window.get_design_width())
	design_height := f32(window.get_design_height())
	return {(design_width - width) / 2, (design_height - height) / 2, width, height}
}

ui_begin_panel :: proc(
	title: string,
	bounds: renderer.Rect,
	border_color := ui_context.theme.panel_border,
) {
	assert(ui_context.depth < len(ui_context.layouts), "UI layout stack overflow")
	ui_panel(bounds, title, border_color)
	padding := ui_context.theme.padding
	ui_context.layouts[ui_context.depth] = {
		bounds    = bounds,
		cursor_x  = bounds.x + padding,
		cursor_y  = bounds.y + padding + ui_context.theme.line_height,
		direction = .Column,
	}
	ui_context.depth += 1
}

ui_end_panel :: proc() {
	assert(ui_context.depth > 0, "UI panel stack underflow")
	ui_context.depth -= 1
}

ui_begin_layout :: proc(direction: UI_Layout_Direction, bounds: renderer.Rect, gap: f32 = 0) {
	assert(ui_context.depth < len(ui_context.layouts), "UI layout stack overflow")
	ui_context.layouts[ui_context.depth] = {
		bounds    = bounds,
		cursor_x  = bounds.x,
		cursor_y  = bounds.y,
		direction = direction,
		gap       = gap,
	}
	ui_context.depth += 1
}

ui_end_layout :: proc() {
	assert(ui_context.depth > 0, "UI layout stack underflow")
	ui_context.depth -= 1
}

ui_next_rect :: proc(width, height: f32) -> renderer.Rect {
	layout := ui_current_layout()
	bounds := renderer.Rect{layout.cursor_x, layout.cursor_y, width, height}
	switch layout.direction {
	case .Column: layout.cursor_y += height + layout.gap
	case .Row: layout.cursor_x += width + layout.gap
	}
	return bounds
}

ui_focus_reset :: proc(focus: ^UI_Focus) {
	focus.index = 0
	focus.repeat_timer = 0
}

ui_focus_update :: proc(focus: ^UI_Focus, item_count: int, delta_time: f32) -> UI_Navigation {
	navigation := UI_Navigation {
		confirm = input.action_pressed(.Menu_Confirm),
		back    = input.action_pressed(.Menu_Back),
	}
	if item_count <= 0 do return navigation

	focus.index = clamp(focus.index, 0, item_count - 1)
	focus.repeat_timer = max(focus.repeat_timer - delta_time, 0)

	vertical := 0
	horizontal := 0
	if input.is_key_pressed(.UP) ||
	   input.is_key_pressed(.W) ||
	   input.is_gamepad_button_pressed(.PLAYER_1, .LEFT_FACE_UP) {
		vertical = -1
	}
	if input.is_key_pressed(.DOWN) ||
	   input.is_key_pressed(.S) ||
	   input.is_gamepad_button_pressed(.PLAYER_1, .LEFT_FACE_DOWN) {
		vertical = 1
	}
	if input.is_key_pressed(.LEFT) ||
	   input.is_key_pressed(.A) ||
	   input.is_gamepad_button_pressed(.PLAYER_1, .LEFT_FACE_LEFT) {
		horizontal = -1
	}
	if input.is_key_pressed(.RIGHT) ||
	   input.is_key_pressed(.D) ||
	   input.is_gamepad_button_pressed(.PLAYER_1, .LEFT_FACE_RIGHT) {
		horizontal = 1
	}

	if focus.repeat_timer <= 0 && input.is_gamepad_available(.PLAYER_1) {
		x := input.get_gamepad_axis_movement(.PLAYER_1, .LEFT_X)
		y := input.get_gamepad_axis_movement(.PLAYER_1, .LEFT_Y)
		if vertical == 0 && abs(y) > 0.5 do vertical = y < 0 ? -1 : 1
		if horizontal == 0 && abs(x) > 0.5 do horizontal = x < 0 ? -1 : 1
	}

	if vertical != 0 {
		focus.index = (focus.index + vertical + item_count) % item_count
		focus.repeat_timer = 0.2
	}
	if horizontal != 0 {
		navigation.adjust = horizontal
		focus.repeat_timer = 0.2
	}
	return navigation
}

ui_text :: proc(text: string, color := ui_context.theme.text, size: int = 13) {
	layout := ui_current_layout()
	renderer.draw_text(
		text,
		int(layout.bounds.x + ui_context.theme.padding),
		int(layout.cursor_y),
		size,
		color,
	)
	layout.cursor_y += ui_context.theme.line_height
}

ui_field :: proc(
	label, value: string,
	actions: []input.Action = {},
	value_color := ui_context.theme.value_text,
) {
	layout := ui_current_layout()
	padding := ui_context.theme.padding
	x := layout.bounds.x + padding
	y := layout.cursor_y
	label_text := fmt.tprintf("%s:", label)
	renderer.draw_text(label_text, int(x), int(y), 13, ui_context.theme.muted_text)
	value_x := x + f32(renderer.measure_text(label_text, 13)) + 7
	renderer.draw_text(value, int(value_x), int(y), 13, value_color)

	right := layout.bounds.x + layout.bounds.width - padding
	hints_width: f32 = 0
	for action in actions {
		hint_width := ui_action_hint_width(action, 10)
		if hint_width == 0 do continue
		hints_width += hint_width + 10
	}

	hint_y := y + 2
	field_height := ui_context.theme.line_height
	value_right := value_x + f32(renderer.measure_text(value, 13))
	if hints_width > 0 && value_right > right - hints_width {
		hint_y += ui_context.theme.line_height
		field_height += ui_context.theme.line_height
	}

	for action_index := len(actions) - 1; action_index >= 0; action_index -= 1 {
		hint_width := ui_action_hint_width(actions[action_index], 10)
		if hint_width == 0 do continue
		right -= hint_width
		ui_draw_action_hint(actions[action_index], right, hint_y, 10, ui_context.theme.muted_text)
		right -= 10
	}

	layout.cursor_y += field_height
}

ui_spacer :: proc(height: f32 = 8) {
	layout := ui_current_layout()
	layout.cursor_y += height
}

ui_status :: proc(message: string, succeeded: bool) {
	if message == "" do return
	color := succeeded ? renderer.Colour{120, 255, 150, 255} : renderer.Colour{255, 120, 120, 255}
	ui_text(message, color, 12)
}

ui_panel :: proc(
	bounds: renderer.Rect,
	title: string,
	border_color := ui_context.theme.panel_border,
) {
	renderer.draw_rect(
		bounds.x,
		bounds.y,
		bounds.width,
		bounds.height,
		ui_context.theme.panel_background,
	)
	ui_draw_fantasy_border(bounds, border_color)
	renderer.draw_text(
		title,
		int(bounds.x + ui_context.theme.padding),
		int(bounds.y + ui_context.theme.padding),
		14,
		border_color,
	)
}

ui_button :: proc(bounds: renderer.Rect, text: string, selected: bool = false) {
	background := renderer.Colour{35, 35, 35, 235}
	if selected do background = {65, 105, 150, 255}

	border := selected ? ui_context.theme.value_text : ui_context.theme.panel_border
	renderer.draw_rect(bounds.x, bounds.y, bounds.width, bounds.height, background)
	ui_draw_fantasy_border(bounds, border)

	font_size := 13
	text_width := f32(renderer.measure_text(text, i32(font_size)))
	text_x := bounds.x + (bounds.width - text_width) / 2
	text_y := bounds.y + (bounds.height - f32(font_size)) / 2
	renderer.draw_text(text, int(text_x), int(text_y), font_size, ui_context.theme.text)
}

ui_menu_panel :: proc(
	title: string,
	items: []string,
	focus: UI_Focus,
	width: f32 = 300,
	button_width: f32 = 220,
	button_height: f32 = 40,
	gap: f32 = 15,
) {
	content_height := f32(len(items)) * button_height + f32(max(len(items) - 1, 0)) * gap
	panel_height :=
		ui_context.theme.padding * 2 + ui_context.theme.line_height + 16 + content_height
	panel_bounds := ui_centered_rect(width, panel_height)
	ui_begin_panel(title, panel_bounds)

	content_bounds := renderer.Rect {
		panel_bounds.x + (panel_bounds.width - button_width) / 2,
		panel_bounds.y + ui_context.theme.padding + ui_context.theme.line_height + 16,
		button_width,
		content_height,
	}
	ui_begin_layout(.Column, content_bounds, gap)
	for item, index in items {
		ui_button(ui_next_rect(button_width, button_height), item, focus.index == index)
	}
	ui_end_layout()
	ui_end_panel()
}

ui_label :: proc(bounds: renderer.Rect, text: string) {
	renderer.draw_text(text, int(bounds.x), int(bounds.y + 2), 13, ui_context.theme.text)
}

ui_keycap :: proc(bounds: renderer.Rect, key: input.Key) {
	ui_draw_prompt_view(ui_key_prompt_view(key), bounds.x, bounds.y + 1, 18)
}

ui_slider :: proc(
	bounds: renderer.Rect,
	label: string,
	value: f32,
	min_value, max_value: f32,
	selected: bool = false,
) {
	if label != "" {
		label_color := selected ? ui_context.theme.value_text : ui_context.theme.text
		renderer.draw_text(label, int(bounds.x), int(bounds.y - 18), 13, label_color)
	}

	if selected {
		ui_draw_fantasy_border(
			{bounds.x - 5, bounds.y - 5, bounds.width + 10, bounds.height + 10},
			ui_context.theme.value_text,
		)
	}

	track_y := bounds.y + bounds.height / 2 - 3
	renderer.draw_rect(bounds.x, track_y, bounds.width, 6, renderer.Colour{45, 45, 45, 255})
	normalized := clamp((value - min_value) / (max_value - min_value), 0, 1)
	renderer.draw_rect(
		bounds.x,
		track_y,
		bounds.width * normalized,
		6,
		ui_context.theme.value_text,
	)
	handle_x := bounds.x + bounds.width * normalized
	renderer.draw_rect(handle_x - 4, bounds.y, 8, bounds.height, ui_context.theme.text)

	value_text := fmt.tprintf("%.0f%%", normalized * 100)
	renderer.draw_text(
		value_text,
		int(bounds.x + bounds.width + 10),
		int(bounds.y + 2),
		13,
		ui_context.theme.value_text,
	)
}

ui_action_hint_width :: proc(action: input.Action, font_size: int = 11) -> f32 {
	prompt := ui_action_prompt_view(action)
	prompt_width := ui_prompt_view_width(prompt)
	if prompt_width == 0 do return 0
	binding := input.action_binding(action)
	label_width := f32(renderer.measure_text(binding.label, i32(font_size)))
	return prompt_width + 6 + label_width
}

ui_draw_action_hint :: proc(
	action: input.Action,
	x, y: f32,
	font_size: int = 11,
	color := ui_context.theme.text,
) -> f32 {
	prompt := ui_action_prompt_view(action)
	prompt_width := ui_prompt_view_width(prompt)
	if prompt_width == 0 do return 0
	binding := input.action_binding(action)
	ui_draw_prompt_view(prompt, x, y)
	label_x := x + prompt_width + 6
	renderer.draw_text(binding.label, int(label_x), int(y + 2), font_size, color)
	return prompt_width + 6 + f32(renderer.measure_text(binding.label, i32(font_size)))
}

ui_action_hint :: proc(action: input.Action, color := ui_context.theme.muted_text) {
	layout := ui_current_layout()
	x := layout.bounds.x + ui_context.theme.padding
	ui_draw_action_hint(action, x, layout.cursor_y, 11, color)
	layout.cursor_y += 22
}

ui_action_bar_height :: proc(actions: []input.Action, width: f32) -> f32 {
	rows := ui_action_bar_rows(actions, width)
	return f32(rows) * 22 + ui_context.theme.padding * 2
}

ui_action_bar :: proc(actions: []input.Action, bounds: renderer.Rect) {
	renderer.draw_rect(
		bounds.x,
		bounds.y,
		bounds.width,
		bounds.height,
		ui_context.theme.panel_background,
	)
	ui_draw_fantasy_border(bounds, ui_context.theme.panel_border)

	padding := ui_context.theme.padding
	x := bounds.x + padding
	y := bounds.y + padding
	right := bounds.x + bounds.width - padding

	for action in actions {
		hint_width := ui_action_hint_width(action)
		if hint_width == 0 do continue
		if x > bounds.x + padding && x + hint_width > right {
			x = bounds.x + padding
			y += 22
		}
		ui_draw_action_hint(action, x, y)
		x += hint_width + 20
	}
}

ui_menu_action_bar :: proc(show_adjust: bool) {
	base_actions := [?]input.Action{.Menu_Navigate, .Menu_Confirm, .Menu_Back}
	adjust_actions := [?]input.Action{.Menu_Navigate, .Menu_Adjust, .Menu_Confirm, .Menu_Back}
	actions := show_adjust ? adjust_actions[:] : base_actions[:]
	width := f32(window.get_design_width()) - 20
	height := ui_action_bar_height(actions, width)
	y := f32(window.get_design_height()) - height - 10
	ui_action_bar(actions, {10, y, width, height})
}

@(private)
ui_action_bar_rows :: proc(actions: []input.Action, width: f32) -> int {
	padding := ui_context.theme.padding
	available_width := width - padding * 2
	x: f32 = 0
	rows := 1

	for action in actions {
		item_width := ui_action_hint_width(action)
		if item_width == 0 do continue
		if x > 0 && x + item_width > available_width {
			rows += 1
			x = 0
		}
		x += item_width + 20
	}
	return rows
}

@(private)
ui_current_layout :: proc() -> ^UI_Layout {
	assert(ui_context.depth > 0, "UI widget must be inside a panel")
	return &ui_context.layouts[ui_context.depth - 1]
}

// Convert design coordinates to screen coordinates
ui_scale_x :: proc(design_x: f32) -> f32 {
	window_width := f32(rl.GetScreenWidth())
	return design_x * (window_width / f32(design_width))
}

ui_scale_y :: proc(design_y: f32) -> f32 {
	window_height := f32(rl.GetScreenHeight())
	return design_y * (window_height / f32(design_height))
}

ui_scale_size :: proc(design_size: int) -> int {
	// Scale size based on average of x/y scaling
	scale_x := f32(rl.GetScreenWidth()) / f32(design_width)
	scale_y := f32(rl.GetScreenHeight()) / f32(design_height)
	avg_scale := (scale_x + scale_y) / 2.0
	return int(f32(design_size) * avg_scale)
}
