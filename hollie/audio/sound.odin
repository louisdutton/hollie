package audio

import "core:math/rand"
import rl "vendor:raylib"

Sound :: rl.Sound
Sound_Collection :: struct {
	sounds: []Sound,
}

sound_init :: proc(file_path: string) -> Sound {
	return rl.LoadSound(cstring(raw_data(file_path)))
}

sound_fini :: proc(sound: Sound) {
	rl.UnloadSound(sound)
}

sound_play :: proc(sound: Sound, volume: f32 = 0.5, pitch: f32 = 1.0) {
	rl.SetSoundVolume(sound, volume)
	rl.SetSoundPitch(sound, pitch + rand.float32_range(-0.1, 0.1))
	rl.PlaySound(sound)
}

sound_set_volume :: proc(sound: Sound, volume: f32) {
	rl.SetSoundVolume(sound, volume)
}

sound_collection_init :: proc(file_paths: []string) -> Sound_Collection {
	sounds := make([]Sound, len(file_paths))
	for path, i in file_paths {
		sounds[i] = sound_init(path)
	}
	return Sound_Collection{sounds}
}

sound_collection_fini :: proc(collection: ^Sound_Collection) {
	for sound in collection.sounds do sound_fini(sound)
	delete(collection.sounds)
}

sound_collection_play_random :: proc(collection: Sound_Collection) {
	if len(collection.sounds) == 0 do return
	sound := rand.choice(collection.sounds)
	sound_play(sound)
}
