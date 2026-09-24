package hollie

import "core:testing"

@(test)
test_camera_zoom_eases_between_modes_and_resets_override :: proc(t: ^testing.T) {
	state := Camera_Zoom_State {
		target = ZOOM_DEFAULT,
	}
	zoom := camera_zoom_step(&state, ZOOM_DEFAULT, .Riding, 0, 0.1)
	testing.expect(t, zoom < ZOOM_DEFAULT && zoom > ZOOM_RIDING)
	testing.expect_value(t, state.target, f32(ZOOM_RIDING))
	zoom = camera_zoom_step(&state, zoom, .Riding, 1, 0.5)
	overridden := state.target
	testing.expect(t, overridden > ZOOM_RIDING)
	zoom = camera_zoom_step(&state, zoom, .Riding, 0, 0.1)
	testing.expect_value(t, state.target, overridden)
	zoom = camera_zoom_step(&state, zoom, .Dialog, 0, 0.1)
	testing.expect_value(t, state.target, f32(ZOOM_DIALOG))
	zoom = camera_zoom_step(&state, zoom, .Riding, 0, 0.1)
	testing.expect_value(t, state.target, f32(ZOOM_RIDING))
	zoom = camera_zoom_step(&state, zoom, .On_Foot, 0, 0.1)
	testing.expect_value(t, state.target, f32(ZOOM_DEFAULT))
	testing.expect_value(t, camera_zoom_step(&state, zoom, .On_Foot, 1, 0), zoom)
}

@(test)
test_camera_zoom_easing_is_frame_rate_independent :: proc(t: ^testing.T) {
	slow, fast := Camera_Zoom_State {
			target = ZOOM_DEFAULT,
		}, Camera_Zoom_State {
			target = ZOOM_DEFAULT,
		}
	a, b := f32(ZOOM_DEFAULT), f32(ZOOM_DEFAULT)
	for i in 0 ..< 30 do a = camera_zoom_step(&slow, a, .Riding, 0, 1.0 / 30)
	for i in 0 ..< 120 do b = camera_zoom_step(&fast, b, .Riding, 0, 1.0 / 120)
	testing.expect(t, abs(a - b) < 0.00001)
	_ = camera_zoom_step(&slow, a, .Riding, 1, 100)
	testing.expect_value(t, slow.target, f32(ZOOM_MAX))
	_ = camera_zoom_step(&slow, a, .Riding, -1, 100)
	testing.expect_value(t, slow.target, f32(ZOOM_MIN))
}
