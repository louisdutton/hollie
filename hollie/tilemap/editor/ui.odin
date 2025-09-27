package main

import "../"
import "../../"
import "../../input"
import "../../renderer"
import "../../window"
import "core:fmt"
import "core:math"
import rl "vendor:raylib"

ui_begin :: proc() {
	ui_scale := window.get_ui_scale()
	renderer.begin_mode_2d({zoom = ui_scale})
}

ui_end :: proc() {
	renderer.end_mode_2d()
}

/// Draw a button and return true if clicked
ui_button :: proc(rect: rl.Rectangle, text: string) -> bool {
	// Transform mouse to UI coordinate space
	raw_mouse := rl.GetMousePosition()
	ui_camera := rl.Camera2D {
		zoom = window.get_ui_scale(),
	}
	mouse_pos := rl.GetScreenToWorld2D(raw_mouse, ui_camera)

	hovered := rl.CheckCollisionPointRec(mouse_pos, rect)
	pressed := hovered && rl.IsMouseButtonPressed(.LEFT)

	// Button colors
	color := hovered ? rl.LIGHTGRAY : rl.GRAY
	if pressed do color = rl.DARKGRAY

	// Draw button
	rl.DrawRectangleRec(rect, color)
	rl.DrawRectangleLinesEx(rect, 1, rl.BLACK)

	FONT_SIZE :: 12

	// Draw text centered
	text_width := renderer.measure_text(text, FONT_SIZE)
	text_x := int(rect.x + (rect.width - f32(text_width)) / 2)
	text_y := int(rect.y + (rect.height - FONT_SIZE) / 2)
	renderer.draw_text(text, text_x, text_y, FONT_SIZE, rl.BLACK)

	return pressed
}

/// Draw a panel background
ui_panel :: proc(rect: rl.Rectangle, title: string) {
	// Panel background
	rl.DrawRectangleRec(rect, rl.Color{240, 240, 240, 255})
	rl.DrawRectangleLinesEx(rect, 1, rl.BLACK)

	// Title bar
	title_rect := rl.Rectangle{rect.x, rect.y, rect.width, 25}
	rl.DrawRectangleRec(title_rect, rl.Color{200, 200, 200, 255})
	rl.DrawRectangleLinesEx(title_rect, 1, rl.BLACK)

	// Title text
	rl.DrawText(cstring(raw_data(title)), i32(rect.x + 5), i32(rect.y + 5), 16, rl.BLACK)
}

/// Draw a label
ui_label :: proc(rect: rl.Rectangle, text: string) {
	rl.DrawText(cstring(raw_data(text)), i32(rect.x), i32(rect.y + 2), 16, rl.BLACK)
}

/// Draw a slider and return true if value changed
ui_slider :: proc(rect: rl.Rectangle, label: string, value: ^f32, min_val, max_val: f32) -> bool {
	// Transform mouse to UI coordinate space
	raw_mouse := rl.GetMousePosition()
	ui_camera := rl.Camera2D {
		zoom = window.get_ui_scale(),
	}
	mouse_pos := rl.GetScreenToWorld2D(raw_mouse, ui_camera)
	changed := false

	// Draw label
	if len(label) > 0 {
		rl.DrawText(cstring(raw_data(label)), i32(rect.x), i32(rect.y - 18), 14, rl.BLACK)
	}

	// Draw track
	track_rect := rl.Rectangle{rect.x, rect.y + 5, rect.width, 10}
	rl.DrawRectangleRec(track_rect, rl.LIGHTGRAY)
	rl.DrawRectangleLinesEx(track_rect, 1, rl.GRAY)

	// Calculate handle position
	normalized := (value^ - min_val) / (max_val - min_val)
	handle_x := rect.x + normalized * (rect.width - 10)
	handle_rect := rl.Rectangle{handle_x, rect.y, 10, rect.height}

	// Handle interaction
	if rl.IsMouseButtonDown(.LEFT) && rl.CheckCollisionPointRec(mouse_pos, rect) {
		relative_x := (mouse_pos.x - rect.x) / rect.width
		new_value := min_val + relative_x * (max_val - min_val)
		new_value = max(new_value, min_val)
		new_value = min(new_value, max_val)
		if new_value != value^ {
			value^ = new_value
			changed = true
		}
	}

	// Draw handle
	handle_color := rl.CheckCollisionPointRec(mouse_pos, handle_rect) ? rl.DARKGRAY : rl.GRAY
	rl.DrawRectangleRec(handle_rect, handle_color)
	rl.DrawRectangleLinesEx(handle_rect, 1, rl.BLACK)

	// Draw value text
	value_text := fmt.ctprintf("%.0f", value^)
	rl.DrawText(value_text, i32(rect.x + rect.width + 10), i32(rect.y + 2), 14, rl.BLACK)

	return changed
}
