package hollie

import "core:math"
import "graphics"
import "input"
import "window"

CAMERA_SMOOTH: f32 : 0.1 // interpolation factor used when following the target
ZOOM_RATE :: 0.6 // zoom adjustment per second at full input
ZOOM_DEFAULT :: 1.8
ZOOM_MAX :: 10.0
ZOOM_MIN :: 1.0
ZOOM_DIALOG :: 3.0 // zoom level used during dialogue

// Camera state
camera_bounds: graphics.Rect
camera_height: f32
camera_grounded_time: f32
CAMERA_HEIGHT_DEAD_ZONE :: f32(32) // Slightly taller than a regular jump.
camera := graphics.Camera2D {
	zoom = camera_base_zoom,
}

// this is an internal value that should not be controlled directly by user input
screen_scale: f32 = 1.0

// this is the user-controlled zoom value
camera_base_zoom: f32 = ZOOM_DEFAULT

camera_relative_movement :: proc(direction: Vec2) -> Vec2 {
	view := rendering_camera()
	forward := Vec2{view.target.x - view.position.x, view.target.z - view.position.z}
	length := math.sqrt(forward.x * forward.x + forward.y * forward.y)
	if length == 0 do return direction
	forward /= length
	right := Vec2{-forward.y, forward.x}
	// Input Y increases down the screen, opposite the camera's forward direction.
	return right * direction.x - forward * direction.y
}

camera_follow_target :: proc() {
	// Get both players and follow their center point using new entity system
	player1 := entity_get_player(.Player_1)
	player2 := entity_get_player(.Player_2)

	target_pos: Vec2
	if player1 != nil && player2 != nil {
		// Follow center point between both players
		target_pos = (player1.position + player2.position) / 2
	} else if player1 != nil {
		target_pos = player1.position
	} else if player2 != nil {
		target_pos = player2.position
	} else {
		return
	}
	dt := min(graphics.get_frame_time(), 0.1)
	if camera_player_grounded(player1) && camera_player_grounded(player2) {
		camera_grounded_time += dt
	} else {
		camera_grounded_time = 0
	}
	height_difference := camera_players_height(player1, player2) - camera_height
	if camera_grounded_time > 0.15 {
		camera_height = math.lerp(
			camera_height,
			camera_players_height(player1, player2),
			1 - math.exp(-3 * dt),
		)
	} else if abs(height_difference) > CAMERA_HEIGHT_DEAD_ZONE {
		target_height :=
			height_difference > 0 ? camera_height + height_difference - CAMERA_HEIGHT_DEAD_ZONE : camera_height + height_difference + CAMERA_HEIGHT_DEAD_ZONE
		height_blend := 1 - math.exp(-3 * min(graphics.get_frame_time(), 0.1))
		camera_height = math.lerp(camera_height, target_height, height_blend)
	}

	scale := 2 * camera.zoom
	x_offset := f32(window.get_screen_width()) / scale
	y_offset := f32(window.get_screen_height()) / scale

	max_x := camera_bounds.x + camera_bounds.width - x_offset * 2
	max_y := camera_bounds.y + camera_bounds.height - y_offset * 2
	min_x := camera_bounds.x
	min_y := camera_bounds.y

	camera.target.x = clamp(
		math.lerp(camera.target.x, target_pos.x - x_offset, CAMERA_SMOOTH),
		min_x,
		max_x,
	)
	camera.target.y = clamp(
		math.lerp(camera.target.y, target_pos.y - y_offset, CAMERA_SMOOTH),
		min_y,
		max_y,
	)
}

camera_init :: proc() {
	screen_scale = window.get_ui_scale()
	camera_update()
}

camera_update :: proc() {
	camera_update_zoom()
	camera_follow_target()
}

camera_update_zoom :: proc() {
	if window.is_resized() {
		screen_scale = window.get_ui_scale()
	}

	zoom_input := input.get_zoom()
	if graphics.is_key_down(.MINUS) {
		zoom_input -= 1
	} else if graphics.is_key_down(.EQUAL) {
		zoom_input += 1
	}
	camera_base_zoom = clamp(
		camera_base_zoom + clamp(zoom_input, -1, 1) * ZOOM_RATE * graphics.get_frame_time(),
		ZOOM_MIN,
		ZOOM_MAX,
	)

	camera.zoom = camera_base_zoom * screen_scale
}

camera_set_bounds :: proc(bounds: graphics.Rect) {
	camera_bounds = bounds
}

camera_snap_to_target :: proc() {
	// Get both players and snap to their center point using new entity system
	player1 := entity_get_player(.Player_1)
	player2 := entity_get_player(.Player_2)

	target_pos: Vec2
	if player1 != nil && player2 != nil {
		// Follow center point between both players
		target_pos = (player1.position + player2.position) / 2
	} else if player1 != nil {
		target_pos = player1.position
	} else if player2 != nil {
		target_pos = player2.position
	} else {
		return
	}
	camera_height = camera_players_height(player1, player2)
	camera_grounded_time = 0

	scale := 2 * camera.zoom
	x_offset := f32(window.get_screen_width()) / scale
	y_offset := f32(window.get_screen_height()) / scale

	max_x := camera_bounds.x + camera_bounds.width - x_offset * 2
	max_y := camera_bounds.y + camera_bounds.height - y_offset * 2
	min_x := camera_bounds.x
	min_y := camera_bounds.y

	camera.target.x = clamp(target_pos.x - x_offset, min_x, max_x)
	camera.target.y = clamp(target_pos.y - y_offset, min_y, max_y)
}

camera_players_height :: proc(first, second: ^Player) -> f32 {
	if first != nil && second != nil do return (first.height + second.height) / 2
	if first != nil do return first.height
	if second != nil do return second.height
	return 0
}

camera_player_grounded :: proc(player: ^Player) -> bool {
	if player == nil do return true
	if animal := riding_animal_for_player(player.index); animal != nil {
		return(
			player.mount_elapsed >= player.mount_duration &&
			(animal.grounded || animal.swimming) \
		)
	}
	return player.grounded || player.swimming
}
