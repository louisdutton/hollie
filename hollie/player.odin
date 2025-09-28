package hollie

import "asset"

player_frame_counts := [?]int{9, 8, 9, 13, 10, 10}

player_spawn_at :: proc(spawn_pos: Vec2) {
	composite_textures := create_composite_player_textures("longhair")

	character_create_with_textures(
		spawn_pos,
		.PLAYER,
		.HUMAN,
		{.CAN_MOVE, .CAN_ATTACK, .CAN_ROLL, .CAN_INTERACT},
		composite_textures[:],
		player_frame_counts[:],
	)
}
