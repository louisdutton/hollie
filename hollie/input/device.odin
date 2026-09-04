package input

Input_Device :: enum {
	Keyboard,
	Gamepad,
}

@(private)
last_input_device := Input_Device.Keyboard

active_device :: proc() -> Input_Device {
	if last_input_device == .Gamepad && !is_gamepad_available(.Player_1) {
		return .Keyboard
	}
	return last_input_device
}

@(private)
note_device_input :: proc(device: Input_Device) {
	last_input_device = device
}
