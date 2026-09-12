package hollie

MAX_SIMULATION_DELTA :: f32(0.1)

// Discard excess time after stalls. UI and scene tweens use unclamped frame time.
simulation_delta_time :: proc(frame_dt: f32) -> f32 {
	return clamp(frame_dt, 0, MAX_SIMULATION_DELTA)
}
