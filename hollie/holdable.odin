package hollie

import "asset"

WOOD_TEXTURE_PATH :: "art/elements/crops/wood.png"

holdable_spawn_at :: proc(position: Vec2) -> ^Holdable {
	return entity_create_holdable(position, asset.path(WOOD_TEXTURE_PATH))
}
