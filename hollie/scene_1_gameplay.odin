package hollie

import "audio"
import "core:slice"
import "core:time"
import "tilemap"
import "tween"
import rl "vendor:raylib"


Drawable_Entity :: struct {
	position:    Vec2,
	type:        Character_Type,
	enemy_index: int, // only used for enemies
}

// Draw all characters sorted by y position
draw_entities_sorted :: proc() {
	entities := make([dynamic]Drawable_Entity, 0, len(characters))
	defer delete(entities)

	// Add all characters
	for i in 0 ..< len(characters) {
		character := &characters[i]

		append(
			&entities,
			Drawable_Entity{position = character.position, type = character.type, enemy_index = i},
		)
	}

	// Sort by y position (entities with higher y values are drawn later/on top)
	slice.sort_by(entities[:], proc(a, b: Drawable_Entity) -> bool {
		return a.position.y < b.position.y
	})

	// Draw all entities in sorted order
	for entity in entities {
		character := &characters[entity.enemy_index]
		character_draw(character)
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
	init_camera()
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
	if rl.IsKeyPressed(.P) || rl.IsGamepadButtonPressed(PLAYER_1, .MIDDLE_RIGHT) {
		if gameplay_state.is_paused {
			gameplay_state.is_paused = false
			audio.music_set_volume(game_state.music, 1)
		} else {
			gameplay_state.is_paused = true
			audio.music_set_volume(game_state.music, 0.2)
		}
	}

	if rl.IsKeyPressed(.R) {
		level_reload()
	}

	if rl.IsKeyPressed(.T) && !dialog_is_active() {
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
		update_camera()
		dialog_update()
	}
}

draw_gameplay_screen :: proc() {
	// world
	{
		rl.BeginMode2D(camera)
		defer rl.EndMode2D()

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

	rl.DrawRectangle(0, 0, DESIGN_WIDTH, DESIGN_HEIGHT, rl.Fade(rl.BLACK, 0.75))

	design_w := f32(DESIGN_WIDTH)
	design_h := f32(DESIGN_HEIGHT)
	tx := i32(design_w / 2 - 60)
	ty := i32(design_h / 2 - 30)
	rl.DrawText("PAUSED", tx, ty, 20, rl.WHITE)
}

draw_transition_overlay :: proc() {
	if gameplay_state.is_transitioning && gameplay_state.transition_opacity > 0.01 {
		w := rl.GetScreenWidth()
		h := rl.GetRenderHeight()
		alpha := u8(gameplay_state.transition_opacity * 255)
		rl.DrawRectangle(0, 0, DESIGN_WIDTH, DESIGN_HEIGHT, rl.Color{0, 0, 0, alpha})
	}
}
