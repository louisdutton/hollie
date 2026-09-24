package hollie

// Resolved environment values consumed by rendering. Future weather/time-of-day
// controllers can blend presets here without adding material-specific clocks.
Environment_Period :: enum {
	Day,
	Night,
}

Environment_State :: struct {
	period:                                                        Environment_Period,
	ambient, sun_direction, sun_color, fill_direction, fill_color: Vec3,
	water_light_floor:                                             Vec3,
}

ENVIRONMENT_DAY :: Environment_State {
	ambient           = {0.22, 0.23, 0.32},
	sun_direction     = {-0.5, -0.7, 0.5},
	sun_color         = {0.6, 0.56, 0.52},
	fill_direction    = {0.65, -0.35, 0.55},
	fill_color        = {0.07, 0.09, 0.13},
	water_light_floor = {1, 1, 1},
}

ENVIRONMENT_NIGHT :: Environment_State {
	period            = .Night,
	ambient           = {0.055, 0.075, 0.14},
	sun_direction     = {-0.5, -0.7, 0.5}, // Moon key light uses the same shadow pipeline.
	sun_color         = {0.12, 0.18, 0.32},
	fill_direction    = {0.65, -0.35, 0.55},
	fill_color        = {0.025, 0.04, 0.08},
	water_light_floor = {0.08, 0.12, 0.22},
}

environment := ENVIRONMENT_DAY

environment_toggle_period :: proc(state: ^Environment_State) {
	state^ = state.period == .Day ? ENVIRONMENT_NIGHT : ENVIRONMENT_DAY
}
