package main

import "../"
import "../../"
import "../../gui"
import "core:fmt"
import "core:math"
import rl "vendor:raylib"

ui_begin :: proc() {
	gui.begin()
}

ui_end :: proc() {
	gui.end()
}

/// Draw a button and return true if clicked
ui_button :: proc(rect: rl.Rectangle, text: string) -> bool {
	return gui.button(rect, text)
}

/// Draw a panel background
ui_panel :: proc(rect: rl.Rectangle, title: string) {
	gui.panel(rect, title)
}

/// Draw a label
ui_label :: proc(rect: rl.Rectangle, text: string) {
	gui.label(rect, text)
}

/// Draw a slider and return true if value changed
ui_slider :: proc(rect: rl.Rectangle, label: string, value: ^f32, min_val, max_val: f32) -> bool {
	return gui.slider(rect, label, value, min_val, max_val)
}
