package hollie


PLAYER_ANIM_COUNT :: 6
player_frame_counts := [PLAYER_ANIM_COUNT]int{9, 8, 9, 13, 10, 10}
player_anim_files := [PLAYER_ANIM_COUNT]string {
	asset_path("art/characters/human/idle/base_idle_strip9.png"),
	asset_path("art/characters/human/run/base_run_strip8.png"),
	asset_path("art/characters/human/jump/base_jump_strip9.png"),
	asset_path("art/characters/human/death/base_death_strip13.png"),
	asset_path("art/characters/human/attack/base_attack_strip10.png"),
	asset_path("art/characters/human/roll/base_roll_strip10.png"),
}

// Player reference (now uses character system)
player: ^Character


player_set_spawn_position :: proc(spawn_pos: Vec2) {
	if player != nil {
		character_remove(player)
	}

	// Create player character with appropriate behaviors
	player_behaviors := Character_Behavior_Flags{.CAN_MOVE, .CAN_ATTACK, .CAN_ROLL, .CAN_INTERACT}

	// Create composite textures (base + hair) - using longhair for player
	composite_textures := create_composite_player_textures("longhair")

	player = character_create_with_textures(
		spawn_pos,
		.PLAYER,
		Character_Race.HUMAN,
		player_behaviors,
		composite_textures[:],
		player_frame_counts[:],
	)
}
