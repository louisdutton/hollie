package hollie

import "core:math"
import "graphics"
import "input"
import "tilemap"

PLAYER_INTERACT_RANGE :: 24 // distance within which the player can interact with interactable entities
PLAYER_DROP_FALLBACK_DISTANCE :: 16 // fallback distance for placing a dropped item
PLAYER_DROP_GAP :: 2 // clearance kept between the player and a dropped item

Player :: struct {
	using transform:      Transform,
	using collider:       Collider,
	using health:         Health,
	using movement:       Movement,
	using anim_data:      Animator,
	index:                input.Player_Index,
	// TODO: Replace persistent pointers into the dynamic entity array with stable references.
	carrying:             ^Holdable,
	head_turn:            f32,
	movement_lean:        f32,
	stride_time:          f32,
	dismount_air_control: bool,
	mount_elapsed:        f32,
	mount_duration:       f32,
	mount_start:          Vec2,
	mount_start_height:   f32,
	mount_start_facing:   Vec2,
}

player_create :: proc(
	position: Vec2,
	index: input.Player_Index,
	animations: []Animation,
) -> ^Player {
	player := Player {
		transform = {position = position, grounded = true},
		collider = model_character_collider(true),
		health = {current = 100, max = 100, is_dying = false},
		movement = {move_speed = 80, facing_direction = {1, 0}},
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
	if p.is_busy do return
	if animal := riding_animal_for_player(p.index); animal != nil {
		if p.mount_elapsed < p.mount_duration do return
		if input.is_pressed_for_player(.Interact, p.index) {
			riding_dismount(p, animal)
			return
		}
		if !animal.ram_ready && input.is_pressed_for_player(.Jump, p.index) {
			jump_speed := animal.kind == .Bison ? PHYSICS_JUMP_SPEED * 0.8 : PHYSICS_JUMP_SPEED
			physics_jump(&animal.transform, jump_speed)
		}
		return
	}

	// Carrying is a limited state so must be handled first
	// there will likely be other states like this
	if p.carrying != nil && input.is_pressed_for_player(.Interact, p.index) {
		player_drop(p)
		return
	}

	if input.is_pressed_for_player(.Interact, p.index) {
		if npc := npc_get_in_range(p.position, PLAYER_INTERACT_RANGE); npc != nil {
			dialog_start(npc)
		} else if !riding_try_mount(p) {
			player_carry(p)
		}
	}
	if input.is_pressed_for_player(.Jump, p.index) do physics_jump(&p.transform)
}

player_update_input :: proc() {
	for &entity in entities {
		#partial switch &p in entity {
		case Player: player_handle_input(&p)
		}
	}
}

player_update_movement :: proc() {
	dt := min(graphics.get_frame_time(), 0.1)
	for &entity in entities {
		#partial switch &p in entity {
		case Player:
			if animal := riding_animal_for_player(p.index); animal != nil {
				if p.mount_elapsed < p.mount_duration {
					p.mount_elapsed = min(p.mount_elapsed + dt, p.mount_duration)
					continue
				}
				if p.is_busy {
					animal.velocity = {}
					animal.turn_lean = riding_turn_lean(animal.turn_lean, {}, {}, dt)
					animal.head_turn = riding_head_turn(
						animal.head_turn,
						animal.facing_direction,
						{},
						dt,
					)
					continue
				}
				movement_input: Vec2
				if !p.is_busy do movement_input = camera_relative_movement(input.get_movement_for_player(p.index))
				animal_update_movement(
					animal,
					movement_input,
					animal_riding_profile(animal.kind),
					dt,
				)
				continue
			}
			if p.knockback_timer > 0 || p.is_busy {
				if p.knockback_timer > 0 {
					p.velocity *= 0.85
				} else if p.is_busy {
					p.velocity = {0, 0}
				}
				continue
			}

			movement_input := camera_relative_movement(input.get_movement_for_player(p.index))
			if p.grounded do p.dismount_air_control = false
			if p.dismount_air_control {
				p.velocity = movement_steer_air(p.velocity, movement_input, dt)
			} else {
				p.velocity = movement_accelerate(
					p.velocity,
					movement_input,
					PLAYER_MOVEMENT_PROFILE,
					dt,
				)
			}
			if p.velocity != (Vec2{}) {
				p.facing_direction =
					p.velocity /
					math.sqrt(p.velocity.x * p.velocity.x + p.velocity.y * p.velocity.y)
			}
			p.head_turn = riding_head_turn(
				p.head_turn,
				p.facing_direction,
				movement_input,
				dt * 1.5,
			)
		}
	}
}

@(private)
player_drop :: proc(p: ^Player) {
	offset := Vec3{0, RENDERING_CARRIED_ITEM_HEIGHT, 0}
	if p.carrying.held_pose_valid do offset = p.carrying.held_offset
	position := p.position + Vec2{offset.x, offset.z}
	height := p.height + offset.y
	if collision_check_solid(position, p.carrying.collider, height = height) ||
	   (room_get_current() != nil &&
			   tilemap.check_collision(collision_aabb_at(position, p.carrying.collider, height))) {
		return
	}
	p.carrying.height = height
	direction := p.facing_direction
	length := math.sqrt(direction.x * direction.x + direction.y * direction.y)
	if length > 0 do direction /= length
	p.carrying.velocity = p.velocity + direction * 45
	p.carrying.vertical_velocity = p.vertical_velocity + 15
	p.carrying.grounded = false
	p.carrying.held_by = nil
	p.carrying.release_ignore_player = true
	p.carrying.release_player = p.index
	p.carrying.held_pose_valid = false
	p.carrying.position = position
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
			if get_distance(holdable.position, p.position) <= PLAYER_INTERACT_RANGE &&
			   abs(holdable.height - p.height) <= PLAYER_INTERACT_RANGE {
				holdable.held_by = p
				p.carrying = holdable
				break
			}
		}
	}
}
