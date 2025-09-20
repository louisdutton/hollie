package hollie

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
