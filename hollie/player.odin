package hollie

import "core:fmt"
import "core:math/linalg"
import "renderer"
import rl "vendor:raylib"

MOVE_SPEED :: 1.5
ROLL_SPEED :: 3.0
ANIM_COUNT :: 5

// Player state
player := struct {
	position:     Vec2,
	width:        u32,
	height:       u32,
	velocity:     Vec2,
	color:        rl.Color,
	anim_data:    Animator,
	is_attacking: bool,
	attack_timer: u32,
	is_rolling:   bool,
	roll_timer:   u32,
	is_flipped:   bool, // Persistent sprite flip state
} {
	position = {256, 256},
	width    = 16,
	height   = 16,
	velocity = {0, 0},
	color    = rl.WHITE,
}


player_frame_counts := [ANIM_COUNT]int{9, 8, 9, 10, 10}
player_anim_files := [ANIM_COUNT]string {
	"res/art/characters/human/idle/base_idle_strip9.png",
	"res/art/characters/human/run/base_run_strip8.png",
	"res/art/characters/human/jump/base_jump_strip9.png",
	"res/art/characters/human/attack/base_attack_strip10.png",
	"res/art/characters/human/roll/base_roll_strip10.png",
}

calc_velocity :: proc() {
	if dialog_is_active() {
		player.velocity = {0, 0}
		return
	}

	if player.is_rolling do return

	input := input_get_movement()
	player.velocity.x = input.x * MOVE_SPEED
	player.velocity.y = input.y * MOVE_SPEED

	// Update sprite flip state when moving horizontally
	if abs(input.x) > 0 {
		player.is_flipped = input.x < 0
	}
}

calc_state :: proc() {
	if player.is_rolling {
		animation_set_state(&player.anim_data, .ROLL, player.is_flipped)
	} else if player.is_attacking {
		animation_set_state(&player.anim_data, .ATTACK, player.is_flipped)
	} else if player.velocity.x != 0 || player.velocity.y != 0 {
		animation_set_state(&player.anim_data, .RUN, player.is_flipped)
	} else {
		animation_set_state(&player.anim_data, .IDLE, player.is_flipped)
	}
}

move_and_collide :: proc() {
	player.position.x += player.velocity.x
	player.position.y += player.velocity.y
}


// FIXME: get this working in stack memory
enemy_messages := []Dialog_Message {
	{text = "Grr! What do you want, human?", speaker = "Goblin"},
	{text = "I'm just passing through.", speaker = "Hollie"},
	{text = "Well then, be on your way!", speaker = "Goblin"},
}

player_handle_input :: proc() {
	if dialog_is_active() do return

	if input_pressed(.Accept) {
		// Try to interact with nearby enemy
		INTERACTION_RANGE :: 40.0
		enemy, found := enemy_find_nearest(player.position, INTERACTION_RANGE)

		if found {
			enemy.busy = true
			dialog_start(enemy_messages)
			return
		}
	}

	if input_pressed(.Attack) && !player.is_attacking && !player.is_rolling {
		player.is_attacking = true
		player.attack_timer = 0
	}

	if input_pressed(.Roll) && !player.is_rolling && !player.is_attacking {
		// Lock current velocity for roll (only roll if moving)
		if linalg.length(player.velocity) > 0 {
			player.velocity = linalg.normalize(player.velocity) * ROLL_SPEED
			player.is_rolling = true
			player.roll_timer = 0
		}
	}
}


player_update :: proc() {
	player_handle_input()
	calc_velocity()
	calc_state()

	// attack timer
	// TODO this can possibly be a tween
	if player.is_attacking {
		player.attack_timer += 1
		// Attack animation duration: 10 frames * INTERVAL
		if player.attack_timer >= 10 * INTERVAL {
			player.is_attacking = false
			player.attack_timer = 0
		}
	}

	// roll timer
	if player.is_rolling {
		player.roll_timer += 1
		// Roll animation duration: 10 frames * INTERVAL
		if player.roll_timer >= 10 * INTERVAL {
			player.is_rolling = false
			player.roll_timer = 0
		}
	}

	move_and_collide()
	animation_update(&player.anim_data)
}

draw_bounds :: proc() {
	x := player.position.x - f32(player.width) / 2
	y := player.position.y - f32(player.height) / 2
	renderer.draw_rect_outline(x, y, f32(player.width), f32(player.height), 1)
}

player_draw :: proc() {
	animation_draw(&player.anim_data, player.position, player.color)

	// player debug info
	when ODIN_DEBUG {
		draw_bounds()
		using player.anim_data
		debug_text := fmt.tprint(current_anim)
		renderer.draw_text(
			debug_text,
			int(player.position.x) - 10,
			int(player.position.y) - 20,
			size = 8,
		)
	}
}

player_set_spawn_position :: proc(spawn_pos: Vec2) {
	player.position = spawn_pos
	animation_init(&player.anim_data, player_anim_files[:], player_frame_counts[:])
}
