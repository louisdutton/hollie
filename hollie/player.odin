package hollie

import "audio"
import "core:math"
import "input"

PLAYER_INTERACT_RANGE :: 24 // distance within which the player can interact with interactable entities
PLAYER_DROP_FALLBACK_DISTANCE :: 16 // fallback distance for placing a dropped item
PLAYER_DROP_GAP :: 2 // clearance kept between the player and a dropped item

Player :: struct {
	using transform: Transform,
	using collider:  Collider,
	using health:    Health,
	using movement:  Movement,
	using combat:    Combat,
	using anim_data: Animator,
	index:           input.Player_Index,
	// TODO: Replace persistent pointers into the dynamic entity array with stable references.
	carrying:        ^Holdable,
}

player_create :: proc(
	position: Vec2,
	index: input.Player_Index,
	animations: []Animation,
) -> ^Player {
	player := Player {
		transform = {position = position},
		collider = model_character_collider(true),
		health = {current = 100, max = 100, is_dying = false},
		movement = {move_speed = 80, roll_speed = 160, facing_direction = {1, 0}},
		combat = {damage = 25, range = 32, attack_width = 32, attack_height = 32},
		index = index,
	}
	if len(animations) > 0 do animation_init(&player.anim_data, animations)

	append(&entities, player)
	return &entities[len(entities) - 1].(Player)
}

player_spawn_at :: proc(pos: Vec2, index: input.Player_Index) {
	player_create(pos, index, player_animations[:])
}

player_handle_input :: proc(p: ^Player) {
	// attack and rolling bools can probably be made redundant
	if p.is_busy || p.is_attacking || p.is_rolling do return

	// Carrying is a limited state so must be handled first
	// there will likely be other states like this
	if p.carrying != nil && input.is_pressed_for_player(.Accept, p.index) {
		player_drop(p)
		return
	}

	if input.is_pressed_for_player(.Accept, p.index) {
		if npc := npc_get_in_range(p.position, PLAYER_INTERACT_RANGE); npc != nil {
			dialog_start(npc)
		} else {
			player_carry(p)
		}
	}
	if input.is_pressed_for_player(.Attack, p.index) do player_attack(p)
	if input.is_pressed_for_player(.Roll, p.index) do player_roll(p)
}

player_update_input :: proc() {
	for &entity in entities {
		#partial switch &p in entity {
		case Player: player_handle_input(&p)
		}
	}
}

player_update_movement :: proc() {
	for &entity in entities {
		#partial switch &p in entity {
		case Player:
			if p.is_rolling {
				p.roll_timer += 1
				if p.roll_timer >= 10 * INTERVAL {
					p.is_rolling = false
					p.roll_timer = 0
				}
			}

			if p.is_rolling || p.knockback_timer > 0 || p.is_busy {
				if p.knockback_timer > 0 {
					p.velocity *= 0.85
				} else if p.is_busy {
					p.velocity = {0, 0}
				}
				continue
			}

			movement_input := input.get_movement_for_player(p.index)
			p.velocity = movement_input * p.move_speed
			if abs(movement_input.x) > 0 || abs(movement_input.y) > 0 {
				p.facing_direction = movement_input
			}
		}
	}
}

@(private)
player_drop :: proc(p: ^Player) {
	p.carrying.held_by = nil
	p.carrying.position = player_drop_position(
		p.position,
		p.facing_direction,
		p.collider,
		p.carrying.collider,
	)
	p.carrying = nil
}

player_drop_position :: proc(
	position, facing_direction: Vec2,
	player_collider, item_collider: Collider,
) -> Vec2 {
	length := math.sqrt(
		facing_direction.x * facing_direction.x + facing_direction.y * facing_direction.y,
	)
	if length == 0 do return position

	direction := facing_direction / length
	distance := f32(1e9)
	if direction.x > 0 {
		distance = min(
			distance,
			(player_collider.offset.x + player_collider.size.x - item_collider.offset.x) /
			direction.x,
		)
	} else if direction.x < 0 {
		distance = min(
			distance,
			(player_collider.offset.x - item_collider.offset.x - item_collider.size.x) /
			direction.x,
		)
	}
	if direction.y > 0 {
		distance = min(
			distance,
			(player_collider.offset.z + player_collider.size.z - item_collider.offset.z) /
			direction.y,
		)
	} else if direction.y < 0 {
		distance = min(
			distance,
			(player_collider.offset.z - item_collider.offset.z - item_collider.size.z) /
			direction.y,
		)
	}
	if distance == f32(1e9) do distance = PLAYER_DROP_FALLBACK_DISTANCE - PLAYER_DROP_GAP
	return position + direction * (distance + PLAYER_DROP_GAP)
}


// this is a little messy, we shouldn't really have to iterate twice like this.
@(private)
player_carry :: proc(p: ^Player) {
	for &entity in entities {
		holdable, ok := &entity.(Holdable)
		if !ok do continue
		if holdable.held_by == nil {
			if get_distance(holdable.position, p.position) <= PLAYER_INTERACT_RANGE {
				holdable.held_by = p
				p.carrying = holdable
				break
			}
		}
	}
}

@(private)
player_roll :: proc(p: ^Player) {
	movement_input := input.get_movement_for_player(p.index)
	is_moving := abs(movement_input.x) > 0 || abs(movement_input.y) > 0

	if is_moving {
		length := math.sqrt(
			movement_input.x * movement_input.x + movement_input.y * movement_input.y,
		)
		p.velocity = (movement_input / length) * p.roll_speed
		p.facing_direction = movement_input / length
		p.is_rolling = true
		p.roll_timer = 0

		audio.sound_play(&game.sounds, audio.Sound_Kind.GruntRoll)
	}
}

@(private)
player_attack :: proc(p: ^Player) {
	p.is_attacking = true
	p.attack_timer = 0
	p.attack_hit = false

	// Lock attack direction based on current movement or facing
	movement_input := input.get_movement_for_player(p.index)
	if abs(movement_input.x) > 0 || abs(movement_input.y) > 0 {
		// Use current movement direction
		p.attack_direction = {movement_input.x, movement_input.y}
		if abs(p.attack_direction.x) > 0 || abs(p.attack_direction.y) > 0 {
			length := math.sqrt(
				p.attack_direction.x * p.attack_direction.x +
				p.attack_direction.y * p.attack_direction.y,
			)
			p.attack_direction = p.attack_direction / length
		}
	} else {
		// Use current facing direction if not moving
		p.attack_direction = p.facing_direction
	}

	// Play attack grunt sound
	audio.sound_play(&game.sounds, audio.Sound_Kind.GruntAttack)
}
