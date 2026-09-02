package hollie

import "asset"

WOOD_TEXTURE_PATH :: "art/prototype/object.png"
WOOD_SPRITE_PROFILE :: Sprite_Profile {
	world_size = {16, 16},
	anchor     = {0.5, 0.5},
	smooth     = true,
}

holdable_spawn_at :: proc(position: Vec2) -> ^Holdable {
	return entity_create_holdable(position, asset.path(WOOD_TEXTURE_PATH), WOOD_SPRITE_PROFILE)
}
