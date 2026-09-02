package hollie

import "audio"
import "core:math"
import "input"

PLAYER_INTERACT_RANGE :: 24 // the distance within which the player can interact with interable entities
PLAYER_DROP_FALLBACK_DISTANCE :: 16
PLAYER_DROP_GAP :: 2

player_spawn_at :: proc(pos: Vec2, index: input.Player_Index) {
	entity_create_player(pos, index, player_animations[:])
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
			(player_collider.offset.y + player_collider.size.y - item_collider.offset.y) /
			direction.y,
		)
	} else if direction.y < 0 {
		distance = min(
			distance,
			(player_collider.offset.y - item_collider.offset.y - item_collider.size.y) /
			direction.y,
		)
	}
	if distance == f32(1e9) do distance = PLAYER_DROP_FALLBACK_DISTANCE - PLAYER_DROP_GAP
	return position + direction * (distance + PLAYER_DROP_GAP)
}


// this is a little messy, we shouldn't really have to iterate twice like this.
@(private)
player_carry :: proc(p: ^Player) {
	holdables := entity_get_holdables()
	defer delete(holdables)

	for holdable in holdables {
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

		audio.sound_play(game.sounds["grunt_roll"])
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
	audio.sound_play(game.sounds["grunt_attack"])
}
