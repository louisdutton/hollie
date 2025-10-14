package renderer

import rl "vendor:raylib"

WHITE :: rl.WHITE
BLACK :: rl.BLACK
RED :: rl.RED
GREEN :: rl.GREEN
BLUE :: rl.BLUE
YELLOW :: rl.YELLOW
SKYBLUE :: rl.SKYBLUE
DARKGREEN :: rl.DARKGREEN
BLANK :: rl.BLANK
PURPLE :: rl.PURPLE

fade :: #force_inline proc(color: Colour, alpha: f32) -> Colour {
	return rl.Fade(color, alpha)
}
