package hollie

import "core:math/rand"
import rl "vendor:raylib"

// Audio type aliases for Odin-friendly types
Music :: rl.Music
Sound :: rl.Sound

// Audio device management
audio_init :: proc() {
	rl.InitAudioDevice()
}

audio_close :: proc() {
	rl.CloseAudioDevice()
}

// Music loading and unloading
music_load :: proc(file_path: string) -> Music {
	return rl.LoadMusicStream(cstring(raw_data(file_path)))
}

music_unload :: proc(music: Music) {
	rl.UnloadMusicStream(music)
}

// Sound loading and unloading
sound_load :: proc(file_path: string) -> Sound {
	return rl.LoadSound(cstring(raw_data(file_path)))
}

sound_unload :: proc(sound: Sound) {
	rl.UnloadSound(sound)
}

// Music playback control
music_play :: proc(music: Music) {
	rl.PlayMusicStream(music)
}

music_stop :: proc(music: Music) {
	rl.StopMusicStream(music)
}

music_update :: proc(music: Music) {
	rl.UpdateMusicStream(music)
}

music_set_volume :: proc(music: Music, volume: f32) {
	rl.SetMusicVolume(music, volume)
}

// Sound playback
sound_play :: proc(sound: Sound) {
	rl.PlaySound(sound)
}

sound_set_volume :: proc(sound: Sound, volume: f32) {
	rl.SetSoundVolume(sound, volume)
}

// Sound collections for random playback
Sound_Collection :: struct {
	sounds: []Sound,
}

sound_collection_create :: proc(file_paths: []string) -> Sound_Collection {
	sounds := make([]Sound, len(file_paths))
	for path, i in file_paths {
		sounds[i] = sound_load(path)
	}
	return Sound_Collection{sounds}
}

sound_collection_destroy :: proc(collection: ^Sound_Collection) {
	for sound in collection.sounds {
		sound_unload(sound)
	}
	delete(collection.sounds)
}

sound_collection_play_random :: proc(collection: Sound_Collection) {
	if len(collection.sounds) == 0 do return

	sound := rand.choice(collection.sounds)
	sound_play(sound)
}
