package hollie

import "content"

Enemy :: struct {
	using npc:    Npc,
	using combat: Combat,
}

enemy_create :: proc(position: Vec2, animations: []Animation) -> ^Enemy {
	enemy := Enemy {
		transform = {position = position},
		collider = model_character_collider(true),
		health = {current = 50, max = 50},
		movement = {move_speed = 50, roll_speed = 100, facing_direction = {1, 0}},
		combat = {damage = 15, range = 24, attack_width = 24, attack_height = 24},
	}
	if len(animations) > 0 do animation_init(&enemy.anim_data, animations)

	append(&entities, enemy)
	return &entities[len(entities) - 1].(Enemy)
}

enemy_spawn_kind_at :: proc(position: Vec2, kind: content.Character_Kind) {
	switch kind {
	case .Goblin: enemy_create(position, goblin_animations[:])
	case .Skeleton: enemy_create(position, skeleton_animations[:])
	case .Human: enemy_create(position, human_animations[:])
	}
}
