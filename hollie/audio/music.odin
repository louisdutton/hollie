package audio

import rl "vendor:raylib"

Music :: rl.Music

MUSIC_ENABLED :: false // Temporarily disable music playback.

music_init :: proc(file_path: string) -> Music {
	return rl.LoadMusicStream(cstring(raw_data(file_path)))
}

music_fini :: proc(music: Music) {
	rl.UnloadMusicStream(music)
}

// Music playback control
music_play :: #force_inline proc(music: Music) {
	if !MUSIC_ENABLED do return
	rl.PlayMusicStream(music)
}

music_stop :: #force_inline proc(music: Music) {
	rl.StopMusicStream(music)
}

music_update :: #force_inline proc(music: Music) {
	if !MUSIC_ENABLED do return
	rl.UpdateMusicStream(music)
}

music_set_volume :: #force_inline proc(music: Music, volume: f32) {
	rl.SetMusicVolume(music, volume)
}
