package hollie

import "core:math/linalg"
import rl "vendor:raylib"

ENEMY_MOVE_SPEED :: 2

// Animation constants
ENEMY_TARGET_FPS :: 60
ENEMY_FPS :: 24
ENEMY_INTERVAL :: TARGET_FPS / FPS
ENEMY_FRAME_WIDTH :: 96
ENEMY_FRAME_HEIGHT :: 64
ENEMY_ANIM_COUNT :: 3

EnemyState :: enum {
	IDLE,
	RUN,
	JUMP,
}

Enemy :: struct {
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
	current_anim:  EnemyState,
	is_flipped:    bool,
}

// enemy state
enemy := Enemy {
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

enemy_anim_files := [ANIM_COUNT]string {
	"res/art/characters/goblin/png/spr_idle_strip9.png",
	"res/art/characters/goblin/png/spr_run_strip8.png",
	"res/art/characters/goblin/png/spr_jump_strip9.png",
}

enemy_calc_velocity :: proc() {
	// input := rl.Vector2 {
	// 	f32(int(rl.IsKeyDown(.D)) - int(rl.IsKeyDown(.A))),
	// 	f32(int(rl.IsKeyDown(.S)) - int(rl.IsKeyDown(.W))),
	// }
	// input = rl.Vector2Normalize(input)
	// enemy.velocity.x = input.x * MOVE_SPEED
	// enemy.velocity.y = input.y * MOVE_SPEED

	enemy.velocity = {0, 0}
}

enemy_calc_state :: proc() {
	if enemy.velocity.x != 0 || enemy.velocity.y != 0 {
		enemy.current_anim = .RUN
		enemy.is_flipped = enemy.velocity.x < 0
	} else {
		enemy.current_anim = .IDLE
	}
}

enemy_move_and_collide :: proc() {
	enemy.position.x += enemy.velocity.x
	enemy.position.y += enemy.velocity.y
}

enemy_animate :: proc() {
	enemy.frame_counter += 1

	if enemy.frame_counter > INTERVAL {
		enemy.frame_counter = 0
		enemy.frame += 1
		if int(enemy.frame) > enemy.frame_counts[enemy.current_anim] {
			enemy.frame = 0
		}
		enemy.rect.x = f32(enemy.frame) * f32(FRAME_WIDTH)
	}
}

enemy_draw_bounds :: proc() {
	x := enemy.position.x - f32(enemy.width) / 2
	y := enemy.position.y - f32(enemy.height) / 2
	rl.DrawRectangleLines(i32(x), i32(y), i32(enemy.width), i32(enemy.height), rl.RED)
}

enemy_draw_sprite :: proc() {
	tex_pos := enemy.position
	tex_pos.x -= f32(FRAME_WIDTH) / 2
	tex_pos.y -= f32(FRAME_HEIGHT) / 2
	tex_rect := enemy.rect
	if enemy.is_flipped {
		tex_rect.width *= -1
	}
	rl.DrawTextureRec(enemy.animations[enemy.current_anim], tex_rect, tex_pos, enemy.color)
}

enemy_init :: proc() {
	for file, i in enemy_anim_files {
		enemy.animations[i] = rl.LoadTexture(cstring(raw_data(file)))
	}
}

enemy_update :: proc() {
	enemy_calc_velocity()
	enemy_calc_state()
	enemy_move_and_collide()
	enemy_animate()
}

enemy_draw :: proc() {
	// draw_bounds()
	enemy_draw_sprite()
}

enemy_fini :: proc() {
	for i in 0 ..< ANIM_COUNT {
		rl.UnloadTexture(enemy.animations[i])
	}
}
