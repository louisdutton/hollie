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

// Global entity storage
entities: [dynamic]Entity

// Entity system functions
entity_system_init :: proc() {
	entities = make([dynamic]Entity)
}

entity_system_fini :: proc() {
	entity_destroy_all()
	delete(entities)
}

entity_destroy :: proc(entity: ^Entity) {
	switch &e in entity {
	case Player: animation_fini(&e.anim_data)
	case Enemy: animation_fini(&e.anim_data)
	case Npc: animation_fini(&e.anim_data)
	case Gate: delete(e.required_triggers)
	case Pressure_Plate, Holdable, Door: return
	}
}

entity_destroy_all :: proc() {
	for &entity in entities {
		entity_destroy(&entity)
	}
	clear(&entities)
}

entity_get_player :: proc(index: input.Player_Index) -> ^Player {
	for &entity in entities {
		if player, ok := &entity.(Player); ok && player.index == index {
			return player
		}
	}
	return nil
}

// Update systems
entity_system_update :: proc() {
	pressure_plate_update_surfaces()
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
					entity_destroy(&entities[i])
					unordered_remove(&entities, i)
				}
		case Npc: if e.is_dying && e.death_timer >= 13 * INTERVAL {
					particle_create_explosion(e.position)
					entity_destroy(&entities[i])
					unordered_remove(&entities, i)
				}
		case Player, Pressure_Plate, Gate, Holdable, Door: continue
		}
	}
}
