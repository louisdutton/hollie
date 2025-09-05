package hollie

import "core:c"
import "core:fmt"
import "core:strings"
import "core:unicode/utf8"
import "renderer"
import "tween"
import rl "vendor:raylib"

message := utf8.string_to_runes("Hi there, my name is Basil!")
message_progress: f32 = 0.0

init_dialog :: proc() {
	tween.to(&message_progress, 1.0, .Linear)
}

update_dialog :: proc() {}

draw_dialog :: proc() {
	MARGIN_X :: 100
	MARGIN_Y :: 10
	PADDING_X :: 15
	PADDING_Y :: 15

	screen_w := rl.GetScreenWidth()
	screen_h := rl.GetScreenHeight()

	// bg
	bg_height :: 200
	bg_x := f32(MARGIN_X)
	bg_y := f32(screen_h - bg_height - MARGIN_Y)
	renderer.draw_rect(bg_x, bg_y, f32(screen_w - MARGIN_X * 2), bg_height)
	renderer.draw_rect_outline(bg_x, bg_y, f32(screen_w - MARGIN_X * 2), bg_height)

	// message
	// TODO: allocate once and mutate the string contents
	str := utf8.runes_to_string(message[:int(message_progress * f32(len(message)))])
	defer delete(str)
	renderer.draw_text(str, MARGIN_X + PADDING_X, int(bg_y) + PADDING_Y)
}
