package hollie

import "audio"
import "core:time"
import "gui"
import "input"
import "renderer"
import "tilemap"
import "tween"
import rl "vendor:raylib"


// Gameplay Screen
@(private = "file")
gameplay_state := struct {
	grass_room:         RoomResource,
	sand_room:          RoomResource,
	small_room:         RoomResource,
	current_room:       int, // 0 = grass, 1 = sand, 2 = small
	is_transitioning:   bool,
	transition_opacity: f32,
	pending_room:       int,
	pending_player_pos: Vec2,
} {
	current_room       = 0,
	is_transitioning   = false,
	transition_opacity = 0.0,
	pending_room       = -1,
}

init_gameplay_screen :: proc() {
	camera_init()
	dialog_init()
	entity_system_init() // Initialize union-based entities
	particle_system_init()
	shader_init()
	gui.init()
	puzzle_init()

	gameplay_state.grass_room = room_new()
	gameplay_state.sand_room = room_new_sand()
	gameplay_state.small_room = room_new_small()
	room_init(&gameplay_state.grass_room)
}

update_gameplay_screen :: proc() {
	if input.is_key_pressed(.P) || input.is_gamepad_button_pressed(.PLAYER_1, .MIDDLE_RIGHT) {
		pause_toggle()
	}

	pause_handle_input()
	pause_update(rl.GetFrameTime())

	when ODIN_DEBUG {
		if input.is_key_pressed(.R) {
			room_reload()
		}
	}

	// Handle transition state - switch level at peak opacity
	if gameplay_state.is_transitioning &&
	   gameplay_state.transition_opacity >= 0.99 &&
	   gameplay_state.pending_room >= 0 {
		gameplay_state.current_room = gameplay_state.pending_room

		// Load appropriate level
		switch gameplay_state.current_room {
		case 0: room_init(&gameplay_state.grass_room)
		case 1: room_init(&gameplay_state.sand_room)
		case 2: room_init(&gameplay_state.small_room)
		}

		// Position both players
		player1 := entity_get_player(.PLAYER_1)
		player2 := entity_get_player(.PLAYER_2)
		if player1 != nil {
			player1.position = gameplay_state.pending_player_pos
		}
		if player2 != nil {
			player2.position = {
				gameplay_state.pending_player_pos.x + 32,
				gameplay_state.pending_player_pos.y,
			}
		}
		gameplay_state.pending_room = -1

		// Snap camera to new player positions immediately (no lerping)
		camera_snap_to_target()

		// Start fade out
		tween.to(&gameplay_state.transition_opacity, 0.0, .Quadratic_In, 300 * time.Millisecond)
		audio.music_play(game.music)
	}

	// End transition when fade out completes
	if gameplay_state.is_transitioning &&
	   gameplay_state.transition_opacity <= 0.01 &&
	   gameplay_state.pending_room < 0 {
		gameplay_state.is_transitioning = false
		gameplay_state.transition_opacity = 0.0
	}

	if !pause_is_active() {
		room_update()
		entity_system_update() // Handles all entities (players, enemies, NPCs, puzzles)
		puzzle_update()

		// Check for door collisions with any player
		if !gameplay_state.is_transitioning {
			players := entity_get_players()
			defer delete(players)

			for player in players {
				door := room_check_door_collision(player.position)
				if door != nil {
					gameplay_state.is_transitioning = true

					if door.target_room == "desert" {
						gameplay_state.pending_room = 1
						gameplay_state.pending_player_pos = {50, player.position.y}
					} else if door.target_room == "olivewood" {
						gameplay_state.pending_room = 0
						if door.target_door == "from_small_room" {
							// Coming from small room, place on left side
							gameplay_state.pending_player_pos = {50, player.position.y}
						} else {
							// Coming from desert, place on right side
							room_width := f32(50 * 16) // 50 tiles * 16 pixels per tile
							gameplay_state.pending_player_pos = {room_width - 60, player.position.y}
						}
					} else if door.target_room == "small_room" {
						gameplay_state.pending_room = 2
						gameplay_state.pending_player_pos = {32, player.position.y}
					}

					tween.to(
						&gameplay_state.transition_opacity,
						1.0,
						.Quadratic_Out,
						300 * time.Millisecond,
					)
					break
				}
			}
		}

		particle_system_update()
		camera_update()
		dialog_update()
	}
}

draw_gameplay_screen :: proc() {
	// world
	{
		renderer.begin_mode_2d(camera)
		defer renderer.end_mode_2d()

		tilemap.draw(camera)
		room_draw_puzzle_elements() // Draw puzzle sprites in normal mode
		entity_system_draw() // Draw all entities with proper sorting
		particle_system_draw()

		when ODIN_DEBUG {
			room_draw_doors_debug()
			room_draw_puzzle_debug()
		}
	}

	// ui
	{
		ui_begin()
		defer ui_end()

		room_draw_name()
		dialog_draw()
		draw_transition_overlay()

		pause_draw()
	}
}

unload_gameplay_screen :: proc() {
	pause_close()
	shader_fini()
	room_fini()
	entity_system_fini() // Cleanup entities
	particle_system_fini()
	puzzle_fini()
}


draw_transition_overlay :: proc() {
	if gameplay_state.is_transitioning && gameplay_state.transition_opacity > 0.01 {
		alpha := u8(gameplay_state.transition_opacity * 255)
		renderer.draw_rect_i(0, 0, design_width, design_height, renderer.Colour{0, 0, 0, alpha})
	}
}
