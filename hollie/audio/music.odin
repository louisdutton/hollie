package audio

import rl "vendor:raylib"

Music :: rl.Music

music_init :: proc(file_path: string) -> Music {
	return rl.LoadMusicStream(cstring(raw_data(file_path)))
}

music_fini :: proc(music: Music) {
	rl.UnloadMusicStream(music)
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
