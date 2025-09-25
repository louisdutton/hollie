package audio

import "core:math/rand"
import rl "vendor:raylib"

init :: proc() {
	rl.InitAudioDevice()
}

fini :: proc() {
	rl.CloseAudioDevice()
}
