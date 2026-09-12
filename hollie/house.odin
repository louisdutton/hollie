package hollie

HOUSE_WALL_HEIGHT :: f32(44)
HOUSE_WALL_SCALE :: f32(8)
HOUSE_ROOF_HEIGHT :: f32(7)
HOUSE_ROOF_OVERHANG :: f32(4)

house_roof_aabb :: proc(position, size: Vec2) -> AABB {
	return {
		min = {
			position.x - HOUSE_ROOF_OVERHANG,
			HOUSE_WALL_HEIGHT,
			position.y - HOUSE_ROOF_OVERHANG,
		},
		max = {
			position.x + size.x + HOUSE_ROOF_OVERHANG,
			HOUSE_WALL_HEIGHT + HOUSE_ROOF_HEIGHT,
			position.y + size.y + HOUSE_ROOF_OVERHANG,
		},
	}
}

// Bounds follow the wall and wide-doorway meshes in res/world/props.
// The doorway's clear opening spans local Z [-0.45, 0.45], up to Y 0.8.
house_wall_aabbs :: proc(position, size: Vec2) -> [6]AABB {
	x0, z0 := position.x, position.y
	x1, z1 := x0 + size.x, z0 + size.y
	center_x := (x0 + x1) / 2
	wall_half := HOUSE_WALL_SCALE * 0.1
	door_half := HOUSE_WALL_SCALE * 0.15
	opening_half := size.x * (0.45 / 1.5)
	height := HOUSE_WALL_HEIGHT
	return {
		{min = {x0, 0, z0 - wall_half}, max = {x1, height, z0 + wall_half}},
		{min = {x0 - wall_half, 0, z0}, max = {x0 + wall_half, height, z1}},
		{min = {x1 - wall_half, 0, z0}, max = {x1 + wall_half, height, z1}},
		{min = {x0, 0, z1 - door_half}, max = {center_x - opening_half, height, z1 + door_half}},
		{min = {center_x + opening_half, 0, z1 - door_half}, max = {x1, height, z1 + door_half}},
		{
			min = {center_x - opening_half, height * 0.8, z1 - door_half},
			max = {center_x + opening_half, height, z1 + door_half},
		},
	}
}
