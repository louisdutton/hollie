package hollie

import "content"

enemy_spawn_kind_at :: proc(position: Vec2, kind: content.Character_Kind) {
	switch kind {
	case .Goblin: entity_create_enemy(position, goblin_animations[:])
	case .Skeleton: entity_create_enemy(position, skeleton_animations[:])
	case .Human: entity_create_enemy(position, human_animations[:])
	}
}
