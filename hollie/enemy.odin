package hollie

import "core:math/linalg"
import rl "vendor:raylib"

ENEMY_MOVE_SPEED :: 2
ENEMY_ANIM_COUNT :: 3

Enemy :: struct {
	position:  rl.Vector2,
	width:     u32,
	height:    u32,
	velocity:  rl.Vector2,
	color:     rl.Color,
	anim_data: Animation,
}

// enemy state
enemy := Enemy {
	position = {0, 0},
	width    = 16,
	height   = 16,
	velocity = {0, 0},
	color    = rl.WHITE,
}

enemy_frame_counts := [ENEMY_ANIM_COUNT]int{9, 8, 9}
enemy_anim_files := [ENEMY_ANIM_COUNT]string {
	"res/art/characters/goblin/png/spr_idle_strip9.png",
	"res/art/characters/goblin/png/spr_run_strip8.png",
	"res/art/characters/goblin/png/spr_jump_strip9.png",
}

enemy_calc_velocity :: proc() {
	// TODO
	enemy.velocity = {0, 0}
}

enemy_calc_state :: proc() {
	if enemy.velocity.x != 0 || enemy.velocity.y != 0 {
		animation_set_state(&enemy.anim_data, .RUN, enemy.velocity.x < 0)
	} else {
		animation_set_state(&enemy.anim_data, .IDLE, false)
	}
}

enemy_move_and_collide :: proc() {
	enemy.position.x += enemy.velocity.x
	enemy.position.y += enemy.velocity.y
}

enemy_animate :: proc() {
	animation_update(&enemy.anim_data)
}

enemy_draw_bounds :: proc() {
	x := enemy.position.x - f32(enemy.width) / 2
	y := enemy.position.y - f32(enemy.height) / 2
	rl.DrawRectangleLines(i32(x), i32(y), i32(enemy.width), i32(enemy.height), rl.RED)
}

enemy_draw_sprite :: proc() {
	animation_draw(&enemy.anim_data, enemy.position, enemy.color)
}

enemy_init :: proc() {
	animation_init(&enemy.anim_data, enemy_anim_files[:], enemy_frame_counts[:])
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
	animation_fini(&enemy.anim_data)
}
