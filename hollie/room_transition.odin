package hollie

Door :: struct {
	using transform: Transform,
	using collider:  Collider,
	target_room:     string,
	target_door:     string,
}

door_create :: proc(position, size: Vec2, target_room, target_door: string) -> ^Door {
	door := Door {
		transform = {position = position},
		collider = {size = {size.x, RENDERING_GATE_HEIGHT, size.y}, solid = false},
		target_room = target_room,
		target_door = target_door,
	}
	append(&entities, door)
	return &entities[len(entities) - 1].(Door)
}
