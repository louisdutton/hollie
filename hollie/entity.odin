package hollie

import "input"

// Specific entity types
Player :: struct {
	using transform: Transform,
	using collider:  Collider,
	using health:    Health,
	using movement:  Movement,
	using combat:    Combat,
	using anim_data: Animator,
	index:           input.Player_Index,
	carrying:        ^Holdable,
}

Npc :: struct {
	using transform: Transform,
	using collider:  Collider,
	using health:    Health,
	using movement:  Movement,
	using ai:        Ai,
	using anim_data: Animator,
	dialog_messages: []Dialog_Message,
}

Enemy :: struct {
	using npc:    Npc,
	using combat: Combat,
}

Pressure_Plate :: struct {
	using transform: Transform,
	using collider:  Collider,
	trigger_id:      int,
	active:          bool,
	animation_time:  f32,
	activated_by:    bit_set[input.Player_Index],
	requires_both:   bool,
}

Gate :: struct {
	using transform:   Transform,
	using collider:    Collider,
	gate_id:           int,
	open:              bool,
	required_triggers: [dynamic]int,
	inverted:          bool,
}

Holdable :: struct {
	using transform: Transform,
	using collider:  Collider,
	held_by:         ^Player,
}

Door :: struct {
	using transform: Transform,
	using collider:  Collider,
	target_room:     string,
	target_door:     string,
}

// Main entity union
Entity :: union {
	Player,
	Enemy,
	Npc,
	Pressure_Plate,
	Gate,
	Holdable,
	Door,
}

// Global entity storage
entities: [dynamic]Entity

// Entity system functions
entity_system_init :: proc() {
	entities = make([dynamic]Entity)
}

entity_system_fini :: proc() {
	delete(entities)
}

// Create entities
entity_create_player :: proc(
	pos: Vec2,
	index: input.Player_Index,
	animations: []Animation,
) -> ^Player {
	player := Player {
		transform = {position = pos},
		collider = model_character_collider(true),
		health = {current = 100, max = 100, is_dying = false},
		movement = {move_speed = 80, roll_speed = 160, facing_direction = {1, 0}},
		combat = {damage = 25, range = 32, attack_width = 32, attack_height = 32},
		index = index,
	}

	if len(animations) > 0 {
		animation_init(&player.anim_data, animations)
	}

	append(&entities, player)
	return &entities[len(entities) - 1].(Player)
}

entity_create_enemy :: proc(pos: Vec2, animations: []Animation) -> ^Enemy {
	enemy := Enemy {
		transform = {position = pos},
		collider = model_character_collider(true),
		health = {current = 50, max = 50},
		movement = {move_speed = 50, roll_speed = 100, facing_direction = {1, 0}},
		combat = {damage = 15, range = 24, attack_width = 24, attack_height = 24},
	}

	if len(animations) > 0 {
		animation_init(&enemy.anim_data, animations)
	}

	append(&entities, enemy)
	return &entities[len(entities) - 1].(Enemy)
}

entity_create_pressure_plate :: proc(
	pos: Vec2,
	trigger_id: int,
	requires_both: bool = false,
) -> ^Pressure_Plate {
	plate := Pressure_Plate {
		transform = {position = pos},
		collider = model_pressure_pad_collider(false),
		trigger_id = trigger_id,
		requires_both = requires_both,
		animation_time = 1e9,
	}

	append(&entities, plate)
	return &entities[len(entities) - 1].(Pressure_Plate)
}

entity_create_gate :: proc(pos: Vec2, size: Vec2, gate_id: int, inverted: bool = false) -> ^Gate {
	gate := Gate {
		transform = {position = pos},
		collider = {size = size, height = RENDERING_GATE_HEIGHT, solid = true},
		gate_id = gate_id,
		required_triggers = make([dynamic]int),
		inverted = inverted,
	}

	append(&entities, gate)
	return &entities[len(entities) - 1].(Gate)
}

entity_create_npc :: proc(
	pos: Vec2,
	animations: []Animation,
	dialog_messages: []Dialog_Message = {},
) -> ^Npc {
	npc := Npc {
		transform = {position = pos},
		collider = model_character_collider(true),
		health = {current = 50, max = 50},
		movement = {move_speed = 30, facing_direction = {1, 0}},
		dialog_messages = dialog_messages,
	}

	if len(animations) > 0 {
		animation_init(&npc.anim_data, animations)
	}

	append(&entities, npc)
	return &entities[len(entities) - 1].(Npc)
}

entity_create_holdable :: proc(pos: Vec2) -> ^Holdable {
	holdable := Holdable {
		transform = {position = pos},
		collider = model_crate_collider(true),
	}

	append(&entities, holdable)
	return &entities[len(entities) - 1].(Holdable)
}

entity_create_door :: proc(
	pos: Vec2,
	size: Vec2,
	target_room: string,
	target_door: string,
) -> ^Door {
	door := Door {
		transform = {position = pos},
		collider = {size = size, solid = false},
		target_room = target_room,
		target_door = target_door,
	}

	append(&entities, door)
	return &entities[len(entities) - 1].(Door)
}

// Query functions
entity_get_players :: proc() -> [dynamic]^Player {
	players := make([dynamic]^Player)
	for &entity in entities {
		if player, ok := &entity.(Player); ok {
			append(&players, player)
		}
	}
	return players
}

entity_get_player :: proc(index: input.Player_Index) -> ^Player {
	for &entity in entities {
		if player, ok := &entity.(Player); ok && player.index == index {
			return player
		}
	}
	return nil
}

entity_get_pressure_plates :: proc() -> [dynamic]^Pressure_Plate {
	plates := make([dynamic]^Pressure_Plate)
	for &entity in entities {
		if plate, ok := &entity.(Pressure_Plate); ok {
			append(&plates, plate)
		}
	}
	return plates
}

entity_get_gates :: proc() -> [dynamic]^Gate {
	gates := make([dynamic]^Gate)
	for &entity in entities {
		if gate, ok := &entity.(Gate); ok {
			append(&gates, gate)
		}
	}
	return gates
}

entity_get_holdables :: proc() -> [dynamic]^Holdable {
	holdables := make([dynamic]^Holdable)
	for &entity in entities {
		if holdable, ok := &entity.(Holdable); ok {
			append(&holdables, holdable)
		}
	}
	return holdables
}

entity_get_doors :: proc() -> [dynamic]^Door {
	doors := make([dynamic]^Door)
	for &entity in entities {
		if door, ok := &entity.(Door); ok {
			append(&doors, door)
		}
	}
	return doors
}

// Update systems
entity_system_update :: proc() {
	player_update_input()
	combat_update_timers()
	player_update_movement()
	ai_update_movement()
	movement_update_positions()
	combat_update()
	puzzle_update()
	animation_update_entities()
	entity_cleanup_dead()
}

entity_cleanup_dead :: proc() {
	for i := len(entities) - 1; i >= 0; i -= 1 {
		switch &e in entities[i] {
		case Enemy: if e.is_dying && e.death_timer >= 13 * INTERVAL {
					particle_create_explosion(e.position)
					unordered_remove(&entities, i)
				}
		case Npc: if e.is_dying && e.death_timer >= 13 * INTERVAL {
					particle_create_explosion(e.position)
					unordered_remove(&entities, i)
				}
		case Player, Pressure_Plate, Gate, Holdable, Door: continue
		}
	}
}
