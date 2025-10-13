package hollie

import "audio"
import "core:math"
import "core:math/rand"
import "core:slice"
import "input"
import "renderer"
import rl "vendor:raylib"

// Common components that can be reused
Transform :: struct {
	position: Vec2,
	velocity: Vec2,
}

Collider :: struct {
	size:   Vec2,
	offset: Vec2, // Offset from transform position
	solid:  bool,
}

Health :: struct {
	current:         i32,
	max:             i32,
	is_dying:        bool,
	death_timer:     u32,
	hit_flash_timer: f32,
	knockback_timer: f32,
}

Movement :: struct {
	move_speed: f32,
	roll_speed: f32,
	is_rolling: bool,
	roll_timer: u32,
	is_busy:    bool,
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

AI :: struct {
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
	player_index:    input.Player_Index,
}

NPC :: struct {
	using transform: Transform,
	using collider:  Collider,
	using health:    Health,
	using movement:  Movement,
	using ai:        AI,
	using anim_data: Animator,
}

Enemy :: struct {
	using npc:    NPC,
	using combat: Combat,
}

Pressure_Plate :: struct {
	using transform: Transform,
	using collider:  Collider,
	trigger_id:      int,
	active:          bool,
	activated_by:    bit_set[Player_ID],
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

// Main entity union
Entity :: union {
	Player,
	Enemy,
	NPC,
	Pressure_Plate,
	Gate,
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
	player_index: input.Player_Index,
	animations: []Animation,
) -> ^Player {
	player := Player {
		transform = {position = pos, velocity = {0, 0}},
		collider = {size = {16, 16}, offset = {-8, -8}, solid = true},
		health = {current = 100, max = 100, is_dying = false},
		movement = {move_speed = 100, roll_speed = 200, is_rolling = false},
		combat = {damage = 25, range = 32, attack_width = 32, attack_height = 32},
		player_index = player_index,
	}

	if len(animations) > 0 {
		animation_init(&player.anim_data, animations)
	}

	append(&entities, player)
	return &entities[len(entities) - 1].(Player)
}

entity_create_enemy :: proc(pos: Vec2, race: NPC_Race, animations: []Animation) -> ^Enemy {
	enemy := Enemy {
		transform = {position = pos, velocity = {0, 0}},
		collider = {size = {16, 16}, offset = {-8, -8}, solid = true},
		health = {current = 50, max = 50, is_dying = false},
		movement = {move_speed = 50, roll_speed = 100, is_rolling = false},
		combat = {damage = 15, range = 24, attack_width = 24, attack_height = 24},
		ai = {wait_timer = 0, move_timer = 0, move_direction = {0, 0}},
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
		transform = {position = pos, velocity = {0, 0}},
		collider = {size = {32, 32}, offset = {-16, -16}, solid = false},
		trigger_id = trigger_id,
		active = false,
		requires_both = requires_both,
	}

	append(&entities, plate)
	return &entities[len(entities) - 1].(Pressure_Plate)
}

entity_create_gate :: proc(pos: Vec2, size: Vec2, gate_id: int, inverted: bool = false) -> ^Gate {
	gate := Gate {
		transform = {position = pos, velocity = {0, 0}},
		collider = {size = size, offset = {0, 0}, solid = true},
		gate_id = gate_id,
		open = false,
		required_triggers = make([dynamic]int),
		inverted = inverted,
	}

	append(&entities, gate)
	return &entities[len(entities) - 1].(Gate)
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

entity_get_player :: proc(player_index: input.Player_Index) -> ^Player {
	for &entity in entities {
		if player, ok := &entity.(Player); ok && player.player_index == player_index {
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

// Collision helpers
entity_get_world_collider_pos :: proc(entity: ^Entity) -> Vec2 {
	switch e in entity {
	case Player: return e.position + e.collider.offset
	case Enemy: return e.position + e.collider.offset
	case NPC: return e.position + e.collider.offset
	case Pressure_Plate: return e.position + e.collider.offset
	case Gate: return e.position + e.collider.offset
	}
	return {0, 0}
}

entity_get_collider_size :: proc(entity: ^Entity) -> Vec2 {
	switch e in entity {
	case Player: return e.collider.size
	case Enemy: return e.collider.size
	case NPC: return e.collider.size
	case Pressure_Plate: return e.collider.size
	case Gate: return e.collider.size
	}
	return {0, 0}
}

entity_check_collision :: proc(a, b: ^Entity) -> bool {
	pos_a := entity_get_world_collider_pos(a)
	size_a := entity_get_collider_size(a)
	pos_b := entity_get_world_collider_pos(b)
	size_b := entity_get_collider_size(b)

	return(
		pos_a.x < pos_b.x + size_b.x &&
		pos_a.x + size_a.x > pos_b.x &&
		pos_a.y < pos_b.y + size_b.y &&
		pos_a.y + size_a.y > pos_b.y \
	)
}

entity_point_in_collider :: proc(entity: ^Entity, point: Vec2) -> bool {
	pos := entity_get_world_collider_pos(entity)
	size := entity_get_collider_size(entity)

	return(
		point.x >= pos.x &&
		point.x <= pos.x + size.x &&
		point.y >= pos.y &&
		point.y <= pos.y + size.y \
	)
}

// Update systems
entity_system_update :: proc() {
	entity_handle_input()
	entity_update_timers()
	entity_update_movement()
	entity_update_positions()
	entity_check_combat()
	entity_update_animations()
	entity_cleanup_dead()
}

entity_handle_input :: proc() {
	for &entity in entities {
		switch &e in entity {
		case Player:
			// Skip input if dialog is active
			if dialog_is_active() do continue

			// Handle attack input
			if input.is_pressed_for_player(.Attack, e.player_index) &&
			   !e.is_attacking &&
			   !e.is_rolling {
				e.is_attacking = true
				e.attack_timer = 0
				e.attack_hit = false

				// Lock attack direction based on current movement or facing
				movement_input := input.get_movement_for_player(e.player_index)
				if abs(movement_input.x) > 0 || abs(movement_input.y) > 0 {
					// Use current movement direction
					e.attack_direction = {movement_input.x, movement_input.y}
					if abs(e.attack_direction.x) > 0 || abs(e.attack_direction.y) > 0 {
						length := math.sqrt(
							e.attack_direction.x * e.attack_direction.x +
							e.attack_direction.y * e.attack_direction.y,
						)
						e.attack_direction = e.attack_direction / length
					}
				} else {
					// Use current facing direction if not moving
					e.attack_direction = Vec2{e.is_flipped ? -1 : 1, 0}
				}

				// Play attack grunt sound
				audio.sound_play(game.sounds["grunt_attack"])
			}

			// Handle roll input
			if input.is_pressed_for_player(.Roll, e.player_index) &&
			   !e.is_rolling &&
			   !e.is_attacking {
				movement_input := input.get_movement_for_player(e.player_index)
				// Only roll if moving
				if abs(movement_input.x) > 0 || abs(movement_input.y) > 0 {
					length := math.sqrt(
						movement_input.x * movement_input.x + movement_input.y * movement_input.y,
					)
					e.velocity = (movement_input / length) * e.roll_speed
					e.is_rolling = true
					e.roll_timer = 0

					// Play roll grunt sound
					audio.sound_play(game.sounds["grunt_roll"])
				}
			}

		case Enemy, NPC, Pressure_Plate, Gate: // No input handling for these entities
				continue
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

		case NPC:
			if e.is_dying do e.death_timer += 1
			if e.hit_flash_timer > 0 do e.hit_flash_timer = max(e.hit_flash_timer - dt, 0)
			if e.knockback_timer > 0 do e.knockback_timer = max(e.knockback_timer - dt, 0)

		case Pressure_Plate, Gate: // No timers for these entities
				continue
		}
	}
}

entity_update_movement :: proc() {
	for &entity in entities {
		switch &e in entity {
		case Player: // Skip movement if rolling (velocity locked) or attacking or knockback
				if e.is_rolling || e.knockback_timer > 0 {
					// Keep current velocity for rolling or apply knockback friction
					if e.knockback_timer > 0 {
						e.velocity = e.velocity * 0.85 // Knockback friction
					}
				} else {
					movement_input := input.get_movement_for_player(e.player_index)
					e.velocity = movement_input * e.move_speed

					if abs(movement_input.x) > 0 {
						e.is_flipped = movement_input.x < 0
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
					// Simple AI movement
					e.ai.move_timer -= rl.GetFrameTime()
					if e.ai.move_timer <= 0 {
						e.ai.move_direction = {
							rand.float32_range(-1.0, 1.0),
							rand.float32_range(-1.0, 1.0),
						}
						e.ai.move_timer = rand.float32_range(1.0, 3.0)
					}
					e.velocity = e.ai.move_direction * e.move_speed

					// Update sprite flip
					if abs(e.ai.move_direction.x) > 0 {
						e.is_flipped = e.ai.move_direction.x < 0
					}
				}

		case NPC: // Skip movement if dying or in knockback
				if e.is_dying || e.knockback_timer > 0 {
					// Apply knockback friction
					if e.knockback_timer > 0 {
						e.velocity = e.velocity * 0.85 // Knockback friction
					} else {
						e.velocity = {0, 0}
					}
				} else {
					// Simple AI movement (similar to enemy)
					e.ai.move_timer -= rl.GetFrameTime()
					if e.ai.move_timer <= 0 {
						e.ai.move_direction = {
							rand.float32_range(-1.0, 1.0),
							rand.float32_range(-1.0, 1.0),
						}
						e.ai.move_timer = rand.float32_range(1.0, 3.0)
					}
					e.velocity = e.ai.move_direction * e.move_speed

					// Update sprite flip
					if abs(e.ai.move_direction.x) > 0 {
						e.is_flipped = e.ai.move_direction.x < 0
					}
				}

		case Pressure_Plate, Gate: // Static entities don't move
				continue
		}
	}
}

entity_update_positions :: proc() {
	for &entity in entities {
		switch &e in entity {
		case Player: entity_move_character(&e.transform, &e.collider)
		case Enemy: entity_move_character(&e.transform, &e.collider)
		case NPC: entity_move_character(&e.transform, &e.collider)
		case Pressure_Plate, Gate: // Static entities don't move
				continue
		}
	}
}

// Helper function to move any character with Transform and Collider
entity_move_character :: proc(transform: ^Transform, collider: ^Collider) {
	next_pos := transform.position + transform.velocity * rl.GetFrameTime()

	// Check puzzle gate collision
	if puzzle_check_gate_collision(next_pos, collider.size) {
		return // Don't move if blocked by a gate
	}

	// Apply bounds checking using room collision bounds
	room_bounds := room_get_collision_bounds()
	half_width := collider.size.x / 2
	half_height := collider.size.y / 2

	transform.position.x = clamp(
		next_pos.x,
		room_bounds.x + half_width,
		room_bounds.x + room_bounds.width - half_width,
	)
	transform.position.y = clamp(
		next_pos.y,
		room_bounds.y + half_height,
		room_bounds.y + room_bounds.height - half_height,
	)
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

					target_rect := rl.Rectangle {
						t.position.x - t.collider.size.x / 2,
						t.position.y - t.collider.size.y / 2,
						t.collider.size.x,
						t.collider.size.y,
					}

					// Check if attack hits target
					if rl.CheckCollisionRecs(attack_rect, target_rect) {
						// Deal damage
						t.current -= a.damage
						a.attack_hit = true

						audio.sound_play(game.sounds["attack_hit"])
						audio.sound_play(game.sounds["enemy_hit"])

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
							audio.sound_play(game.sounds["enemy_death"])
							t.is_dying = true
							t.death_timer = 0
						}
					}

				case Player, NPC, Pressure_Plate, Gate: continue
				}
			}

		case Enemy, NPC, Pressure_Plate, Gate: continue
		}
	}
}

entity_update_animations :: proc() {
	for &entity in entities {
		switch &e in entity {
		case Player:
			if e.is_attacking {
				// Use attack direction to determine sprite flip for attack animation
				e.is_flipped = e.attack_direction.x < 0
				animation_set_state(&e.anim_data, .ATTACK)
			} else if e.is_rolling {
				animation_set_state(&e.anim_data, .ROLL)
			} else if abs(e.velocity.x) > 0 || abs(e.velocity.y) > 0 {
				animation_set_state(&e.anim_data, .RUN)
			} else {
				animation_set_state(&e.anim_data, .IDLE)
			}
			animation_update(&e.anim_data)

		case Enemy:
			if e.is_dying {
				animation_set_state(&e.anim_data, .DEATH)
			} else if abs(e.velocity.x) > 0 || abs(e.velocity.y) > 0 {
				animation_set_state(&e.anim_data, .RUN)
			} else {
				animation_set_state(&e.anim_data, .IDLE)
			}
			animation_update(&e.anim_data)

		case NPC:
			if e.is_dying {
				animation_set_state(&e.anim_data, .DEATH)
			} else if abs(e.velocity.x) > 0 || abs(e.velocity.y) > 0 {
				animation_set_state(&e.anim_data, .RUN)
			} else {
				animation_set_state(&e.anim_data, .IDLE)
			}
			animation_update(&e.anim_data)

		case Pressure_Plate, Gate: // Static entities don't have animations
				continue
		}
	}
}

npc_update_animation :: proc() {
}


entity_system_draw :: proc() {
	// Collect and sort entities by Y position for proper depth
	drawable_entities := make([dynamic]^Entity, 0, len(entities))
	defer delete(drawable_entities)

	for &entity in entities {
		switch e in entity {
		case Player, Enemy, NPC: append(&drawable_entities, &entity)
		case Pressure_Plate, Gate: // These are drawn by the room system
				continue
		}
	}

	// Sort by Y position
	slice.sort_by(drawable_entities[:], proc(a, b: ^Entity) -> bool {
		pos_a := entity_get_world_collider_pos(a)
		pos_b := entity_get_world_collider_pos(b)
		return pos_a.y < pos_b.y
	})

	// Draw entities
	for entity in drawable_entities {
		switch &e in entity {
		case Player:
			entity_draw_shadow(e.position)

			// Draw with hit flash if needed
			if e.hit_flash_timer > 0 {
				flash_intensity := e.hit_flash_timer / 0.2
				animation_draw_with_flash(&e.anim_data, e.position, rl.WHITE, &flash_intensity)
			} else {
				animation_draw(&e.anim_data, e.position)
			}

			// Draw player indicator
			player_text := e.player_index == .PLAYER_1 ? "P1" : "P2"
			player_color := e.player_index == .PLAYER_1 ? renderer.BLUE : renderer.RED
			renderer.draw_text(
				player_text,
				int(e.position.x) - 8,
				int(e.position.y - 20),
				12,
				color = player_color,
			)

		case Enemy:
			entity_draw_shadow(e.position)

			// Draw with hit flash if needed
			if e.hit_flash_timer > 0 {
				flash_intensity := e.hit_flash_timer / 0.2
				animation_draw_with_flash(&e.anim_data, e.position, rl.WHITE, &flash_intensity)
			} else {
				animation_draw(&e.anim_data, e.position)
			}

		case NPC:
			entity_draw_shadow(e.position)

			// Draw with hit flash if needed
			if e.hit_flash_timer > 0 {
				flash_intensity := e.hit_flash_timer / 0.2
				animation_draw_with_flash(&e.anim_data, e.position, rl.WHITE, &flash_intensity)
			} else {
				animation_draw(&e.anim_data, e.position)
			}

		case Pressure_Plate, Gate: // These shouldn't be in drawable_entities
				continue
		}
	}
}

entity_draw_shadow :: proc(position: Vec2, radius: f32 = 6) {
	renderer.draw_circle(position.x, position.y + 8, radius, renderer.fade(renderer.BLACK, 0.3))
}


entity_cleanup_dead :: proc() {
	for i := len(entities) - 1; i >= 0; i -= 1 {
		switch &e in entities[i] {
		case Enemy: if e.is_dying && e.death_timer >= 13 * INTERVAL {
					particle_create_explosion(e.position)
					unordered_remove(&entities, i)
				}
		case NPC: if e.is_dying && e.death_timer >= 13 * INTERVAL {
					particle_create_explosion(e.position)
					unordered_remove(&entities, i)
				}
		case Player, Pressure_Plate, Gate: continue
		}
	}
}
