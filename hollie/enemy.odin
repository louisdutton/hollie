package hollie

import "content"
import "input"

Enemy :: struct {
	using transform: Transform,
	using collider:  Collider,
	using health:    Health,
	using movement:  Movement,
	using ai:        Ai,
	using anim_data: Animator,
	kind:            content.Character_Kind,
	mounted:         bool,
	coasting:        bool,
	ram_ready:       bool,
	ram_charge_time: f32,
	ram_visual:      f32,
	rider:           input.Player_Index,
	turn_lean:       f32,
	head_turn:       f32,
	gait_phase:      f32,
}

enemy_create :: proc(position: Vec2, kind: content.Character_Kind = .Goblin) -> ^Enemy {
	enemy := Enemy {
		transform = {position = position, grounded = true},
		collider = model_character_collider(true),
		health = {current = 50, max = 50},
		movement = {move_speed = 50, facing_direction = {1, 0}},
		kind = kind,
	}
	if animal := animal_model_for_kind(kind); animal != nil {
		enemy.collider = animal_collider_from_bounds(animal.bounds, enemy.facing_direction)
	}
	animation_init(&enemy.anim_data)
	// Spawn at the surface and let displacement and drag establish the draft.
	if water_at(position) do enemy.height = WATER_SURFACE

	value := entity_add(enemy, &world)
	return &value^.(Enemy)
}

enemy_spawn_kind_at :: proc(position: Vec2, kind: content.Character_Kind) {
	enemy_create(position, kind)
}
