package input

import "core:testing"

when ODIN_TEST {
	@(test)
	automation_input_edges_and_validation :: proc(t: ^testing.T) {
		automation_enable()
		defer {
			automation_reset()
			automation_enabled = false
		}
		testing.expect(t, automation_set([]Key{.S}, nil))
		testing.expect(t, is_key_pressed(.S))
		testing.expect(t, is_key_pressed(.S)) // Multiple consumers see the same edge.
		automation_end_frame()
		testing.expect(t, is_key_down(.S))
		testing.expect(t, !is_key_pressed(.S))
		testing.expect(t, automation_set([]Key{.S}, nil)) // Held across batches.
		testing.expect(t, !is_key_pressed(.S))
		testing.expect(t, !automation_set([]Key{Key(512)}, nil))
		testing.expect(t, is_key_down(.S)) // Invalid commands are atomic.
		testing.expect(t, automation_set(nil, nil))
		automation_end_frame()
		testing.expect(t, automation_set([]Key{.S}, nil))
		testing.expect(t, is_key_pressed(.S)) // Release and press creates a new edge.

		pads := []Automation_Gamepad {
			{
				player = .Player_1,
				buttons = []Gamepad_Button{.RIGHT_FACE_DOWN},
				axes = []f32{0.5, -1},
			},
			{player = .Player_2, axes = []f32{-0.5, 1}},
		}
		testing.expect(t, automation_set(nil, pads))
		testing.expect(t, is_gamepad_available(.Player_1))
		testing.expect(t, is_gamepad_available(.Player_2))
		testing.expect_value(t, get_gamepad_axis_movement(.Player_1, .LEFT_X), f32(0.5))
		testing.expect_value(t, get_gamepad_axis_movement(.Player_2, .LEFT_Y), f32(1))
		testing.expect(t, is_gamepad_button_pressed(.Player_1, .RIGHT_FACE_DOWN))
		testing.expect(t, !is_gamepad_button_pressed(.Player_2, .RIGHT_FACE_DOWN))
		automation_end_frame()
		testing.expect(t, is_gamepad_button_down(.Player_1, .RIGHT_FACE_DOWN))
		testing.expect(t, !is_gamepad_button_pressed(.Player_1, .RIGHT_FACE_DOWN))
		pads[1].axes = []f32{2}
		testing.expect(t, !automation_set(nil, pads))
		testing.expect_value(t, get_gamepad_axis_movement(.Player_2, .LEFT_Y), f32(1))
		pads[1] = pads[0]
		testing.expect(t, !automation_set(nil, pads)) // Duplicate player rejected.
		automation_reset()
		testing.expect(t, !is_key_down(.S))
		testing.expect(t, !is_gamepad_available(.Player_1))
		testing.expect(t, !is_gamepad_button_down(.Player_1, .RIGHT_FACE_DOWN))
	}
}
