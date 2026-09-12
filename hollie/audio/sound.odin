package audio

import "../asset"
import "core:math/rand"
import rl "vendor:raylib"

Sound_Kind :: enum {
	Gate_Open,
	Pressure_Plate_Toggle,
	Switch_On,
	Switch_Off,
	Button_Press,
}

Sound :: struct {
	sounds:          []rl.Sound,
	volume:          f32,
	pitch_variation: f32,
}

Sound_Collection :: [Sound_Kind]Sound

sound_init :: proc() -> Sound_Collection {
	sounds: Sound_Collection

	sounds[.Gate_Open] = _sound_init({"audio/fx/impact/whoosh-airy-flutter-01.wav"})
	sounds[.Pressure_Plate_Toggle] = _sound_init({"audio/fx/impact/hit-short-04.wav"})
	sounds[.Switch_On] = _sound_init({"audio/fx/combat/whoosh-short-light.wav"})
	sounds[.Switch_Off] = _sound_init({"audio/fx/impact/hit-short-04.wav"})
	sounds[.Button_Press] = _sound_init({"audio/fx/impact/hit-short-04.wav"})
	return sounds
}

sound_play :: proc(sound_bank: ^Sound_Collection, kind: Sound_Kind) {
	sound := sound_bank[kind]
	_sound_play(sound)
}

sound_fini :: proc(sounds: ^Sound_Collection) {
	for &sound in sounds^ {
		_sound_fini(&sound)
	}
}

@(private)
_sound_play :: proc(sound: Sound) {
	assert(len(sound.sounds) > 0)

	sample := rand.choice(sound.sounds)
	pitch := 1.0 + rand.float32_range(-sound.pitch_variation, sound.pitch_variation)

	// Apply global SFX volume setting
	effective_volume := sound.volume * get_effective_sfx_volume()
	rl.SetSoundVolume(sample, effective_volume)
	rl.SetSoundPitch(sample, pitch)
	rl.PlaySound(sample)
}

@(private)
_sound_init :: proc(file_paths: []string, volume: f32 = 0.5, pitch_variation: f32 = 0.1) -> Sound {
	sounds := make([]rl.Sound, len(file_paths))
	for path, i in file_paths {
		full_path := asset.path(path)
		defer delete(full_path)
		sounds[i] = rl.LoadSound(cstring(raw_data(full_path)))
	}
	return Sound{sounds = sounds, volume = volume, pitch_variation = pitch_variation}
}


@(private)
_sound_fini :: proc(sound: ^Sound) {
	for rl_sound in sound.sounds do rl.UnloadSound(rl_sound)
	delete(sound.sounds)
}
