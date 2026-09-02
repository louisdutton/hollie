package hollie

import "asset"
import "audio"
import "core:strings"
import "core:time"
import "input"
import "renderer"
import "tilemap"
import "tween"
import rl "vendor:raylib"

INITIAL_ROOM_ID :: "small_room"

@(private)
gameplay_room_registry: Room_Registry

// Gameplay Screen
@(private = "file")
gameplay_state := struct {
	current_tilemap:     tilemap.TileMap,
	current_room_id:     string,
	is_transitioning:    bool,
	transition_opacity:  f32,
	pending_room_id:     Maybe(string),
	pending_target_door: string,
	doors_enabled:       bool,
} {
	current_room_id    = INITIAL_ROOM_ID,
	is_transitioning   = false,
	transition_opacity = 0.0,
	pending_room_id    = nil,
}

when ODIN_DEBUG {
	@(private)
	gameplay_debug_ui_visible := false
}

init_gameplay_screen :: proc() {
	if gameplay_state.current_room_id == "" {
		gameplay_state.current_room_id = INITIAL_ROOM_ID
	}
	maps_directory := asset.path(tilemap.ROOM_FILE_RESOURCE_DIRECTORY)
	defer delete(maps_directory)
	resource_root := asset.path("")
	defer delete(resource_root)
	registry_error: Room_Registry_Error
	gameplay_room_registry, registry_error = room_registry_load(maps_directory, resource_root)
	assert(registry_error.kind == .none, registry_error.message)
	destroy_room_registry_error(&registry_error)

	camera_init()
	dialog_init()
	entity_system_init()
	world_3d_init()
	particle_system_init()
	shader_init()
	when ODIN_DEBUG {
		gameplay_debug_ui_visible = false
		editor_init()
	}

	gameplay_load_room(gameplay_state.current_room_id)
	gameplay_state.doors_enabled = false // Disable doors until players move away from spawn
}

update_gameplay_screen :: proc() {
	if input.is_key_pressed(.P) || input.is_gamepad_button_pressed(.PLAYER_1, .MIDDLE_RIGHT) {
		pause_toggle()
	}

	pause_handle_input(rl.GetFrameTime())

	when ODIN_DEBUG {
		if input.action_pressed(.Editor_Toggle) {
			editor_toggle()
		}

		if editor_is_active() {
			editor_update()
			return
		}

		if input.is_gamepad_button_pressed(.PLAYER_1, .RIGHT_THUMB) {
			gameplay_debug_ui_visible = !gameplay_debug_ui_visible
		}

		if input.is_key_pressed(.R) {
			room_reload()
		}
	}

	// Handle transition state - switch level at peak opacity
	if pending, has_pending := gameplay_state.pending_room_id.?;
	   has_pending &&
	   gameplay_state.is_transitioning &&
	   gameplay_state.transition_opacity >= 0.99 {

		gameplay_load_room(pending, gameplay_state.pending_target_door)

		gameplay_state.pending_room_id = nil
		delete(gameplay_state.pending_target_door)
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
	   gameplay_state.pending_room_id == nil {
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
					target_room, found := room_registry_find(
						&gameplay_room_registry,
						door.target_room,
					)
					if !found do continue

					gameplay_state.is_transitioning = true
					gameplay_state.doors_enabled = false // Disable doors during transition
					gameplay_state.pending_room_id = target_room.id
					delete(gameplay_state.pending_target_door)
					gameplay_state.pending_target_door = strings.clone(door.target_door)

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
	when ODIN_DEBUG {
		if editor_is_active() {
			// The room editor intentionally keeps its direct orthographic 2D view.
			renderer.begin_mode_2d(camera)
			{
				defer renderer.end_mode_2d()
				tilemap.draw(camera)
				editor_draw()
			}
		} else {
			world_3d_draw(gameplay_debug_ui_visible)
		}
	} else {
		world_3d_draw()
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
	tilemap.destroy_tilemap(&gameplay_state.current_tilemap)
	delete(gameplay_state.pending_target_door)
	gameplay_state.pending_target_door = ""
	gameplay_state.pending_room_id = nil
	gameplay_state.current_room_id = ""
	destroy_room_registry(&gameplay_room_registry)
	world_3d_fini()
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

gameplay_get_current_room :: proc() -> string {
	return gameplay_state.current_room_id
}

gameplay_get_current_room_path :: proc() -> string {
	room, found := room_registry_find(&gameplay_room_registry, gameplay_state.current_room_id)
	assert(found, "current room must be registered")
	return room.path
}

gameplay_get_room_registry :: proc() -> ^Room_Registry {
	return &gameplay_room_registry
}

gameplay_load_room :: proc(room_id: string, target_door: string = "") {
	room, found := room_registry_find(&gameplay_room_registry, room_id)
	assert(found, "requested room must be registered")
	resource_root := asset.path("")
	defer delete(resource_root)
	tilemap_result, load_error := tilemap.load_tilemap_file(room.path, resource_root)
	assert(load_error.kind == .none, load_error.message)
	tilemap.destroy_room_file_io_error(&load_error)

	previous_tilemap := gameplay_state.current_tilemap
	gameplay_state.current_room_id = room.id
	gameplay_state.current_tilemap = tilemap_result
	room_init(&gameplay_state.current_tilemap, target_door)
	tilemap.destroy_tilemap(&previous_tilemap)
}

// updates the tilemap of the current room
gameplay_update_current_room :: proc(new_tilemap: tilemap.TileMap) {
	gameplay_state.current_tilemap = new_tilemap
}
