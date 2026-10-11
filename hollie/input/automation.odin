package input

// Injection is compiled only for debug builds and input unit tests.
when ODIN_DEBUG || ODIN_TEST {
	Automation_Gamepad :: struct {
		player:  Player_Index,
		buttons: []Gamepad_Button,
		axes:    []f32,
	}

	Automation_Input :: struct {
		keys:      [512]bool,
		available: [Player_Index]bool,
		buttons:   [Player_Index][32]bool,
		axes:      [Player_Index][6]f32,
	}

	@(private)
	automation_enabled: bool
	@(private)
	automation_current, automation_previous: Automation_Input

	automation_enable :: proc() {
		automation_enabled = true
		automation_reset()
	}

	automation_reset :: proc() {
		automation_current = {}
		automation_previous = {}
		last_input_device = .Keyboard
	}

	// Validate before applying so a bad command leaves the held input unchanged.
	automation_set :: proc(keys: []Key, gamepads: []Automation_Gamepad) -> bool {
		next: Automation_Input
		for key in keys {
			if int(key) < 0 || int(key) >= len(next.keys) do return false
			next.keys[int(key)] = true
		}
		for pad in gamepads {
			if int(pad.player) < 0 || int(pad.player) >= len(next.available) do return false
			if next.available[pad.player] || len(pad.axes) > 6 do return false
			next.available[pad.player] = true
			for button in pad.buttons {
				if int(button) < 0 || int(button) >= 32 do return false
				next.buttons[pad.player][int(button)] = true
			}
			for axis, index in pad.axes {
				if !(axis >= -1 && axis <= 1) do return false
				next.axes[pad.player][index] = axis
			}
		}
		automation_current = next
		return true
	}

	// Edges change only when a simulation frame is consumed, not when drawing.
	automation_end_frame :: proc() {
		automation_previous = automation_current
	}
}
