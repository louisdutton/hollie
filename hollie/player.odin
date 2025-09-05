package hollie

import "core:math/linalg"
import rl "vendor:raylib"

MOVE_SPEED :: 2

// Animation constants
TARGET_FPS :: 60
FPS :: 24
INTERVAL :: TARGET_FPS / FPS
FRAME_WIDTH :: 96
FRAME_HEIGHT :: 64
ANIM_COUNT :: 3

PlayerState :: enum {
	IDLE,
	RUN,
	JUMP,
}

// Player state
player := struct {
	position:      rl.Vector2,
	width:         u32,
	height:        u32,
	velocity:      rl.Vector2,
	color:         rl.Color,
	rect:          rl.Rectangle,

	// Animation
	animations:    [ANIM_COUNT]rl.Texture2D,
	frame_counts:  [ANIM_COUNT]int,
	frame_counter: u32,
	frame:         u32,
	current_anim:  PlayerState,
	is_flipped:    bool,
} {
	position      = {0, 0},
	width         = 16,
	height        = 16,
	velocity      = {0, 0},
	color         = rl.WHITE,
	rect          = {0, 0, FRAME_WIDTH, FRAME_HEIGHT},
	frame_counts  = {9, 8, 9},
	frame_counter = 0,
	frame         = 0,
	current_anim  = .IDLE,
	is_flipped    = false,
}

anim_files := [ANIM_COUNT]string {
	"res/art/characters/human/idle/base_idle_strip9.png",
	"res/art/characters/human/run/base_run_strip8.png",
	"res/art/characters/human/jump/base_jump_strip9.png",
}

calc_velocity :: proc() {
	input := rl.Vector2 {
		f32(int(rl.IsKeyDown(.D)) - int(rl.IsKeyDown(.A))),
		f32(int(rl.IsKeyDown(.S)) - int(rl.IsKeyDown(.W))),
	}
	input = rl.Vector2Normalize(input)
	player.velocity.x = input.x * MOVE_SPEED
	player.velocity.y = input.y * MOVE_SPEED
}

calc_state :: proc() {
	if player.velocity.x != 0 || player.velocity.y != 0 {
		player.current_anim = .RUN
		player.is_flipped = player.velocity.x < 0
	} else {
		player.current_anim = .IDLE
	}
}

move_and_collide :: proc() {
	player.position.x += player.velocity.x
	player.position.y += player.velocity.y
}

animate :: proc() {
	player.frame_counter += 1

	if player.frame_counter > INTERVAL {
		player.frame_counter = 0
		player.frame += 1
		if int(player.frame) > player.frame_counts[player.current_anim] {
			player.frame = 0
		}
		player.rect.x = f32(player.frame) * f32(FRAME_WIDTH)
	}
}

draw_bounds :: proc() {
	x := player.position.x - f32(player.width) / 2
	y := player.position.y - f32(player.height) / 2
	rl.DrawRectangleLines(i32(x), i32(y), i32(player.width), i32(player.height), rl.WHITE)
}

draw_sprite :: proc() {
	tex_pos := player.position
	tex_pos.x -= f32(FRAME_WIDTH) / 2
	tex_pos.y -= f32(FRAME_HEIGHT) / 2
	tex_rect := player.rect
	if player.is_flipped {
		tex_rect.width *= -1
	}
	rl.DrawTextureRec(player.animations[player.current_anim], tex_rect, tex_pos, player.color)
}

player_init :: proc() {
	for file, i in anim_files {
		player.animations[i] = rl.LoadTexture(cstring(raw_data(file)))
	}
}

player_update :: proc() {
	calc_velocity()
	calc_state()
	move_and_collide()
	animate()
}

player_draw :: proc() {
	// draw_bounds()
	draw_sprite()
}

player_fini :: proc() {
	for i in 0 ..< ANIM_COUNT {
		rl.UnloadTexture(player.animations[i])
	}
}
