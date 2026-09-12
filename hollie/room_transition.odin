package hollie

import "graphics"

Door :: struct {
	using transform: Transform,
	using collider:  Collider,
	target_room:     string,
	target_door:     string,
}

door_create :: proc(position, size: Vec2, target_room, target_door: string) -> ^Door {
	door := Door {
		transform = {position = position},
		collider = {size = {size.x, RENDERING_GATE_HEIGHT, size.y}, solid = false},
		target_room = target_room,
		target_door = target_door,
	}
	value := entity_add(door, &world)
	return &value^.(Door)
}

draw_transition_overlay :: proc(opacity: f32) {
	if opacity > 0.01 {
		alpha := u8(opacity * 255)
		graphics.draw_rect_i(0, 0, design_width, design_height, graphics.Colour{0, 0, 0, alpha})
	}
}
