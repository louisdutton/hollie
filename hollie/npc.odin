package hollie

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
