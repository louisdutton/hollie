package hollie

PROTOTYPE_CHARACTER_PATH :: "art/prototype/character.png"
PROTOTYPE_CHARACTER_PROFILE :: Animation_Profile {
	source_frame_size = {128, 128},
	world_size        = {32, 32},
	anchor            = {0.5, 0.75},
	smooth            = true,
}

// During gameplay prototyping, every character intentionally uses the same
// anonymous still image. The animation arrays remain intact so production
// strips can be restored without changing entity state logic.
goblin_animation_profile := PROTOTYPE_CHARACTER_PROFILE
skeleton_animation_profile := PROTOTYPE_CHARACTER_PROFILE
human_animation_profile := PROTOTYPE_CHARACTER_PROFILE
player_animation_profile := PROTOTYPE_CHARACTER_PROFILE

goblin_animations := [?]Animation {
	{PROTOTYPE_CHARACTER_PATH, 1},
	{PROTOTYPE_CHARACTER_PATH, 1},
	{PROTOTYPE_CHARACTER_PATH, 1},
	{PROTOTYPE_CHARACTER_PATH, 1},
}

skeleton_animations := [?]Animation {
	{PROTOTYPE_CHARACTER_PATH, 1},
	{PROTOTYPE_CHARACTER_PATH, 1},
	{PROTOTYPE_CHARACTER_PATH, 1},
	{PROTOTYPE_CHARACTER_PATH, 1},
}

human_animations := [?]Animation {
	{PROTOTYPE_CHARACTER_PATH, 1},
	{PROTOTYPE_CHARACTER_PATH, 1},
	{PROTOTYPE_CHARACTER_PATH, 1},
	{PROTOTYPE_CHARACTER_PATH, 1},
	{PROTOTYPE_CHARACTER_PATH, 1},
	{PROTOTYPE_CHARACTER_PATH, 1},
}

player_animations := [?]Animation {
	{PROTOTYPE_CHARACTER_PATH, 1},
	{PROTOTYPE_CHARACTER_PATH, 1},
	{PROTOTYPE_CHARACTER_PATH, 1},
	{PROTOTYPE_CHARACTER_PATH, 1},
	{PROTOTYPE_CHARACTER_PATH, 1},
	{PROTOTYPE_CHARACTER_PATH, 1},
	{PROTOTYPE_CHARACTER_PATH, 1},
}
