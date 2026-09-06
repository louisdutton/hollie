package hollie

import "audio"
import "input"
import rl "vendor:raylib"

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

pressure_plate_create :: proc(
	position: Vec2,
	trigger_id: int,
	requires_both: bool = false,
) -> ^Pressure_Plate {
	plate := Pressure_Plate {
		transform = {position = position},
		collider = model_pressure_pad_collider(false),
		trigger_id = trigger_id,
		requires_both = requires_both,
		animation_time = 1e9,
	}
	append(&entities, plate)
	return &entities[len(entities) - 1].(Pressure_Plate)
}

gate_create :: proc(position, size: Vec2, gate_id: int, inverted: bool = false) -> ^Gate {
	gate := Gate {
		transform = {position = position},
		collider = {size = size, height = RENDERING_GATE_HEIGHT, solid = true},
		gate_id = gate_id,
		required_triggers = make([dynamic]int),
		inverted = inverted,
	}
	append(&entities, gate)
	return &entities[len(entities) - 1].(Gate)
}

pressure_plate_has_required_weight :: proc(
	player_count, crate_count: int,
	requires_both: bool,
) -> bool {
	required_weight := requires_both ? 2 : 1
	return player_count + crate_count >= required_weight
}

pressure_plate_has_crate :: proc(plate: ^Pressure_Plate, holdable: ^Holdable) -> bool {
	if holdable.held_by != nil do return false
	return rects_intersect(
		collision_rect_at(plate.position, plate.collider),
		collision_rect_at(holdable.position, holdable.collider),
	)
}

puzzle_update :: proc() {
	delta_time := rl.GetFrameTime()

	// Update pressure plate states
	for &plate_entity in entities {
		plate, ok := &plate_entity.(Pressure_Plate)
		if !ok do continue
		was_active := plate.active
		// Reset activation state
		plate.activated_by = {}
		plate.active = false

		// Players and dropped crates each contribute one unit of pressure.
		for &player_entity in entities {
			player, ok := &player_entity.(Player)
			if !ok do continue
			player_rect := collision_rect_at(player.position, player.collider)
			plate_rect := collision_rect_at(plate.position, plate.collider)

			if rects_intersect(player_rect, plate_rect) {
				plate.activated_by += {player.index}
			}
		}

		crate_count := 0
		for &holdable_entity in entities {
			holdable, ok := &holdable_entity.(Holdable)
			if !ok do continue
			if pressure_plate_has_crate(plate, holdable) do crate_count += 1
		}
		plate.active = pressure_plate_has_required_weight(
			card(plate.activated_by),
			crate_count,
			plate.requires_both,
		)

		if plate.active != was_active {
			plate.animation_time = 0
			audio.sound_play(&game.sounds, audio.Sound_Kind.PressurePlateToggle)
		} else {
			plate.animation_time += delta_time
		}
	}

	// Update gate states based on trigger requirements
	for &gate_entity in entities {
		gate, ok := &gate_entity.(Gate)
		if !ok do continue
		assert(len(gate.required_triggers) > 0)

		all_triggers_active := true
		for trigger_id in gate.required_triggers {
			trigger_active := false

			// Check if this trigger ID matches any pressure plate
			for &plate_entity in entities {
				plate, ok := &plate_entity.(Pressure_Plate)
				if !ok do continue
				if plate.trigger_id == trigger_id {
					trigger_active = plate.active
					break
				}
			}

			if !trigger_active {
				all_triggers_active = false
				break
			}
		}

		// Apply inverted logic if needed
		new_open_state := gate.inverted ? !all_triggers_active : all_triggers_active

		gate.open = new_open_state
	}
}
