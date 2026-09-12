package hollie

import "core:math"
import "graphics"
import "input"
import "tilemap"

// Bank around the travel direction, into lateral acceleration. Angles are radians.
riding_turn_lean :: proc(lean: f32, previous_velocity, velocity: Vec2, dt: f32) -> f32 {
	if dt <= 0 do return lean
	speed := math.sqrt(velocity.x * velocity.x + velocity.y * velocity.y)
	target: f32
	if speed > 0 {
		lateral_acceleration :=
			(previous_velocity.x * velocity.y - previous_velocity.y * velocity.x) / (speed * dt)
		speed_weight := clamp((speed / RIDING_MOVEMENT_PROFILE.max_speed - 0.35) / 0.65, 0, 1)
		target =
			clamp(lateral_acceleration / RIDING_MOVEMENT_PROFILE.acceleration, -1, 1) *
			speed_weight *
			math.to_radians(f32(18))
	}
	return lean + (target - lean) * (1 - math.exp(-10 * dt))
}

// Store the player index on the animal, avoiding pointers into the entity array.
riding_animal_for_player :: proc(index: input.Player_Index) -> ^Enemy {
	for &entity in entities {
		if animal, ok := &entity.(Enemy); ok && animal.mounted && animal.rider == index do return animal
	}
	return nil
}

riding_can_mount :: proc(player: ^Player, animal: ^Enemy) -> bool {
	if animal_model_for_kind(animal.kind) == nil ||
	   animal.mounted ||
	   animal.is_dying ||
	   animal.is_busy ||
	   player.is_busy ||
	   player.carrying != nil ||
	   !player.grounded ||
	   !animal.grounded {
		return false
	}
	if abs(player.height - animal.height) > PHYSICS_STEP_HEIGHT do return false
	a := collision_aabb_at(player.position, player.collider, player.height)
	b := collision_aabb_at(animal.position, animal.collider, animal.height)
	dx := max(max(a.min.x - b.max.x, b.min.x - a.max.x), 0)
	dz := max(max(a.min.z - b.max.z, b.min.z - a.max.z), 0)
	return dx * dx + dz * dz <= PLAYER_INTERACT_RANGE * PLAYER_INTERACT_RANGE
}

riding_seat_offset :: proc(facing: Vec2, seat: Vec3, rider_seat_height: f32) -> Vec3 {
	angle := math.to_radians(geometry_facing_angle(facing) + 90)
	sine, cosine := math.sin(angle), math.cos(angle)
	return {
		cosine * seat.x + sine * seat.z,
		seat.y - rider_seat_height,
		-sine * seat.x + cosine * seat.z,
	}
}

riding_combined_collider :: proc(
	animal: ^Enemy,
	rider: Collider,
	seat: Vec3,
	rider_seat_height: f32,
) -> Collider {
	offset := riding_seat_offset(animal.facing_direction, seat, rider_seat_height)
	min_corner := animal.collider.offset
	max_corner := min_corner + animal.collider.size
	for axis in 0 ..< 3 {
		min_corner[axis] = min(min_corner[axis], offset[axis] + rider.offset[axis])
		max_corner[axis] = max(
			max_corner[axis],
			offset[axis] + rider.offset[axis] + rider.size[axis],
		)
	}
	return {offset = min_corner, size = max_corner - min_corner, solid = true}
}

riding_movement_collider :: proc(animal: ^Enemy) -> Collider {
	if !animal.mounted do return animal.collider
	model := animal_model_for_kind(animal.kind)
	return riding_combined_collider(
		animal,
		model_assets.riding_collider,
		model.seat,
		model_assets.riding_seat_height,
	)
}

riding_sync_player :: proc(player: ^Player, animal: ^Enemy) {
	model := animal_model_for_kind(animal.kind)
	offset := riding_seat_offset(
		animal.facing_direction,
		model.seat,
		model_assets.riding_seat_height,
	)
	player.position = animal.position + Vec2{offset.x, offset.z}
	player.height = animal.height + offset.y
	player.velocity = animal.velocity
	player.vertical_velocity = animal.vertical_velocity
	player.grounded = false // The animal, rather than the rider, bears weight on the ground.
	player.facing_direction = animal.facing_direction
}

riding_sync_players :: proc() {
	for &entity in entities {
		if animal, ok := &entity.(Enemy); ok && animal.mounted {
			if player := entity_get_player(animal.rider); player != nil do riding_sync_player(player, animal)
		}
	}
}

riding_try_mount :: proc(player: ^Player) -> bool {
	if riding_animal_for_player(player.index) != nil do return false
	nearest: ^Enemy
	nearest_distance := f32(1e9)
	for &entity in entities {
		animal, ok := &entity.(Enemy)
		if !ok || !riding_can_mount(player, animal) do continue
		model := animal_model_for_kind(animal.kind)
		collider := riding_combined_collider(
			animal,
			model_assets.riding_collider,
			model.seat,
			model_assets.riding_seat_height,
		)
		if collision_check_solid(animal.position, collider, height = animal.height) do continue
		aabb := collision_aabb_at(animal.position, collider, animal.height)
		bounds := room_get_collision_bounds()
		if aabb.min.x < bounds.x ||
		   aabb.max.x > bounds.x + bounds.width ||
		   aabb.min.z < bounds.y ||
		   aabb.max.z > bounds.y + bounds.height ||
		   tilemap.check_collision(aabb) {
			continue
		}
		distance := get_distance(player.position, animal.position)
		if distance < nearest_distance do nearest, nearest_distance = animal, distance
	}
	if nearest == nil do return false
	nearest.mounted = true
	nearest.turn_lean = 0
	nearest.rider = player.index
	nearest.velocity = {}
	riding_sync_player(player, nearest)
	return true
}

riding_find_dismount :: proc(
	player: ^Player,
	animal: ^Enemy,
	obstacles: []AABB,
	bounds: graphics.Rect,
	collide_tiles: bool = false,
) -> (
	Vec2,
	f32,
	bool,
) {
	forward := animal.facing_direction
	if forward == (Vec2{}) do forward = {0, 1}
	right := Vec2{forward.y, -forward.x}
	directions := [8]Vec2 {
		right,
		-right,
		-forward,
		forward,
		right - forward,
		-right - forward,
		right + forward,
		-right + forward,
	}
	height := animal.grounded ? animal.height : player.height
	animal_bounds := collision_aabb_at(animal.position, animal.collider, animal.height)
	start := collision_aabb_at(animal.position, player.collider, height)
	for direction in directions {
		position := player_drop_position(
			animal.position,
			direction,
			animal.collider,
			player.collider,
		)
		aabb := collision_aabb_at(position, player.collider, height)
		if aabb.min.x < bounds.x ||
		   aabb.max.x > bounds.x + bounds.width ||
		   aabb.min.z < bounds.y ||
		   aabb.max.z > bounds.y + bounds.height {
			continue
		}
		if physics_blocked(aabb, obstacles, collide_tiles) do continue
		swept := AABB {
			min = {min(start.min.x, aabb.min.x), start.min.y, min(start.min.z, aabb.min.z)},
			max = {max(start.max.x, aabb.max.x), start.max.y, max(start.max.z, aabb.max.z)},
		}
		blocked := collide_tiles && tilemap.check_collision(swept)
		for obstacle in obstacles {
			if obstacle.min == animal_bounds.min && obstacle.max == animal_bounds.max do continue
			if aabbs_intersect(swept, obstacle) do blocked = true
		}
		if !blocked do return position, height, true
	}
	return {}, 0, false
}

riding_dismount :: proc(player: ^Player, animal: ^Enemy) -> bool {
	obstacles := physics_obstacles(nil)
	defer delete(obstacles)
	append(&obstacles, collision_aabb_at(animal.position, animal.collider, animal.height))
	position, height, clear := riding_find_dismount(
		player,
		animal,
		obstacles[:],
		room_get_collision_bounds(),
		true,
	)
	if !clear do return false
	player.position = position
	player.height = height
	player.velocity = animal.velocity
	player.vertical_velocity = animal.vertical_velocity
	player.grounded = false
	animal.mounted = false
	animal.turn_lean = 0
	animal.velocity = {}
	return true
}
