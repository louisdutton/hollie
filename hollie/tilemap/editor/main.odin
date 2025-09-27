package main

import "../../"
import "../../renderer"
import "../../window"
import "core:os"

main :: proc() {
	init()
	defer fini()

	for !window.should_close() {
		update()
		draw()
	}
}

init :: proc() {
	window.init(1200, 800, "Tilemap Editor")
	editor_init()
}

update :: proc() {
	editor_update()
}

draw :: proc() {
	renderer.begin_drawing()
	defer renderer.end_drawing()

	renderer.clear_background()
	editor_draw()
}

fini :: proc() {
	editor_fini()
	window.fini()
}
