package hollie

import "asset"

WOOD_TEXTURE_PATH :: "art/elements/crops/wood.png"
WOOD_SPRITE_PROFILE :: Sprite_Profile {
	world_size = {11, 11},
	anchor     = {8.0 / 11.0, 8.0 / 11.0},
}

holdable_spawn_at :: proc(position: Vec2) -> ^Holdable {
	return entity_create_holdable(position, asset.path(WOOD_TEXTURE_PATH), WOOD_SPRITE_PROFILE)
}
