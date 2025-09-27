package audio

/// Global audio settings
Audio_Settings :: struct {
	master_volume: f32, // master volume in range 0..=1
	music_volume:  f32, // music volume in range 0..=1
	sfx_volume:    f32, // sfx volume in range 0..=1
}

@(private)
settings := Audio_Settings {
	master_volume = 1.0,
	music_volume  = 1.0,
	sfx_volume    = 1.0,
}

// Get current master volume
get_master_volume :: proc() -> f32 {
	return settings.master_volume
}

// Set master volume (0.0 to 1.0)
set_master_volume :: proc(volume: f32) {
	settings.master_volume = max(0.0, min(volume, 1.0))
	update_music_volume()
}

// Get current music volume
get_music_volume :: proc() -> f32 {
	return settings.music_volume
}

// Set music volume (0.0 to 1.0)
set_music_volume :: proc(volume: f32) {
	settings.music_volume = max(0.0, min(volume, 1.0))
	update_music_volume()
}

// Get current SFX volume
get_sfx_volume :: proc() -> f32 {
	return settings.sfx_volume
}

// Set SFX volume (0.0 to 1.0)
set_sfx_volume :: proc(volume: f32) {
	settings.sfx_volume = max(0.0, min(volume, 1.0))
}

// Get effective music volume (master * music)
get_effective_music_volume :: proc() -> f32 {
	return settings.master_volume * settings.music_volume
}

// Get effective SFX volume (master * sfx)
get_effective_sfx_volume :: proc() -> f32 {
	return settings.master_volume * settings.sfx_volume
}

// Update currently playing music volume
@(private)
update_music_volume :: proc() {
	// This will be called when volume settings change
	// The actual music update should be handled by the game state
}
