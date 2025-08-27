package hollie

import "core:c"
import "core:fmt"
import "renderer"
import rl "vendor:raylib"

message := "Hi there, my name is Basil!"
message_display := ""

draw_dialog :: proc() {
	MARGIN_X :: 100
	MARGIN_Y :: 10
	PADDING_X :: 10
	PADDING_Y :: 10

	screen_w := rl.GetScreenWidth()
	screen_h := rl.GetScreenHeight()

	// bg
	bg_height :: 200
	bg_x := f32(MARGIN_X)
	bg_y := f32(screen_h - bg_height - MARGIN_Y)
	renderer.draw_rect_rounded(bg_x, bg_y, f32(screen_w - MARGIN_X * 2), bg_height)

	// image
	img_height :: bg_height - PADDING_Y * 2
	img_width :: img_height
	img_x := bg_x + PADDING_X
	renderer.draw_rect_rounded(img_x, bg_y + PADDING_Y, img_height, img_height, color = rl.SKYBLUE)

	// message
	renderer.draw_text(message, int(img_x + img_width) + PADDING_X, int(bg_y) + PADDING_Y)
}
