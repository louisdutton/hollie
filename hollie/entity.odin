package hollie

import "audio"
import "core:math"
import "core:math/rand"
import "input"
import "renderer"
import "tilemap"
import rl "vendor:raylib"

// Common components that can be reused
Health :: struct {
	current:         i32,
	max:             i32,
	is_dying:        bool,
	death_timer:     u32,
	hit_flash_timer: f32,
	knockback_timer: f32,
}

Combat :: struct {
	damage:           i32,
	range:            f32,
	attack_width:     f32,
	attack_height:    f32,
	is_attacking:     bool,
	attack_timer:     u32,
	attack_hit:       bool,
	attack_direction: Vec2,
}

Ai :: struct {
	wait_timer:     f32,
	move_timer:     f32,
	move_direction: Vec2,
}

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
	entity_handle_input()
	entity_update_timers()
	entity_update_movement()
	entity_update_positions()
	entity_check_combat()
	entity_update_puzzle_logic()
	entity_update_animations()
	entity_cleanup_dead()
}

entity_handle_input :: proc() {
	for &entity in entities {
		#partial switch &e in entity {
		case Player: player_handle_input(&e)
		}
	}
}

entity_update_timers :: proc() {
	dt := rl.GetFrameTime()

	for &entity in entities {
		switch &e in entity {
		case Player:
			// Update attack timer
			if e.is_attacking {
				e.attack_timer += 1
				// Attack duration: 10 frames * INTERVAL
				if e.attack_timer >= 10 * INTERVAL {
					e.is_attacking = false
					e.attack_timer = 0
					e.attack_hit = false
				}
			}

			// Update roll timer
			if e.is_rolling {
				e.roll_timer += 1
				// Roll duration: 10 frames * INTERVAL
				if e.roll_timer >= 10 * INTERVAL {
					e.is_rolling = false
					e.roll_timer = 0
				}
			}

			if e.hit_flash_timer > 0 do e.hit_flash_timer = max(e.hit_flash_timer - dt, 0)
			if e.knockback_timer > 0 do e.knockback_timer = max(e.knockback_timer - dt, 0)

		case Enemy:
			if e.is_dying do e.death_timer += 1
			if e.hit_flash_timer > 0 do e.hit_flash_timer = max(e.hit_flash_timer - dt, 0)
			if e.knockback_timer > 0 do e.knockback_timer = max(e.knockback_timer - dt, 0)

		case Npc:
			if e.is_dying do e.death_timer += 1
			if e.hit_flash_timer > 0 do e.hit_flash_timer = max(e.hit_flash_timer - dt, 0)
			if e.knockback_timer > 0 do e.knockback_timer = max(e.knockback_timer - dt, 0)

		case Pressure_Plate, Gate, Holdable, Door: // No timers for these entities
				continue
		}
	}
}

entity_update_movement :: proc() {
	for &entity in entities {
		switch &e in entity {
		case Player: // Skip movement if rolling (velocity locked) or attacking or knockback or busy
				if e.is_rolling || e.knockback_timer > 0 || e.is_busy {
					// Keep current velocity for rolling or apply knockback friction
					if e.knockback_timer > 0 {
						e.velocity = e.velocity * 0.85 // Knockback friction
					} else if e.is_busy {
						e.velocity = {0, 0} // Stop completely when busy
					}
				} else {
					movement_input := input.get_movement_for_player(e.index)
					e.velocity = movement_input * e.move_speed

					if abs(movement_input.x) > 0 || abs(movement_input.y) > 0 {
						e.facing_direction = movement_input
					}
				}

		case Enemy: // Skip movement if dying or in knockback
				if e.is_dying || e.knockback_timer > 0 {
					// Apply knockback friction
					if e.knockback_timer > 0 {
						e.velocity = e.velocity * 0.85 // Knockback friction
					} else {
						e.velocity = {0, 0}
					}
				} else {
					// Simple Ai movement
					e.ai.move_timer -= rl.GetFrameTime()
					if e.ai.move_timer <= 0 {
						e.ai.move_direction = {
							rand.float32_range(-1.0, 1.0),
							rand.float32_range(-1.0, 1.0),
						}
						e.ai.move_timer = rand.float32_range(1.0, 3.0)
					}
					e.velocity = e.ai.move_direction * e.move_speed

					// Update model facing
					if abs(e.ai.move_direction.x) > 0 || abs(e.ai.move_direction.y) > 0 {
						e.facing_direction = e.ai.move_direction
					}
				}

		case Npc: // Skip movement if dying, in knockback, or busy
				if e.is_dying || e.knockback_timer > 0 || e.is_busy {
					// Apply knockback friction or stop for dialog
					if e.knockback_timer > 0 {
						e.velocity = e.velocity * 0.85 // Knockback friction
					} else {
						e.velocity = {0, 0}
					}
				} else {
					// Simple Ai movement (similar to enemy)
					e.ai.move_timer -= rl.GetFrameTime()
					if e.ai.move_timer <= 0 {
						e.ai.move_direction = {
							rand.float32_range(-1.0, 1.0),
							rand.float32_range(-1.0, 1.0),
						}
						e.ai.move_timer = rand.float32_range(1.0, 3.0)
					}
					e.velocity = e.ai.move_direction * e.move_speed

					// Update model facing
					if abs(e.ai.move_direction.x) > 0 || abs(e.ai.move_direction.y) > 0 {
						e.facing_direction = e.ai.move_direction
					}
				}

		case Pressure_Plate, Gate: // Static entities don't move
				continue
		case Holdable: // Holdables have no Ai movement, they only move when carried
				continue
		case Door: // Doors are static
				continue
		}
	}
}

entity_update_positions :: proc() {
	for &entity in entities {
		switch &e in entity {
		case Player: movement_move(&entity, &e.transform, &e.collider)
		case Enemy: movement_move(&entity, &e.transform, &e.collider)
		case Npc: movement_move(&entity, &e.transform, &e.collider)
		case Pressure_Plate, Gate, Holdable, Door: continue
		}
	}
}

entity_check_combat :: proc() {
	for &attacker in entities {
		switch &a in attacker {
		case Player:
			if !a.is_attacking || a.attack_hit do continue

			// Calculate attack rectangle
			attack_offset := a.attack_direction * a.range
			attack_pos := a.position + attack_offset
			attack_rect := rl.Rectangle {
				attack_pos.x - a.attack_width / 2,
				attack_pos.y - a.attack_height / 2,
				a.attack_width,
				a.attack_height,
			}

			// Check collision with enemies
			for &target in entities {
				switch &t in target {
				case Enemy:
					if t.is_dying do continue

					target_rect := collision_rect_at(t.position, t.collider)

					// Check if attack hits target
					if rl.CheckCollisionRecs(attack_rect, target_rect) {
						// Deal damage
						t.current -= a.damage
						a.attack_hit = true

						audio.sound_play(&game.sounds, audio.Sound_Kind.AttackHit)
						audio.sound_play(&game.sounds, audio.Sound_Kind.EnemyHit)

						// Apply hit effects
						t.hit_flash_timer = 0.2 // Hit flash duration

						// Calculate knockback direction (from attacker to target)
						knockback_dir := t.position - a.position
						if abs(knockback_dir.x) > 0 || abs(knockback_dir.y) > 0 {
							length := math.sqrt(
								knockback_dir.x * knockback_dir.x +
								knockback_dir.y * knockback_dir.y,
							)
							knockback_dir = knockback_dir / length
							t.velocity = knockback_dir * 200 // Knockback force
							t.knockback_timer = 0.3 // Knockback duration
						}

						// Check if enemy dies
						if t.current <= 0 {
							audio.sound_play(&game.sounds, audio.Sound_Kind.EnemyDeath)
							t.is_dying = true
							t.death_timer = 0
						}
					}

				case Player, Npc, Pressure_Plate, Gate, Holdable, Door: continue
				}
			}

		case Enemy, Npc, Pressure_Plate, Gate, Holdable, Door: continue
		}
	}
}


entity_update_animations :: proc() {
	delta_time := rl.GetFrameTime()
	for &entity in entities {
		switch &e in entity {
		case Player:
			if e.is_attacking {
				// Use attack direction to determine model facing for the attack animation.
				e.facing_direction = e.attack_direction
				animation_set_state(&e.anim_data, .Attack)
			} else if e.is_rolling {
				animation_set_state(&e.anim_data, .Roll)
			} else if e.carrying != nil {
				// Use carrying animation when holding an object
				animation_set_state(&e.anim_data, .Carry)
			} else if abs(e.velocity.x) > 0 || abs(e.velocity.y) > 0 {
				animation_set_state(&e.anim_data, .Run)
			} else {
				animation_set_state(&e.anim_data, .Idle)
			}
			animation_update(&e.anim_data, delta_time)

		case Enemy:
			if e.is_dying {
				animation_set_state(&e.anim_data, .Death)
			} else if abs(e.velocity.x) > 0 || abs(e.velocity.y) > 0 {
				animation_set_state(&e.anim_data, .Run)
			} else {
				animation_set_state(&e.anim_data, .Idle)
			}
			animation_update(&e.anim_data, delta_time)

		case Npc:
			if e.is_dying {
				animation_set_state(&e.anim_data, .Death)
			} else if abs(e.velocity.x) > 0 || abs(e.velocity.y) > 0 {
				animation_set_state(&e.anim_data, .Run)
			} else {
				animation_set_state(&e.anim_data, .Idle)
			}
			animation_update(&e.anim_data, delta_time)

		case Pressure_Plate, Gate, Holdable, Door: // Static entities don't have animations
				continue
		}
	}
}

npc_update_animation :: proc() {
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
