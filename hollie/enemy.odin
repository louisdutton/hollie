package hollie

NPC_Race :: enum {
	GOBLIN,
	SKELETON,
	HUMAN,
}


// Convenience function to spawn specific race
enemy_spawn_race_at :: proc(position: Vec2, race: NPC_Race) {
	switch race {
	case .GOBLIN: entity_create_enemy(position, goblin_animations[:])
	case .SKELETON: entity_create_enemy(position, skeleton_animations[:])
	case .HUMAN: entity_create_enemy(position, human_animations[:])
	}
}
