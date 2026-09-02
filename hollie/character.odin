package hollie

PROTOTYPE_CHARACTER_PROFILE :: Animation_Profile {
	source_frame_size = {128, 128},
	world_size        = {32, 32},
	anchor            = {0.5, 0.75},
	smooth            = true,
}

PROTOTYPE_IDLE_PATH :: "art/prototype/animations/idle.png"
PROTOTYPE_RUN_PATH :: "art/prototype/animations/run.png"
PROTOTYPE_JUMP_PATH :: "art/prototype/animations/jump.png"
PROTOTYPE_DEATH_PATH :: "art/prototype/animations/death.png"
PROTOTYPE_ATTACK_PATH :: "art/prototype/animations/attack.png"
PROTOTYPE_ROLL_PATH :: "art/prototype/animations/roll.png"
PROTOTYPE_CARRY_PATH :: "art/prototype/animations/carry.png"

// Every character intentionally shares one anonymous prototype character, but
// retains the states and frame counts of its original animation set.
goblin_animation_profile := PROTOTYPE_CHARACTER_PROFILE
skeleton_animation_profile := PROTOTYPE_CHARACTER_PROFILE
human_animation_profile := PROTOTYPE_CHARACTER_PROFILE
player_animation_profile := PROTOTYPE_CHARACTER_PROFILE

goblin_animations := [?]Animation {
	{PROTOTYPE_IDLE_PATH, 9},
	{PROTOTYPE_RUN_PATH, 8},
	{PROTOTYPE_JUMP_PATH, 9},
	{PROTOTYPE_DEATH_PATH, 13},
}

skeleton_animations := [?]Animation {
	{PROTOTYPE_IDLE_PATH, 6},
	{PROTOTYPE_RUN_PATH, 8},
	{PROTOTYPE_JUMP_PATH, 10},
	{PROTOTYPE_DEATH_PATH, 10},
}

human_animations := [?]Animation {
	{PROTOTYPE_IDLE_PATH, 9},
	{PROTOTYPE_RUN_PATH, 8},
	{PROTOTYPE_JUMP_PATH, 9},
	{PROTOTYPE_DEATH_PATH, 13},
	{PROTOTYPE_ATTACK_PATH, 10},
	{PROTOTYPE_ROLL_PATH, 10},
}

player_animations := [?]Animation {
	{PROTOTYPE_IDLE_PATH, 9},
	{PROTOTYPE_RUN_PATH, 8},
	{PROTOTYPE_JUMP_PATH, 9},
	{PROTOTYPE_DEATH_PATH, 13},
	{PROTOTYPE_ATTACK_PATH, 10},
	{PROTOTYPE_ROLL_PATH, 10},
	{PROTOTYPE_CARRY_PATH, 8},
}
