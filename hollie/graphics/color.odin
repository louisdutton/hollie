package graphics

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
GOLD :: rl.GOLD
ORANGE :: rl.ORANGE
GRAY :: rl.GRAY
BROWN :: rl.BROWN

fade :: #force_inline proc(color: Colour, alpha: f32) -> Colour {
	return rl.Fade(color, alpha)
}
