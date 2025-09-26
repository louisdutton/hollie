package audio

import rl "vendor:raylib"

init :: proc() {
	rl.InitAudioDevice()
}

fini :: proc() {
	rl.CloseAudioDevice()
}
