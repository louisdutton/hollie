package gui

import "../renderer"
import "../window"
import "core:fmt"
import rl "vendor:raylib"

Vec2 :: rl.Vector2
Color :: rl.Color
Rectangle :: rl.Rectangle

// GUI context for managing state
Context :: struct {
	ui_scale: f32,
	camera:   rl.Camera2D,
}

@(private)
ctx := Context{}

// Initialize GUI context
init :: proc() {
	ctx.ui_scale = window.get_ui_scale()
	ctx.camera = rl.Camera2D {
		zoom = ctx.ui_scale,
	}
}

// Begin GUI rendering - call before drawing any GUI elements
begin :: proc() {
	ctx.ui_scale = window.get_ui_scale()
	ctx.camera.zoom = ctx.ui_scale
	renderer.begin_mode_2d(ctx.camera)
}

// End GUI rendering - call after drawing all GUI elements
end :: proc() {
	renderer.end_mode_2d()
}

// Transform raw mouse position to GUI coordinate space
get_mouse_pos :: proc() -> Vec2 {
	raw_mouse := rl.GetMousePosition()
	return rl.GetScreenToWorld2D(raw_mouse, ctx.camera)
}

// Draw a button and return true if clicked
button :: proc(rect: Rectangle, text: string) -> bool {
	mouse_pos := get_mouse_pos()
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

// Draw a panel background with title bar
panel :: proc(rect: Rectangle, title: string) {
	// Panel background
	rl.DrawRectangleRec(rect, Color{240, 240, 240, 255})
	rl.DrawRectangleLinesEx(rect, 1, rl.BLACK)

	// Title bar
	title_rect := Rectangle{rect.x, rect.y, rect.width, 25}
	rl.DrawRectangleRec(title_rect, Color{200, 200, 200, 255})
	rl.DrawRectangleLinesEx(title_rect, 1, rl.BLACK)

	// Title text
	rl.DrawText(cstring(raw_data(title)), i32(rect.x + 5), i32(rect.y + 5), 16, rl.BLACK)
}

// Draw a label
label :: proc(rect: Rectangle, text: string) {
	renderer.draw_text(text, int(rect.x), int(rect.y) + 2)
}

// Draw a slider and return true if value changed
slider :: proc(rect: Rectangle, label_text: string, value: ^f32, min_val, max_val: f32) -> bool {
	mouse_pos := get_mouse_pos()
	changed := false

	// Draw label
	if len(label_text) > 0 {
		rl.DrawText(cstring(raw_data(label_text)), i32(rect.x), i32(rect.y - 18), 14, rl.BLACK)
	}

	// Draw track
	track_rect := Rectangle{rect.x, rect.y + 5, rect.width, 10}
	rl.DrawRectangleRec(track_rect, rl.LIGHTGRAY)
	rl.DrawRectangleLinesEx(track_rect, 1, rl.GRAY)

	// Calculate handle position
	normalized := (value^ - min_val) / (max_val - min_val)
	handle_x := rect.x + normalized * (rect.width - 10)
	handle_rect := Rectangle{handle_x, rect.y, 10, rect.height}

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

// Draw a checkbox and return true if state changed
checkbox :: proc(rect: Rectangle, label_text: string, checked: ^bool) -> bool {
	mouse_pos := get_mouse_pos()
	hovered := rl.CheckCollisionPointRec(mouse_pos, rect)
	clicked := hovered && rl.IsMouseButtonPressed(.LEFT)

	if clicked {
		checked^ = !checked^
	}

	// Draw checkbox background
	color := hovered ? rl.LIGHTGRAY : rl.WHITE
	rl.DrawRectangleRec(rect, color)
	rl.DrawRectangleLinesEx(rect, 1, rl.BLACK)

	// Draw checkmark if checked
	if checked^ {
		check_color := rl.DARKGREEN
		margin: f32 = 3
		rl.DrawRectangleRec(
			Rectangle {
				rect.x + margin,
				rect.y + margin,
				rect.width - 2 * margin,
				rect.height - 2 * margin,
			},
			check_color,
		)
	}

	// Draw label
	if len(label_text) > 0 {
		rl.DrawText(
			cstring(raw_data(label_text)),
			i32(rect.x + rect.width + 5),
			i32(rect.y + 2),
			16,
			rl.BLACK,
		)
	}

	return clicked
}

// Draw a separator line
separator :: proc(rect: Rectangle) {
	rl.DrawRectangleRec(rect, rl.GRAY)
}

// Draw a colored rectangle
colored_rect :: proc(rect: Rectangle, color: Color) {
	rl.DrawRectangleRec(rect, color)
}
