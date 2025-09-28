package hollie

// Convenience function to spawn specific race
enemy_spawn_race_at :: proc(position: Vec2, race: Character_Tag) {
	if race == .GOBLIN {
		character_spawn(position, {.ENEMY, .GOBLIN, .CAN_MOVE, .HAS_AI})
	} else if race == .SKELETON {
		character_spawn(position, {.ENEMY, .SKELETON, .CAN_MOVE, .HAS_AI})
	} else if race == .HUMAN {
		character_spawn(position, {.NPC, .HUMAN, .CAN_MOVE, .HAS_AI, .IS_INTERACTABLE})
	}
}
