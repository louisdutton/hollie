package hollie

import "base:runtime"
import "core:fmt"
import "core:strings"
import "core:testing"

Frame_Test_State :: struct {
	text:         string,
	saved:        string,
	frames:       int,
	draws:        int,
	skip_drawing: bool,
}

frame_test_update :: proc() {
	state := cast(^Frame_Test_State)context.user_ptr
	state.text = fmt.tprintf("Frame %d", state.frames)
	if state.saved == "" do state.saved = strings.clone(state.text)
	state.frames += 1
}

frame_test_draw :: proc() {
	state := cast(^Frame_Test_State)context.user_ptr
	// Check before allocating again: cleanup between update and draw would erase this.
	assert(strings.has_prefix(state.text, "Frame "))
	state.draws += 1
	if state.skip_drawing do return
	// Exercise arena growth as well as the small UI strings allocated by update.
	scratch := make([]u8, 16384, context.temp_allocator)
	scratch[0] = 42
	label := fmt.tprintf("Drawing %s", state.text)
	assert(strings.has_prefix(label, "Drawing Frame "))
}

@(test)
test_frame_temporaries_survive_drawing_and_are_reclaimed :: proc(t: ^testing.T) {
	temp: runtime.Default_Temp_Allocator
	runtime.default_temp_allocator_init(&temp, 4096, context.allocator)
	defer runtime.default_temp_allocator_destroy(&temp)
	context.temp_allocator = runtime.default_temp_allocator(&temp)
	initial_capacity := temp.arena.total_capacity
	state: Frame_Test_State
	defer delete(state.saved)
	context.user_ptr = &state
	for frame in 0 ..< 64 {
		// An early return from drawing, as on a suspended frame, still reclaims update text.
		state.skip_drawing = frame % 2 == 1
		run_frame(frame_test_update, frame_test_draw)
		testing.expect_value(t, temp.arena.total_used, uint(0))
		testing.expect_value(t, temp.arena.total_capacity, initial_capacity)
		testing.expect_value(t, state.saved, "Frame 0")
	}
	testing.expect_value(t, state.frames, 64)
	testing.expect_value(t, state.draws, 64)
}
