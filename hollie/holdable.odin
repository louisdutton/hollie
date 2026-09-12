package hollie

import "input"

CRATE_GROUND_FRICTION :: f32(360) // horizontal deceleration in world units per second squared

Holdable :: struct {
	using transform:       Transform,
	using collider:        Collider,
	// Persistent relationships use IDs; resolved pointers are borrowed until storage changes.
	held_by:               Entity_Id,
	held_offset:           Vec3,
	held_pose_valid:       bool,
	release_ignore_player: bool,
	release_player:        input.Player_Index,
}

holdable_create :: proc(position: Vec2) -> ^Holdable {
	holdable := Holdable {
		transform = {position = position, grounded = true},
		collider = model_crate_collider(true),
	}
	value := entity_add(holdable, &world)
	return &value^.(Holdable)
}

holdable_spawn_at :: proc(position: Vec2) -> ^Holdable {
	return holdable_create(position)
}

// End the drop exemption only in the simulation phase, never during collision queries.
holdable_update_release_contacts :: proc(state: ^World_State) {
	for &entity in state.entities {
		crate, ok := &entity.(Holdable)
		if !ok || !crate.release_ignore_player do continue
		player := entity_get_player(crate.release_player, state)
		if player == nil ||
		   !physics_overlap_horizontal(
				   collision_aabb_at(crate.position, crate.collider, crate.height),
				   collision_aabb_at(player.position, player.collider, player.height),
			   ) {
			crate.release_ignore_player = false
		}
	}
}
