package hollie

Holdable :: struct {
	using transform: Transform,
	using collider:  Collider,
	// TODO: Replace persistent pointers into the dynamic entity array with stable references.
	held_by:         ^Player,
}

holdable_create :: proc(position: Vec2) -> ^Holdable {
	holdable := Holdable {
		transform = {position = position, grounded = true},
		collider = model_crate_collider(true),
	}
	append(&entities, holdable)
	return &entities[len(entities) - 1].(Holdable)
}

holdable_spawn_at :: proc(position: Vec2) -> ^Holdable {
	return holdable_create(position)
}
