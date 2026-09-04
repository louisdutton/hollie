package audio

import "../asset"
import "core:math/rand"
import rl "vendor:raylib"

Sound_Kind :: enum {
	GruntRoll,
	GruntAttack,
	AttackHit,
	EnemyHit,
	EnemyDeath,
	GateOpen,
	PressurePlateToggle,
	SwitchOn,
	SwitchOff,
	ButtonPress,
}

Sound_Kind_Count :: 10

Sound :: struct {
	sounds:          []rl.Sound,
	volume:          f32,
	pitch_variation: f32,
}

Sound_Collection :: [Sound_Kind_Count]Sound

sound_init :: proc() -> Sound_Collection {
	sounds: Sound_Collection

	sounds[int(Sound_Kind.GruntRoll)] = _sound_init(
		{
			"audio/fx/voices/grunting/female/meghan-christian/grunting_1_meghan.wav",
			"audio/fx/voices/grunting/female/meghan-christian/grunting_2_meghan.wav",
		},
	)
	sounds[int(Sound_Kind.GruntAttack)] = _sound_init(
		{"audio/fx/combat/whoosh-short-light.wav", "audio/fx/impact/whoosh-arm-swing-01-wide.wav"},
	)
	sounds[int(Sound_Kind.AttackHit)] = _sound_init(
		{
			"audio/fx/impact/punch-percussive-heavy-08.wav",
			"audio/fx/impact/punch-percussive-heavy-09.wav",
		},
	)
	sounds[int(Sound_Kind.EnemyHit)] = _sound_init(
		{"audio/fx/impact/punch-squelch-heavy-05.wav"},
	)
	sounds[int(Sound_Kind.EnemyDeath)] = _sound_init(
		{"audio/fx/impact/waterplosion.wav"},
	)
	sounds[int(Sound_Kind.GateOpen)] = _sound_init(
		{"audio/fx/impact/whoosh-airy-flutter-01.wav"},
	)
	sounds[int(Sound_Kind.PressurePlateToggle)] = _sound_init(
		{"audio/fx/impact/hit-short-04.wav"},
	)
	sounds[int(Sound_Kind.SwitchOn)] = _sound_init(
		{"audio/fx/combat/whoosh-short-light.wav"},
	)
	sounds[int(Sound_Kind.SwitchOff)] = _sound_init({"audio/fx/impact/hit-short-04.wav"})
	sounds[int(Sound_Kind.ButtonPress)] = _sound_init({"audio/fx/impact/hit-short-04.wav"})
	return sounds
}

sound_play :: proc(sound_bank: ^Sound_Collection, kind: Sound_Kind) {
	sound := sound_bank[int(kind)]
	_sound_play(sound)
}

sound_fini :: proc(sounds: ^Sound_Collection) {
	for sound_index := 0; sound_index < Sound_Kind_Count; sound_index += 1 {
		_sound_fini(&sounds[sound_index])
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
		sounds[i] = rl.LoadSound(cstring(raw_data(full_path)))
	}
	return Sound{sounds = sounds, volume = volume, pitch_variation = pitch_variation}
}


@(private)
_sound_fini :: proc(sound: ^Sound) {
	for rl_sound in sound.sounds do rl.UnloadSound(rl_sound)
	delete(sound.sounds)
}
