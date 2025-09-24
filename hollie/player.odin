package hollie

import "core:fmt"
import "core:math/linalg"
import "renderer"
import rl "vendor:raylib"

PLAYER_ANIM_COUNT :: 5
player_frame_counts := [PLAYER_ANIM_COUNT]int{9, 8, 9, 10, 10}
player_anim_files := [PLAYER_ANIM_COUNT]string {
	"res/art/characters/human/idle/base_idle_strip9.png",
	"res/art/characters/human/run/base_run_strip8.png",
	"res/art/characters/human/jump/base_jump_strip9.png",
	"res/art/characters/human/attack/base_attack_strip10.png",
	"res/art/characters/human/roll/base_roll_strip10.png",
}

// Player reference (now uses character system)
player: ^Character

player_set_spawn_position :: proc(spawn_pos: Vec2) {
	if player != nil {
		character_remove(player)
	}

	// Create player character with appropriate behaviors
	player_behaviors := Character_Behavior_Flags{.CAN_MOVE, .CAN_ATTACK, .CAN_ROLL, .CAN_INTERACT}

	player = character_create(
		spawn_pos,
		.PLAYER,
		player_behaviors,
		player_anim_files[:],
		player_frame_counts[:],
	)
}
