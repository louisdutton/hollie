package hollie

VILLAGER_DIALOG := []Dialog_Message {
	{text = "Hello there, traveler!", speaker = "Village NPC"},
	{text = "Welcome to our peaceful village.", speaker = "Village NPC"},
	{text = "Feel free to explore around.", speaker = "Village NPC"},
}

npc_spawn_at :: proc(position: Vec2) -> ^NPC {
	return entity_create_npc(
		position,
		human_animations[:],
		human_animation_profile,
		VILLAGER_DIALOG,
	)
}

npc_get_all :: proc() -> [dynamic]^NPC {
	npcs := make([dynamic]^NPC)
	for &entity in entities {
		if npc, ok := &entity.(NPC); ok {
			append(&npcs, npc)
		}
	}
	return npcs
}

// returns the first npc within the provided radius
npc_get_in_range :: proc(pos: Vec2, radius: f32) -> ^NPC {
	for &entity in entities {
		if npc, ok := &entity.(NPC);
		   ok && len(npc.dialog_messages) > 0 && get_distance(npc.position, pos) <= radius {
			return npc
		}
	}

	return nil
}
