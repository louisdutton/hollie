package hollie

import "core:testing"

@(test)
test_entity_relationships_survive_growth_and_unordered_removal :: proc(t: ^testing.T) {
	state: World_State
	defer world_fini(&state)
	// Removing this first element will move the last entity into its slot.
	entity_add(Enemy{}, &state)
	player_id := entity_id(entity_add(Player{}, &state)^)
	crate_id := entity_id(entity_add(Holdable{}, &state)^)
	entity_get_carrier(player_id, &state).carrying = crate_id
	entity_get_holdable(crate_id, &state).held_by = player_id
	for i in 0 ..< 256 do entity_add(Enemy{}, &state)
	entity_remove_at(0, &state)
	player := entity_get_carrier(player_id, &state)
	crate := entity_get_holdable(crate_id, &state)
	testing.expect(t, player != nil && crate != nil)
	testing.expect_value(t, player.carrying, crate_id)
	testing.expect_value(t, crate.held_by, player_id)
	// Remove a non-last entity while the crate occupies the last slot.
	for len(state.entities) > 3 do entity_remove_at(len(state.entities) - 1, &state)
	entity_remove_at(0, &state)
	testing.expect_value(t, entity_get_carrier(player_id, &state).carrying, crate_id)
	testing.expect_value(t, entity_get_holdable(crate_id, &state).held_by, player_id)
	testing.expect(t, entity_find(0, &state) == nil)
}

@(test)
test_entity_removal_clears_relationships_and_ids_do_not_recur :: proc(t: ^testing.T) {
	state: World_State
	defer world_fini(&state)
	player_id := entity_id(entity_add(Player{}, &state)^)
	crate_id := entity_id(entity_add(Holdable{}, &state)^)
	entity_get_carrier(player_id, &state).carrying = crate_id
	entity_get_holdable(crate_id, &state).held_by = player_id
	entity_remove_at(0, &state)
	testing.expect(t, entity_get_carrier(player_id, &state) == nil)
	testing.expect_value(t, entity_get_holdable(crate_id, &state).held_by, Entity_Id(0))
	testing.expect(t, entity_get_carrier(crate_id, &state) == nil)
	world_clear_entities(&state)
	replacement_id := entity_id(entity_add(Holdable{}, &state)^)
	testing.expect(t, replacement_id != crate_id && replacement_id != player_id)
	testing.expect(t, entity_find(crate_id, &state) == nil)
}

@(test)
test_removing_carried_item_clears_player_handle :: proc(t: ^testing.T) {
	state: World_State
	defer world_fini(&state)
	crate_id := entity_id(entity_add(Holdable{}, &state)^)
	player_id := entity_id(entity_add(Player{}, &state)^)
	entity_get_carrier(player_id, &state).carrying = crate_id
	entity_remove_at(0, &state)
	testing.expect_value(t, entity_get_carrier(player_id, &state).carrying, Entity_Id(0))
}
