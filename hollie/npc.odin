package hollie

VILLAGER_DIALOG := []Dialog_Message {
	{text = "Hello there, traveler!", speaker = "Village NPC"},
	{text = "Welcome to our peaceful village.", speaker = "Village NPC"},
	{text = "Feel free to explore around.", speaker = "Village NPC"},
}

Npc :: struct {
	using transform: Transform,
	using collider:  Collider,
	using health:    Health,
	using movement:  Movement,
	using ai:        Ai,
	using anim_data: Animator,
	dialog_messages: []Dialog_Message,
}

npc_create :: proc(
	position: Vec2,
	animations: []Animation,
	dialog_messages: []Dialog_Message = {},
) -> ^Npc {
	npc := Npc {
		transform = {position = position},
		collider = model_character_collider(true),
		health = {current = 50, max = 50},
		movement = {move_speed = 30, facing_direction = {1, 0}},
		dialog_messages = dialog_messages,
	}
	if len(animations) > 0 do animation_init(&npc.anim_data, animations)

	append(&entities, npc)
	return &entities[len(entities) - 1].(Npc)
}

npc_spawn_at :: proc(position: Vec2) -> ^Npc {
	return npc_create(position, human_animations[:], VILLAGER_DIALOG)
}

npc_get_all :: proc() -> [dynamic]^Npc {
	npcs := make([dynamic]^Npc)
	for &entity in entities {
		if npc, ok := &entity.(Npc); ok {
			append(&npcs, npc)
		}
	}
	return npcs
}

// returns the first npc within the provided radius
npc_get_in_range :: proc(pos: Vec2, radius: f32) -> ^Npc {
	for &entity in entities {
		if npc, ok := &entity.(Npc);
		   ok && len(npc.dialog_messages) > 0 && get_distance(npc.position, pos) <= radius {
			return npc
		}
	}

	return nil
}
