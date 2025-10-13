package audio

import "../asset"
import "core:math/rand"
import rl "vendor:raylib"

Sound :: struct {
	sounds:          []rl.Sound,
	volume:          f32,
	pitch_variation: f32,
}

Sound_Map :: map[string]Sound

sound_init :: proc() -> Sound_Map {
	sounds := make(Sound_Map)

	sounds["grunt_roll"] = _sound_init(
		{
			"audio/fx/voices/grunting/female/meghan-christian/grunting_1_meghan.wav",
			"audio/fx/voices/grunting/female/meghan-christian/grunting_2_meghan.wav",
		},
	)
	sounds["grunt_attack"] = _sound_init(
		{"audio/fx/combat/whoosh-short-light.wav", "audio/fx/impact/whoosh-arm-swing-01-wide.wav"},
	)
	sounds["attack_hit"] = _sound_init(
		{
			"audio/fx/impact/punch-percussive-heavy-08.wav",
			"audio/fx/impact/punch-percussive-heavy-09.wav",
		},
	)
	sounds["enemy_hit"] = _sound_init({"audio/fx/impact/punch-squelch-heavy-05.wav"})
	sounds["enemy_death"] = _sound_init({"audio/fx/impact/waterplosion.wav"})
	sounds["gate_open"] = _sound_init({"audio/fx/impact/whoosh-airy-flutter-01.wav"})
	sounds["gate_close"] = _sound_init({"audio/fx/impact/hit-short-04.wav"})
	sounds["switch_on"] = _sound_init({"audio/fx/combat/whoosh-short-light.wav"})
	sounds["switch_off"] = _sound_init({"audio/fx/impact/hit-short-04.wav"})
	sounds["button_press"] = _sound_init({"audio/fx/impact/hit-short-04.wav"})
	return sounds
}

sound_fini :: proc(sounds: ^Sound_Map) {
	for _, &sound in sounds do _sound_fini(&sound)
	clear(sounds)
}

sound_play :: proc(sound: Sound) {
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
		sounds[i] = rl.LoadSound(cstring(raw_data(full_path)))
	}
	return Sound{sounds = sounds, volume = volume, pitch_variation = pitch_variation}
}


@(private)
_sound_fini :: proc(sound: ^Sound) {
	for rl_sound in sound.sounds do rl.UnloadSound(rl_sound)
	delete(sound.sounds)
}
