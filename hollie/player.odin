package hollie

import "core:math/linalg"
import rl "vendor:raylib"

MOVE_SPEED :: 1.5
ANIM_COUNT :: 4

// Player state
player := struct {
	position:       Vec2,
	width:          u32,
	height:         u32,
	velocity:       Vec2,
	color:          rl.Color,
	anim_data:      Animator,
	is_attacking:   bool,
	attack_timer:   u32,
	last_direction: Vec2, // Last movement direction with magnitude
} {
	position = {256, 256},
	width    = 16,
	height   = 16,
	velocity = {0, 0},
	color    = rl.WHITE,
}


player_frame_counts := [ANIM_COUNT]int{9, 8, 9, 10}
player_anim_files := [ANIM_COUNT]string {
	"res/art/characters/human/idle/base_idle_strip9.png",
	"res/art/characters/human/run/base_run_strip8.png",
	"res/art/characters/human/jump/base_jump_strip9.png",
	"res/art/characters/human/attack/base_attack_strip10.png",
}

calc_velocity :: proc() {
	input := input_get_movement()
	player.velocity.x = input.x * MOVE_SPEED
	player.velocity.y = input.y * MOVE_SPEED

	// Update last direction only when there's meaningful movement
	if linalg.length(player.velocity) > 0 {
		player.last_direction = player.velocity
	}
}

calc_state :: proc() {
	is_flipped := player.last_direction.x < 0

	if player.is_attacking {
		animation_set_state(&player.anim_data, .ATTACK, is_flipped)
	} else if player.velocity.x != 0 || player.velocity.y != 0 {
		animation_set_state(&player.anim_data, .RUN, is_flipped)
	} else {
		animation_set_state(&player.anim_data, .IDLE, is_flipped)
	}
}

move_and_collide :: proc() {
	player.position.x += player.velocity.x
	player.position.y += player.velocity.y
}

handle_attack :: proc() {
	if input_get_attack() && !player.is_attacking {
		player.is_attacking = true
		player.attack_timer = 0
	}

	if player.is_attacking {
		player.attack_timer += 1
		// Attack animation duration: 10 frames * INTERVAL
		if player.attack_timer >= 10 * INTERVAL {
			player.is_attacking = false
			player.attack_timer = 0
		}
	}
}

draw_bounds :: proc() {
	x := player.position.x - f32(player.width) / 2
	y := player.position.y - f32(player.height) / 2
	rl.DrawRectangleLines(i32(x), i32(y), i32(player.width), i32(player.height), rl.WHITE)
}

player_update :: proc() {
	handle_attack()
	calc_velocity()
	calc_state()
	move_and_collide()
	animation_update(&player.anim_data)
}

player_draw :: proc() {
	// draw_bounds()
	animation_draw(&player.anim_data, player.position, player.color)
}

player_set_spawn_position :: proc(spawn_pos: Vec2) {
	player.position = spawn_pos
	animation_init(&player.anim_data, player_anim_files[:], player_frame_counts[:])
}
