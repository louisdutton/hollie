package hollie

import "content"

Enemy :: struct {
	using transform: Transform,
	using collider:  Collider,
	using health:    Health,
	using movement:  Movement,
	using ai:        Ai,
	using anim_data: Animator,
	kind:            content.Character_Kind,
}

enemy_create :: proc(
	position: Vec2,
	animations: []Animation,
	kind: content.Character_Kind = .Goblin,
) -> ^Enemy {
	enemy := Enemy {
		transform = {position = position, grounded = true},
		collider = model_character_collider(true),
		health = {current = 50, max = 50},
		movement = {move_speed = 50, facing_direction = {1, 0}},
		kind = kind,
	}
	if animal := animal_model_for_kind(kind); animal != nil {
		enemy.collider = geometry_collider_from_bounds(
			animal.bounds,
			ANIMAL_MODEL_SCALE,
			true,
			true,
		)
	}
	if len(animations) > 0 do animation_init(&enemy.anim_data, animations)

	append(&entities, enemy)
	return &entities[len(entities) - 1].(Enemy)
}

enemy_spawn_kind_at :: proc(position: Vec2, kind: content.Character_Kind) {
	switch kind {
	case .Goblin: enemy_create(position, goblin_animations[:], kind)
	case .Skeleton: enemy_create(position, skeleton_animations[:], kind)
	case .Human: enemy_create(position, human_animations[:], kind)
	case .Dog, .Horse, .Bison:
		animations: [len(AnimationState)]Animation
		for &animation in animations do animation.frame_count = 1
		enemy_create(position, animations[:], kind)
	}
}
