package audio

import "core:math/rand"
import rl "vendor:raylib"

Sound :: struct {
	sounds:          []rl.Sound,
	volume:          f32,
	pitch_variation: f32,
}

Sound_Map :: map[string]Sound

sound_init :: proc(file_paths: []string, volume: f32 = 0.5, pitch_variation: f32 = 0.1) -> Sound {
	sounds := make([]rl.Sound, len(file_paths))
	for path, i in file_paths {
		sounds[i] = rl.LoadSound(cstring(raw_data(path)))
	}
	return Sound{sounds = sounds, volume = volume, pitch_variation = pitch_variation}
}

sound_fini :: proc(sound: ^Sound) {
	for rl_sound in sound.sounds {
		rl.UnloadSound(rl_sound)
	}
	delete(sound.sounds)
}

sound_play :: proc(sound: Sound) {
	assert(len(sound.sounds) > 0)

	sample := rand.choice(sound.sounds)
	pitch := 1.0 + rand.float32_range(-sound.pitch_variation, sound.pitch_variation)

	rl.SetSoundVolume(sample, sound.volume)
	rl.SetSoundPitch(sample, pitch)
	rl.PlaySound(sample)
}
