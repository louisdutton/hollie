package hollie

import "tilemap"
import rl "vendor:raylib"

Transform :: struct {
	position: Vec2,
	velocity: Vec2,
}

Movement :: struct {
	move_speed:       f32,
	roll_speed:       f32,
	facing_direction: Vec2,
	is_rolling:       bool,
	roll_timer:       u32,
	is_busy:          bool,
}

movement_move :: proc(moving_entity: ^Entity, transform: ^Transform, collider: ^Collider) {
	dt := rl.GetFrameTime()
	next_pos := transform.position + transform.velocity * dt
	final_pos := transform.position

	test_pos_x := Vec2{next_pos.x, transform.position.y}
	test_rect_x := collision_rect_at(test_pos_x, collider^)
	if !collision_check_solid(test_pos_x, collider.size, moving_entity) &&
	   !tilemap.check_collision(test_rect_x) {
		final_pos.x = next_pos.x
	}

	test_pos_y := Vec2{final_pos.x, next_pos.y}
	test_rect_y := collision_rect_at(test_pos_y, collider^)
	if !collision_check_solid(test_pos_y, collider.size, moving_entity) &&
	   !tilemap.check_collision(test_rect_y) {
		final_pos.y = next_pos.y
	}

	room_bounds := room_get_collision_bounds()
	half_width := collider.size.x / 2
	half_height := collider.size.y / 2
	transform.position.x = clamp(
		final_pos.x,
		room_bounds.x + half_width,
		room_bounds.x + room_bounds.width - half_width,
	)
	transform.position.y = clamp(
		final_pos.y,
		room_bounds.y + half_height,
		room_bounds.y + room_bounds.height - half_height,
	)
}

movement_update_positions :: proc() {
	for &entity in entities {
		switch &e in entity {
		case Player: movement_move(&entity, &e.transform, &e.collider)
		case Enemy: movement_move(&entity, &e.transform, &e.collider)
		case Npc: movement_move(&entity, &e.transform, &e.collider)
		case Pressure_Plate, Gate, Holdable, Door: continue
		}
	}
}
