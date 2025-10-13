package hollie

import "input"

player_spawn_at :: proc(spawn_pos: Vec2, index: input.Player_Index) {
	character_spawn(
		spawn_pos,
		{.PLAYER, .HUMAN, .CAN_MOVE, .CAN_ATTACK, .CAN_ROLL, .CAN_INTERACT},
		"longhair",
		index,
	)
}

player_spawn_both :: proc(spawn_pos_1, spawn_pos_2: Vec2) {
	player_spawn_at(spawn_pos_1, .PLAYER_1)
	player_spawn_at(spawn_pos_2, .PLAYER_2)
}
