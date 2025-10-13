package hollie

import "input"

player_spawn_at :: proc(spawn_pos: Vec2, index: input.Player_Index) {
	entity_create_player(spawn_pos, index, player_animations[:])
}

player_spawn_both :: proc(spawn_pos_1, spawn_pos_2: Vec2) {
	player_spawn_at(spawn_pos_1, .PLAYER_1)
	player_spawn_at(spawn_pos_2, .PLAYER_2)
}
