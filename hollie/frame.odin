package hollie

// Temporary strings must survive both update and drawing, including renderer flushes.
// Clone anything retained across frames using the regular allocator.
run_frame :: proc(update_frame, draw_frame: proc()) {
	defer free_all(context.temp_allocator)
	update_frame()
	draw_frame()
}
