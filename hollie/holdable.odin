package hollie

holdable_spawn_at :: proc(position: Vec2) -> ^Holdable {
	return entity_create_holdable(position)
}
