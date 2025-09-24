package hollie

import "core:fmt"
import "core:math/linalg"
import "core:math/rand"
import "renderer"
import rl "vendor:raylib"

ENEMY_ANIM_COUNT :: 3

// Character race/type for NPCs and enemies
Character_Race :: enum {
	GOBLIN,
	SKELETON,
	HUMAN,
}

// Animation data for different races
goblin_frame_counts := [ENEMY_ANIM_COUNT]int{9, 8, 9}
goblin_anim_files := [ENEMY_ANIM_COUNT]string {
	"res/art/characters/goblin/png/spr_idle_strip9.png",
	"res/art/characters/goblin/png/spr_run_strip8.png",
	"res/art/characters/goblin/png/spr_jump_strip9.png",
}

skeleton_frame_counts := [ENEMY_ANIM_COUNT]int{6, 8, 10}
skeleton_anim_files := [ENEMY_ANIM_COUNT]string {
	"res/art/characters/skeleton/png/skeleton_idle_strip6.png",
	"res/art/characters/skeleton/png/skeleton_walk_strip8.png",
	"res/art/characters/skeleton/png/skeleton_jump_strip10.png",
}

// Using different human variations for variety
human_variants := []string {
	"base",
	"bowlhair",
	"curlyhair",
	"longhair",
	"mophair",
	"shorthair",
	"spikeyhair",
}
human_frame_counts := [ENEMY_ANIM_COUNT]int{9, 8, 9}

// Generate human animation files for a specific variant
get_human_anim_files :: proc(variant: string) -> [ENEMY_ANIM_COUNT]string {
	return {
		fmt.tprintf("res/art/characters/human/idle/%s_idle_strip9.png", variant),
		fmt.tprintf("res/art/characters/human/run/%s_run_strip8.png", variant),
		fmt.tprintf("res/art/characters/human/jump/%s_jump_strip9.png", variant),
	}
}

enemy_spawn_at :: proc(position: Vec2) {
	// Randomly choose character race
	race_idx := rand.int31() % 3
	race := Character_Race(race_idx)

	// Create enemy character with appropriate behaviors
	enemy_behaviors := Character_Behavior_Flags{.CAN_MOVE, .HAS_AI, .IS_INTERACTABLE}

	switch race {
	case Character_Race.GOBLIN:
		character_create(
			position,
			.ENEMY,
			Character_Race.GOBLIN,
			enemy_behaviors,
			goblin_anim_files[:],
			goblin_frame_counts[:],
		)
	case Character_Race.SKELETON:
		character_create(
			position,
			.ENEMY,
			Character_Race.SKELETON,
			enemy_behaviors,
			skeleton_anim_files[:],
			skeleton_frame_counts[:],
		)
	case Character_Race.HUMAN:
		// Randomly pick a human variant
		variant_idx := rand.int31() % i32(len(human_variants))
		variant := human_variants[variant_idx]
		human_files := get_human_anim_files(variant)
		character_create(
			position,
			.ENEMY,
			Character_Race.HUMAN,
			enemy_behaviors,
			human_files[:],
			human_frame_counts[:],
		)
	}
}

// Convenience function to spawn specific race
enemy_spawn_race_at :: proc(position: Vec2, race: Character_Race) {
	enemy_behaviors := Character_Behavior_Flags{.CAN_MOVE, .HAS_AI, .IS_INTERACTABLE}

	switch race {
	case Character_Race.GOBLIN:
		character_create(
			position,
			.ENEMY,
			Character_Race.GOBLIN,
			enemy_behaviors,
			goblin_anim_files[:],
			goblin_frame_counts[:],
		)
	case Character_Race.SKELETON:
		character_create(
			position,
			.ENEMY,
			Character_Race.SKELETON,
			enemy_behaviors,
			skeleton_anim_files[:],
			skeleton_frame_counts[:],
		)
	case Character_Race.HUMAN:
		variant_idx := rand.int31() % i32(len(human_variants))
		variant := human_variants[variant_idx]
		human_files := get_human_anim_files(variant)
		character_create(
			position,
			.ENEMY,
			Character_Race.HUMAN,
			enemy_behaviors,
			human_files[:],
			human_frame_counts[:],
		)
	}
}
