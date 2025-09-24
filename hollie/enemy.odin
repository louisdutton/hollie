package hollie

import "core:math/linalg"
import "core:math/rand"
import "renderer"
import rl "vendor:raylib"

ENEMY_ANIM_COUNT :: 3

enemy_frame_counts := [ENEMY_ANIM_COUNT]int{9, 8, 9}
enemy_anim_files := [ENEMY_ANIM_COUNT]string {
	"res/art/characters/goblin/png/spr_idle_strip9.png",
	"res/art/characters/goblin/png/spr_run_strip8.png",
	"res/art/characters/goblin/png/spr_jump_strip9.png",
}


enemy_spawn_at :: proc(position: Vec2) {
	// Create enemy character with appropriate behaviors
	enemy_behaviors := Character_Behavior_Flags{.CAN_MOVE, .HAS_AI, .IS_INTERACTABLE}

	character_create(position, .ENEMY, enemy_behaviors, enemy_anim_files[:], enemy_frame_counts[:])
}


// Legacy function - use character system instead
enemy_find_nearest :: proc(position: Vec2, max_distance: f32) -> (^Character, bool) {
	return character_find_nearest_of_type(position, .ENEMY, max_distance)
}
