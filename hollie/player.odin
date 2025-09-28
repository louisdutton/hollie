package hollie

player_spawn_at :: proc(spawn_pos: Vec2) {
	character_spawn(
		spawn_pos,
		{.PLAYER, .HUMAN, .CAN_MOVE, .CAN_ATTACK, .CAN_ROLL, .CAN_INTERACT},
		"longhair",
	)
}
