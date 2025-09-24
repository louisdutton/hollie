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

// Using different human variations for variety (excluding base which is just the body)
human_variants := []string {
	"bowlhair",
	"curlyhair",
	"longhair",
	"mophair",
	"shorthair",
	"spikeyhair",
}
human_frame_counts := [ENEMY_ANIM_COUNT]int{9, 8, 9}

// Create composite human textures by combining base + hair variant (for NPCs - 3 animations)
create_composite_human_textures :: proc(variant: string) -> [ENEMY_ANIM_COUNT]rl.Texture2D {
	base_files := [ENEMY_ANIM_COUNT]string{
		"res/art/characters/human/idle/base_idle_strip9.png",
		"res/art/characters/human/run/base_run_strip8.png",
		"res/art/characters/human/jump/base_jump_strip9.png",
	}

	hair_files := [ENEMY_ANIM_COUNT]string{
		fmt.tprintf("res/art/characters/human/idle/%s_idle_strip9.png", variant),
		fmt.tprintf("res/art/characters/human/run/%s_run_strip8.png", variant),
		fmt.tprintf("res/art/characters/human/jump/%s_jump_strip9.png", variant),
	}

	composite_textures: [ENEMY_ANIM_COUNT]rl.Texture2D

	for i in 0..<ENEMY_ANIM_COUNT {
		// Load base and hair textures
		base_texture := rl.LoadTexture(cstring(raw_data(base_files[i])))
		hair_texture := rl.LoadTexture(cstring(raw_data(hair_files[i])))

		// Create render texture for compositing
		render_texture := rl.LoadRenderTexture(base_texture.width, base_texture.height)

		// Composite base + hair
		rl.BeginTextureMode(render_texture)
		rl.ClearBackground(rl.BLANK)
		rl.DrawTexture(base_texture, 0, 0, rl.WHITE)  // Draw base first
		rl.DrawTexture(hair_texture, 0, 0, rl.WHITE)  // Draw hair on top
		rl.EndTextureMode()

		// Store the composite texture (flip Y to fix upside-down rendering)
		flipped_texture := render_texture.texture
		flipped_texture.height = -flipped_texture.height  // Flip Y coordinate
		composite_textures[i] = flipped_texture

		// Clean up source textures
		rl.UnloadTexture(base_texture)
		rl.UnloadTexture(hair_texture)
		// Don't unload render_texture - we need it for the composite
	}

	return composite_textures
}

// Create composite human textures for player (5 animations including attack/roll)
create_composite_player_textures :: proc(variant: string) -> [5]rl.Texture2D {
	base_files := [5]string{
		"res/art/characters/human/idle/base_idle_strip9.png",
		"res/art/characters/human/run/base_run_strip8.png",
		"res/art/characters/human/jump/base_jump_strip9.png",
		"res/art/characters/human/attack/base_attack_strip10.png",
		"res/art/characters/human/roll/base_roll_strip10.png",
	}

	hair_files := [5]string{
		fmt.tprintf("res/art/characters/human/idle/%s_idle_strip9.png", variant),
		fmt.tprintf("res/art/characters/human/run/%s_run_strip8.png", variant),
		fmt.tprintf("res/art/characters/human/jump/%s_jump_strip9.png", variant),
		fmt.tprintf("res/art/characters/human/attack/%s_attack_strip10.png", variant),
		fmt.tprintf("res/art/characters/human/roll/%s_roll_strip10.png", variant),
	}

	composite_textures: [5]rl.Texture2D

	for i in 0..<5 {
		// Load base and hair textures
		base_texture := rl.LoadTexture(cstring(raw_data(base_files[i])))
		hair_texture := rl.LoadTexture(cstring(raw_data(hair_files[i])))

		// Create render texture for compositing
		render_texture := rl.LoadRenderTexture(base_texture.width, base_texture.height)

		// Composite base + hair
		rl.BeginTextureMode(render_texture)
		rl.ClearBackground(rl.BLANK)
		rl.DrawTexture(base_texture, 0, 0, rl.WHITE)  // Draw base first
		rl.DrawTexture(hair_texture, 0, 0, rl.WHITE)  // Draw hair on top
		rl.EndTextureMode()

		// Store the composite texture (flip Y to fix upside-down rendering)
		flipped_texture := render_texture.texture
		flipped_texture.height = -flipped_texture.height  // Flip Y coordinate
		composite_textures[i] = flipped_texture

		// Clean up source textures
		rl.UnloadTexture(base_texture)
		rl.UnloadTexture(hair_texture)
		// Don't unload render_texture - we need it for the composite
	}

	return composite_textures
}

enemy_spawn_at :: proc(position: Vec2) {
	// Randomly choose character race
	race_idx := rand.int31() % 3
	race := Character_Race(race_idx)

	switch race {
	case Character_Race.GOBLIN:
		// Goblins are always hostile enemies
		enemy_behaviors := Character_Behavior_Flags{.CAN_MOVE, .HAS_AI}
		character_create(
			position,
			.ENEMY,
			Character_Race.GOBLIN,
			enemy_behaviors,
			goblin_anim_files[:],
			goblin_frame_counts[:],
		)
	case Character_Race.SKELETON:
		// Skeletons are always hostile enemies
		enemy_behaviors := Character_Behavior_Flags{.CAN_MOVE, .HAS_AI}
		character_create(
			position,
			.ENEMY,
			Character_Race.SKELETON,
			enemy_behaviors,
			skeleton_anim_files[:],
			skeleton_frame_counts[:],
		)
	case Character_Race.HUMAN:
		// Humans are always friendly NPCs
		npc_behaviors := Character_Behavior_Flags{.CAN_MOVE, .HAS_AI, .IS_INTERACTABLE}

		// Randomly pick a human variant
		variant_idx := rand.int31() % i32(len(human_variants))
		variant := human_variants[variant_idx]

		// Create composite textures (base + hair)
		composite_textures := create_composite_human_textures(variant)

		character_create_with_textures(
			position,
			.NPC,  // Changed from .ENEMY to .NPC
			Character_Race.HUMAN,
			npc_behaviors,
			composite_textures[:],
			human_frame_counts[:],
		)
	}
}

// Convenience function to spawn specific race
enemy_spawn_race_at :: proc(position: Vec2, race: Character_Race) {
	switch race {
	case Character_Race.GOBLIN:
		// Goblins are always hostile enemies
		enemy_behaviors := Character_Behavior_Flags{.CAN_MOVE, .HAS_AI}
		character_create(
			position,
			.ENEMY,
			Character_Race.GOBLIN,
			enemy_behaviors,
			goblin_anim_files[:],
			goblin_frame_counts[:],
		)
	case Character_Race.SKELETON:
		// Skeletons are always hostile enemies
		enemy_behaviors := Character_Behavior_Flags{.CAN_MOVE, .HAS_AI}
		character_create(
			position,
			.ENEMY,
			Character_Race.SKELETON,
			enemy_behaviors,
			skeleton_anim_files[:],
			skeleton_frame_counts[:],
		)
	case Character_Race.HUMAN:
		// Humans are always friendly NPCs
		npc_behaviors := Character_Behavior_Flags{.CAN_MOVE, .HAS_AI, .IS_INTERACTABLE}
		variant_idx := rand.int31() % i32(len(human_variants))
		variant := human_variants[variant_idx]

		// Create composite textures (base + hair)
		composite_textures := create_composite_human_textures(variant)

		character_create_with_textures(
			position,
			.NPC,  // Changed from .ENEMY to .NPC
			Character_Race.HUMAN,
			npc_behaviors,
			composite_textures[:],
			human_frame_counts[:],
		)
	}
}
