package hollie

import "core:testing"

@(test)
test_obstacle_queries_do_not_end_drop_exemptions :: proc(t: ^testing.T) {
	state: World_State
	defer world_fini(&state)
	player_id := entity_id(
		entity_add(
			Player{transform = {position = {20, 20}}, collider = {size = {4, 4, 4}}},
			&state,
		)^,
	)
	crate_id := entity_id(
		entity_add(
			Holdable {
				transform = {position = {40, 40}},
				collider = {size = {4, 4, 4}, solid = true},
				release_ignore_player = true,
			},
			&state,
		)^,
	)
	player := entity_find(player_id, &state)
	obstacles := physics_obstacles(player, &state)
	defer delete(obstacles)
	testing.expect_value(t, len(obstacles), 1)
	testing.expect(t, entity_get_holdable(crate_id, &state).release_ignore_player)
	holdable_update_release_contacts(&state)
	testing.expect(t, !entity_get_holdable(crate_id, &state).release_ignore_player)
	// Moving back into the crate cannot revive the exemption.
	entity_get_carrier(player_id, &state).position = {40, 40}
	again := physics_obstacles(player, &state)
	defer delete(again)
	testing.expect_value(t, len(again), 1)
}

@(test)
test_drop_exemption_persists_while_player_overlaps :: proc(t: ^testing.T) {
	state: World_State
	defer world_fini(&state)
	player_id := entity_id(entity_add(Player{collider = {size = {4, 4, 4}}}, &state)^)
	crate_id := entity_id(
		entity_add(
			Holdable{collider = {size = {4, 4, 4}, solid = true}, release_ignore_player = true},
			&state,
		)^,
	)
	obstacles := physics_obstacles(entity_find(player_id, &state), &state)
	defer delete(obstacles)
	testing.expect_value(t, len(obstacles), 0)
	holdable_update_release_contacts(&state)
	testing.expect(t, entity_get_holdable(crate_id, &state).release_ignore_player)
}
