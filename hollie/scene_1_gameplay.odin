package hollie

import "asset"
import "audio"
import "core:time"
import "gui"
import "input"
import "renderer"
import "tilemap"
import "tween"
import rl "vendor:raylib"

Room :: enum {
	OLIVEWOOD,
	DESERT,
	SMALL_ROOM,
}

ROOM_PATHS := [Room]string {
	.OLIVEWOOD  = "maps/olivewood.map",
	.DESERT     = "maps/desert.map",
	.SMALL_ROOM = "maps/room.map",
}

// Gameplay Screen
@(private = "file")
gameplay_state := struct {
	current_tilemap:    tilemap.TileMap,
	current_room:       Room,
	is_transitioning:   bool,
	transition_opacity: f32,
	pending_room:       Maybe(Room),
	pending_target_door: string,
	doors_enabled:      bool,
} {
	current_room       = .SMALL_ROOM,
	is_transitioning   = false,
	transition_opacity = 0.0,
	pending_room       = nil,
}

init_gameplay_screen :: proc() {
	camera_init()
	dialog_init()
	entity_system_init()
	particle_system_init()
	shader_init()
	gui.init()

	when ODIN_DEBUG {
		editor_init()
	}

	gameplay_load_room(gameplay_state.current_room)
	gameplay_state.doors_enabled = false // Disable doors until players move away from spawn
}

update_gameplay_screen :: proc() {
	if input.is_key_pressed(.P) || input.is_gamepad_button_pressed(.PLAYER_1, .MIDDLE_RIGHT) {
		pause_toggle()
	}

	pause_handle_input()
	pause_update(rl.GetFrameTime())

	when ODIN_DEBUG {
		if input.is_key_pressed(.F1) || input.is_gamepad_button_pressed(.PLAYER_1, .MIDDLE) {
			editor_toggle()
		}

		if editor_is_active() {
			editor_update()
			return
		}

		if input.is_key_pressed(.R) || input.is_gamepad_button_pressed(.PLAYER_1, .MIDDLE_LEFT) {
			room_reload()
		}
	}

	// Handle transition state - switch level at peak opacity
	if pending, has_pending := gameplay_state.pending_room.?;
	   has_pending &&
	   gameplay_state.is_transitioning &&
	   gameplay_state.transition_opacity >= 0.99 {

		gameplay_load_room(pending, gameplay_state.pending_target_door)

		gameplay_state.pending_room = nil
		gameplay_state.pending_target_door = ""
		gameplay_state.doors_enabled = false // Disable doors until players move away

		// Snap camera to new player positions immediately (no lerping)
		camera_snap_to_target()

		// Start fade out
		tween.to(&gameplay_state.transition_opacity, 0.0, .Quadratic_In, 300 * time.Millisecond)
		audio.music_play(game.music)
	}

	// End transition when fade out completes
	if gameplay_state.is_transitioning &&
	   gameplay_state.transition_opacity <= 0.01 &&
	   gameplay_state.pending_room == nil {
		gameplay_state.is_transitioning = false
		gameplay_state.transition_opacity = 0.0
	}

	if !pause_is_active() {
		room_update()
		entity_system_update() // Handles all entities (players, enemies, NPCs, puzzles)

		// Check if doors should be enabled (no players in any door area)
		if !gameplay_state.doors_enabled {
			players := entity_get_players()
			defer delete(players)

			all_players_clear := true
			for player in players {
				if entity_check_door_collision(player.position) != nil {
					all_players_clear = false
					break
				}
			}

			if all_players_clear {
				gameplay_state.doors_enabled = true
			}
		}

		// Check for door collisions with any player
		if !gameplay_state.is_transitioning && gameplay_state.doors_enabled {
			players := entity_get_players()
			defer delete(players)

			for player in players {
				door := entity_check_door_collision(player.position)
				if door != nil {
					gameplay_state.is_transitioning = true
					gameplay_state.doors_enabled = false // Disable doors during transition

					if door.target_room == "desert" {
						gameplay_state.pending_room = .DESERT
						gameplay_state.pending_target_door = door.target_door
					} else if door.target_room == "olivewood" {
						gameplay_state.pending_room = .OLIVEWOOD
						gameplay_state.pending_target_door = door.target_door
					} else if door.target_room == "small_room" {
						gameplay_state.pending_room = .SMALL_ROOM
						gameplay_state.pending_target_door = door.target_door
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

		when ODIN_DEBUG {
			if editor_is_active() {
				editor_draw()
			} else {
				room_draw_puzzle_elements()
				entity_system_draw()
				particle_system_draw()

				// debug colldiers
				room_draw_doors_debug()
				room_draw_puzzle_debug()
			}
		} else {
			room_draw_puzzle_elements()
			entity_system_draw()
			particle_system_draw()
		}
	}

	// ui
	{

		when ODIN_DEBUG {
			if editor_is_active() {
				editor_draw_ui()
				return
			}
		}

		ui_begin()
		defer ui_end()

		room_draw_name()
		dialog_draw()
		draw_transition_overlay()

		pause_draw()
	}
}

unload_gameplay_screen :: proc() {
	when ODIN_DEBUG {
		editor_fini()
	}

	pause_close()
	shader_fini()
	room_fini()
	entity_system_fini()
	particle_system_fini()
}

// TODO: move this elsewhere
draw_transition_overlay :: proc() {
	if gameplay_state.is_transitioning && gameplay_state.transition_opacity > 0.01 {
		alpha := u8(gameplay_state.transition_opacity * 255)
		renderer.draw_rect_i(0, 0, design_width, design_height, renderer.Colour{0, 0, 0, alpha})
	}
}

gameplay_get_current_room :: proc() -> Room {
	return gameplay_state.current_room
}

gameplay_get_current_room_path :: proc() -> string {
	return ROOM_PATHS[gameplay_state.current_room]
}

gameplay_load_room :: proc(room: Room, target_door: string = "") {
	gameplay_state.current_room = room
	map_path := asset.path(ROOM_PATHS[room])

	tilemap_result, ok := tilemap.from_file(map_path)
	assert(ok, "statically-known maps must load")
	gameplay_state.current_tilemap = tilemap_result

	room_init(&gameplay_state.current_tilemap, target_door)
}

// updates the tilemap of the current room
gameplay_update_current_room :: proc(new_tilemap: tilemap.TileMap) {
	gameplay_state.current_tilemap = new_tilemap
}
