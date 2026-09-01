package hollie

import "content"

enemy_spawn_kind_at :: proc(position: Vec2, kind: content.Character_Kind) {
	switch kind {
	case .GOBLIN: entity_create_enemy(position, goblin_animations[:])
	case .SKELETON: entity_create_enemy(position, skeleton_animations[:])
	case .HUMAN: entity_create_enemy(position, human_animations[:])
	}
}
