package hollie

import "core:math/linalg"
import rl "vendor:raylib"

MOVE_SPEED :: 2
ANIM_COUNT :: 3

// Player state
player := struct {
	position:  rl.Vector2,
	width:     u32,
	height:    u32,
	velocity:  rl.Vector2,
	color:     rl.Color,
	anim_data: Animation,
} {
	position = {0, 0},
	width    = 16,
	height   = 16,
	velocity = {0, 0},
	color    = rl.WHITE,
}


player_frame_counts := [ANIM_COUNT]int{9, 8, 9}
player_anim_files := [ANIM_COUNT]string {
	"res/art/characters/human/idle/base_idle_strip9.png",
	"res/art/characters/human/run/base_run_strip8.png",
	"res/art/characters/human/jump/base_jump_strip9.png",
}

calc_velocity :: proc() {
	input := input_get_movement()
	player.velocity.x = input.x * MOVE_SPEED
	player.velocity.y = input.y * MOVE_SPEED
}

calc_state :: proc() {
	if player.velocity.x != 0 || player.velocity.y != 0 {
		animation_set_state(&player.anim_data, .RUN, player.velocity.x < 0)
	} else {
		animation_set_state(&player.anim_data, .IDLE, false)
	}
}

move_and_collide :: proc() {
	player.position.x += player.velocity.x
	player.position.y += player.velocity.y
}

animate :: proc() {
	animation_update(&player.anim_data)
}

draw_bounds :: proc() {
	x := player.position.x - f32(player.width) / 2
	y := player.position.y - f32(player.height) / 2
	rl.DrawRectangleLines(i32(x), i32(y), i32(player.width), i32(player.height), rl.WHITE)
}

draw_sprite :: proc() {
	animation_draw(&player.anim_data, player.position, player.color)
}

player_init :: proc() {
	animation_init(&player.anim_data, player_anim_files[:], player_frame_counts[:])
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
	animation_fini(&player.anim_data)
}
