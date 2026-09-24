package hollie

// Resolved environment values consumed by rendering. Future weather/time-of-day
// controllers can blend presets here without adding material-specific clocks.
Environment_State :: struct {
	ambient, sun_direction, sun_color, fill_direction, fill_color: Vec3,
	wind_velocity, cloud_offset:                                   Vec2,
	cloud_scale, cloud_coverage, cloud_softness, cloud_strength:   f32,
}

ENVIRONMENT_DAY :: Environment_State {
	ambient        = {0.22, 0.23, 0.32},
	sun_direction  = {-0.5, -0.7, 0.5},
	sun_color      = {0.6, 0.56, 0.52},
	fill_direction = {0.65, -0.35, 0.55},
	fill_color     = {0.07, 0.09, 0.13},
	wind_velocity  = {10, 4.5},
	cloud_scale    = 0.012,
	cloud_coverage = 0.52,
	cloud_softness = 0.08,
	cloud_strength = 0.78,
}

environment := ENVIRONMENT_DAY

environment_update :: proc(state: ^Environment_State, dt: f32) {
	state.cloud_offset += state.wind_velocity * max(dt, 0)
}
