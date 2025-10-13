package hollie

import "asset"

goblin_animations := [?]Animation {
	{asset.path("art/characters/goblin/png/spr_idle_strip9.png"), 9},
	{asset.path("art/characters/goblin/png/spr_run_strip8.png"), 8},
	{asset.path("art/characters/goblin/png/spr_jump_strip9.png"), 9},
	{asset.path("art/characters/goblin/png/spr_death_strip13.png"), 13},
}

skeleton_animations := [?]Animation {
	{asset.path("art/characters/skeleton/png/skeleton_idle_strip6.png"), 6},
	{asset.path("art/characters/skeleton/png/skeleton_walk_strip8.png"), 8},
	{asset.path("art/characters/skeleton/png/skeleton_jump_strip10.png"), 10},
	{asset.path("art/characters/skeleton/png/skeleton_death_strip10.png"), 10},
}

human_animations := [?]Animation {
	{asset.path("art/characters/human/idle/base_idle_strip9.png"), 9},
	{asset.path("art/characters/human/run/base_run_strip8.png"), 8},
	{asset.path("art/characters/human/jump/base_jump_strip9.png"), 9},
	{asset.path("art/characters/human/death/base_death_strip13.png"), 13},
	{asset.path("art/characters/human/attack/base_attack_strip10.png"), 10},
	{asset.path("art/characters/human/roll/base_roll_strip10.png"), 10},
}

player_animations := [?]Animation {
	{asset.path("art/characters/player/idle.png"), 9},
	{asset.path("art/characters/player/run.png"), 8},
	{asset.path("art/characters/player/jump.png"), 9},
	{asset.path("art/characters/player/death.png"), 13},
	{asset.path("art/characters/player/attack.png"), 10},
	{asset.path("art/characters/player/roll.png"), 10},
}
