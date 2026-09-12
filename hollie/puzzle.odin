package hollie

import "audio"
import "graphics"
import "input"

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
	breakable:         bool,
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
		collider = {size = {size.x, RENDERING_GATE_HEIGHT, size.y}, solid = true},
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
	holdable_entity := Entity(holdable^)
	return pressure_plate_supports(plate, &holdable_entity)
}

pressure_plate_supports :: proc(plate: ^Pressure_Plate, entity: ^Entity) -> bool {
	grounded := false
	switch e in entity^ {
	case Player: grounded = e.grounded
	case Enemy: grounded = e.grounded
	case Holdable: grounded = e.grounded && e.held_by == nil
	case Npc, Pressure_Plate, Gate, Door: return false
	}
	if !grounded do return false
	plate_bounds := collision_aabb_at(plate.position, plate.collider, plate.height)
	body_bounds := collision_entity_aabb(entity)
	return(
		physics_overlap_horizontal(plate_bounds, body_bounds) &&
		abs(body_bounds.min.y - plate_bounds.max.y) <= PHYSICS_CONTACT_EPSILON \
	)
}

pressure_plate_update_surfaces :: proc() {
	for &entity in entities {
		plate, ok := &entity.(Pressure_Plate)
		if !ok do continue
		plate.animation_time += graphics.get_frame_time()
		state := plate.active ? Pressure_Pad_State.On : Pressure_Pad_State.Off
		clip_index := model_assets.pressure_pad_animation_indices[state]
		if clip_index < 0 do continue
		clip := model_assets.pressure_pad_animations[clip_index]
		graphics.update_model_animation(
			model_assets.pressure_pad,
			clip,
			model_animation_frame(plate.animation_time, clip, .Once_Hold),
		)
		bounds := graphics.get_animated_model_bounding_box(model_assets.pressure_pad)
		new_height :=
			(bounds.max.y - model_assets.pressure_pad_bounds.min.y) * MODEL_PRESSURE_PAD_SCALE
		delta := new_height - plate.collider.size.y
		// Keep resting weight attached while the button depresses or rises.
		for &body in entities {
			if !pressure_plate_supports(plate, &body) do continue
			switch &e in body {
			case Player: e.height += delta
			case Enemy: e.height += delta
			case Holdable: e.height += delta
			case Npc, Pressure_Plate, Gate, Door: continue
			}
		}
		plate.collider.size.y = new_height
	}
}

puzzle_update :: proc() {

	// Update pressure plate states
	for &plate_entity in entities {
		plate, ok := &plate_entity.(Pressure_Plate)
		if !ok do continue
		was_active := plate.active
		// Reset activation state
		plate.activated_by = {}
		plate.active = false

		// Players, enemies, and resting crates each contribute one unit of pressure.
		other_weight := 0
		for &body in entities {
			if !pressure_plate_supports(plate, &body) do continue
			if player, ok := &body.(Player); ok {
				plate.activated_by += {player.index}
			} else {
				other_weight += 1
			}
		}
		plate.active = pressure_plate_has_required_weight(
			card(plate.activated_by),
			other_weight,
			plate.requires_both,
		)

		if plate.active != was_active {
			plate.animation_time = 0
			audio.sound_play(&game.sounds, audio.Sound_Kind.PressurePlateToggle)
		}
	}

	// Update gate states based on trigger requirements
	for &gate_entity in entities {
		gate, ok := &gate_entity.(Gate)
		if !ok do continue
		if gate.breakable do continue
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

		if new_open_state {
			gate.open = true
		} else if gate.open {
			physics_close_gate(&gate_entity)
		}
	}
}
