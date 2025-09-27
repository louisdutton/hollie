package hollie

import "audio"
import "core:slice"
import "core:time"
import "input"
import "renderer"
import "tilemap"
import "tween"

Drawable_Entity :: struct {
	position:    Vec2,
	type:        Character_Type,
	enemy_index: int, // only used for enemies
}

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
	is_paused:          bool,
	grass_level:        LevelResource,
	sand_level:         LevelResource,
	current_level:      int, // 0 = grass, 1 = sand
	is_transitioning:   bool,
	transition_opacity: f32,
	pending_level:      int,
	pending_player_pos: Vec2,
} {
	is_paused          = false,
	current_level      = 0,
	is_transitioning   = false,
	transition_opacity = 0.0,
	pending_level      = -1,
}

init_gameplay_screen :: proc() {
	camera_init()
	dialog_init()
	character_system_init()
	particle_system_init()
	shader_init()

	gameplay_state.grass_level = level_new()
	gameplay_state.sand_level = level_new_sand()
	level_init(&gameplay_state.grass_level)
}

// FIXME: putting this in stack memory causes uaf in dialog
test_messages := []Dialog_Message {
	{text = "Hi there Hollie! It's me, Basil!", speaker = "Basil"},
	{text = "Greetings Basil.", speaker = "Hollie"},
	{text = "Good luck on your journey.", speaker = "Basil"},
	{text = "Thanks!", speaker = "Hollie"},
}

update_gameplay_screen :: proc() {
	if input.is_key_pressed(.P) || input.is_gamepad_button_pressed(input.PLAYER_1, .MIDDLE_RIGHT) {
		if gameplay_state.is_paused {
			gameplay_state.is_paused = false
			audio.music_set_volume(game_state.music, 1)
		} else {
			gameplay_state.is_paused = true
			audio.music_set_volume(game_state.music, 0.2)
		}
	}

	if input.is_key_pressed(.R) {
		level_reload()
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
		if gameplay_state.current_level == 0 && player_pos.x >= 785 {
			gameplay_state.is_transitioning = true
			gameplay_state.pending_level = 1
			gameplay_state.pending_player_pos = {50, player_pos.y}
			tween.to(
				&gameplay_state.transition_opacity,
				1.0,
				.Quadratic_Out,
				300 * time.Millisecond,
			)
		} else if gameplay_state.current_level == 1 && player_pos.x <= 15 {
			// Transition to grass level (left side) - trigger near left edge
			gameplay_state.is_transitioning = true
			gameplay_state.pending_level = 0
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
	   gameplay_state.pending_level >= 0 {
		gameplay_state.current_level = gameplay_state.pending_level

		// Load appropriate level
		switch gameplay_state.current_level {
		case 0:
			level_init(&gameplay_state.grass_level)
		case 1:
			level_init(&gameplay_state.sand_level)
		}

		// Position player
		transition_player := character_get_player()
		if transition_player != nil {
			transition_player.position = gameplay_state.pending_player_pos
		}
		gameplay_state.pending_level = -1

		// Start fade out
		tween.to(&gameplay_state.transition_opacity, 0.0, .Quadratic_In, 300 * time.Millisecond)
	}

	// End transition when fade out completes
	if gameplay_state.is_transitioning &&
	   gameplay_state.transition_opacity <= 0.01 &&
	   gameplay_state.pending_level < 0 {
		gameplay_state.is_transitioning = false
		gameplay_state.transition_opacity = 0.0
	}

	if !gameplay_state.is_paused {
		level_update()
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

		level_draw_name()
		dialog_draw()
		draw_transition_overlay()
		draw_pause_overlay()
	}
}

unload_gameplay_screen :: proc() {
	shader_fini()
	level_fini()
	character_system_fini()
	particle_system_fini()
}

finish_gameplay_screen :: proc() -> int {
	return 0
}

draw_pause_overlay :: proc() {
	if !gameplay_state.is_paused do return

	renderer.draw_rect_i(0, 0, design_width, design_height, renderer.fade(renderer.BLACK, 0.75))

	design_w := f32(design_width)
	design_h := f32(design_height)
	tx := i32(design_w / 2 - 60)
	ty := i32(design_h / 2 - 30)
	renderer.draw_text("PAUSED", int(tx), int(ty), 20, renderer.WHITE)
}

draw_transition_overlay :: proc() {
	if gameplay_state.is_transitioning && gameplay_state.transition_opacity > 0.01 {
		alpha := u8(gameplay_state.transition_opacity * 255)
		renderer.draw_rect_i(0, 0, design_width, design_height, renderer.Colour{0, 0, 0, alpha})
	}
}
