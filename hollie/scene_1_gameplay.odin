package hollie

import "audio"
import "core:slice"
import "core:time"
import "gui"
import "input"
import "renderer"
import "tilemap"
import "tween"

// Draw all characters sorted by y position
// we can potentially avoid double iteration with a custom sort
draw_entities_sorted :: proc() {
	slice.sort_by(characters[:], proc(a, b: Character) -> bool {
		return a.position.y < b.position.y
	})

	for &character in characters {
		character_draw(&character)
	}
}


// Gameplay Screen
@(private = "file")
gameplay_state := struct {
	grass_room:         RoomResource,
	sand_room:          RoomResource,
	current_room:       int, // 0 = grass, 1 = sand
	is_transitioning:   bool,
	transition_opacity: f32,
	pending_room:      int,
	pending_player_pos: Vec2,
} {
	current_room      = 0,
	is_transitioning   = false,
	transition_opacity = 0.0,
	pending_room      = -1,
}

init_gameplay_screen :: proc() {
	camera_init()
	dialog_init()
	character_system_init()
	particle_system_init()
	shader_init()
	gui.init()

	gameplay_state.grass_room = room_new()
	gameplay_state.sand_room = room_new_sand()
	room_init(&gameplay_state.grass_room)
}

// FIXME: putting this in stack memory causes uaf in dialog
test_messages := []Dialog_Message {
	{text = "Hi there Hollie! It's me, Basil!", speaker = "Basil"},
	{text = "Greetings Basil.", speaker = "Hollie"},
	{text = "Good luck on your journey.", speaker = "Basil"},
	{text = "Thanks!", speaker = "Hollie"},
}

update_gameplay_screen :: proc() {
	// Handle pause toggle
	if input.is_key_pressed(.P) || input.is_gamepad_button_pressed(input.PLAYER_1, .MIDDLE_RIGHT) {
		pause_toggle()
	}

	// Handle pause menu navigation
	pause_handle_input()

	if input.is_key_pressed(.R) {
		room_reload()
	}

	if input.is_key_pressed(.T) && !dialog_is_active() {
		dialog_start(test_messages)
	}

	// Check for level transitions based on player position
	current_player := character_get_player()
	if current_player != nil && !gameplay_state.is_transitioning {
		player_pos := current_player.position
		level_width := f32(50 * 16) // 50 tiles * 16 pixels per tile

		// Transition to sand level (right side) - trigger just before camera bounds
		if gameplay_state.current_room == 0 && player_pos.x >= 785 {
			gameplay_state.is_transitioning = true
			gameplay_state.pending_room = 1
			gameplay_state.pending_player_pos = {50, player_pos.y}
			tween.to(
				&gameplay_state.transition_opacity,
				1.0,
				.Quadratic_Out,
				300 * time.Millisecond,
			)
		} else if gameplay_state.current_room == 1 && player_pos.x <= 15 {
			// Transition to grass level (left side) - trigger near left edge
			gameplay_state.is_transitioning = true
			gameplay_state.pending_room = 0
			gameplay_state.pending_player_pos = {level_width - 60, player_pos.y}
			tween.to(
				&gameplay_state.transition_opacity,
				1.0,
				.Quadratic_Out,
				300 * time.Millisecond,
			)
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
		}

		// Position player
		transition_player := character_get_player()
		if transition_player != nil {
			transition_player.position = gameplay_state.pending_player_pos
		}
		gameplay_state.pending_room = -1

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
		character_system_update() // Handles all characters (player, enemies, NPCs)
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
		draw_entities_sorted()
		particle_system_draw()
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
	shader_fini()
	room_fini()
	character_system_fini()
	particle_system_fini()
}


draw_transition_overlay :: proc() {
	if gameplay_state.is_transitioning && gameplay_state.transition_opacity > 0.01 {
		alpha := u8(gameplay_state.transition_opacity * 255)
		renderer.draw_rect_i(0, 0, design_width, design_height, renderer.Colour{0, 0, 0, alpha})
	}
}
