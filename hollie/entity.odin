package hollie

import "input"

// Specific entity types
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

// IDs are never reused during a world lifetime, including across room reloads.
Entity_Id :: distinct u64

World_State :: struct {
	entities:       [dynamic]Entity,
	next_entity_id: Entity_Id,
}

world: World_State

entity_add :: proc(new_entity: Entity, state: ^World_State) -> ^Entity {
	state.next_entity_id += 1
	assert(state.next_entity_id != 0, "entity ID space exhausted")
	value := new_entity
	switch &e in value {
	case Player: e.entity_id = state.next_entity_id
	case Enemy: e.entity_id = state.next_entity_id
	case Npc: e.entity_id = state.next_entity_id
	case Pressure_Plate: e.entity_id = state.next_entity_id
	case Gate: e.entity_id = state.next_entity_id
	case Holdable: e.entity_id = state.next_entity_id
	case Door: e.entity_id = state.next_entity_id
	}
	append(&state.entities, value)
	return &state.entities[len(state.entities) - 1]
}

entity_id :: proc(value: Entity) -> Entity_Id {
	switch e in value {
	case Player: return e.entity_id
	case Enemy: return e.entity_id
	case Npc: return e.entity_id
	case Pressure_Plate: return e.entity_id
	case Gate: return e.entity_id
	case Holdable: return e.entity_id
	case Door: return e.entity_id
	}
	return 0
}

// The result is borrowed only until the next add, remove, or room teardown.
entity_find :: proc(id: Entity_Id, state: ^World_State) -> ^Entity {
	if id == 0 do return nil
	for &value in state.entities {
		if entity_id(value) == id do return &value
	}
	return nil
}

entity_get_holdable :: proc(id: Entity_Id, state: ^World_State) -> ^Holdable {
	if value := entity_find(id, state); value != nil {
		if item, ok := &value^.(Holdable); ok do return item
	}
	return nil
}

entity_get_carrier :: proc(id: Entity_Id, state: ^World_State) -> ^Player {
	if value := entity_find(id, state); value != nil {
		if player, ok := &value^.(Player); ok do return player
	}
	return nil
}

entity_remove_at :: proc(index: int, state: ^World_State) {
	removed_id := entity_id(state.entities[index])
	for &value in state.entities {
		#partial switch &e in value {
		case Player: if e.carrying == removed_id do e.carrying = 0
		case Holdable: if e.held_by == removed_id {
					e.held_by = 0
					e.held_pose_valid = false
					e.grounded = false
				}
		}
	}
	entity_destroy(&state.entities[index])
	unordered_remove(&state.entities, index)
}

world_clear_entities :: proc(state: ^World_State) {
	for &value in state.entities do entity_destroy(&value)
	clear(&state.entities)
}

world_fini :: proc(state: ^World_State) {
	world_clear_entities(state)
	delete(state.entities)
	state.entities = nil
}

// Entity system functions
entity_system_init :: proc() {
	world.entities = make([dynamic]Entity)
}

entity_system_fini :: proc() {
	world_fini(&world)
}

entity_destroy :: proc(entity: ^Entity) {
	switch &e in entity {
	case Gate: delete(e.required_triggers)
	case Player, Enemy, Npc, Pressure_Plate, Holdable, Door: return
	}
}


entity_get_player :: proc(index: input.Player_Index, state: ^World_State) -> ^Player {
	for &entity in state.entities {
		if player, ok := &entity.(Player); ok && player.index == index {
			return player
		}
	}
	return nil
}


entity_cleanup_dead :: proc(state: ^World_State) {
	for i := len(state.entities) - 1; i >= 0; i -= 1 {
		switch &e in state.entities[i] {
		case Enemy: if e.is_dying && e.death_timer >= DEATH_DURATION {
					particle_create_explosion(e.position)
					entity_remove_at(i, state)
				}
		case Npc: if e.is_dying && e.death_timer >= DEATH_DURATION {
					particle_create_explosion(e.position)
					entity_remove_at(i, state)
				}
		case Player, Pressure_Plate, Gate, Holdable, Door: continue
		}
	}
}
