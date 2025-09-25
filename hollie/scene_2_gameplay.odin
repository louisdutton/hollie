package hollie

import "audio"
import "core:slice"
import "tilemap"
import rl "vendor:raylib"

// Entity for y-sorting
Entity_Type_For_Sorting :: enum {
	PLAYER,
	ENEMY,
}

Drawable_Entity :: struct {
	position:    Vec2,
	type:        Entity_Type_For_Sorting,
	enemy_index: int, // only used for enemies
}

// Draw all characters sorted by y position
draw_entities_sorted :: proc() {
	entities := make([dynamic]Drawable_Entity, 0, len(characters))
	defer delete(entities)

	// Add all characters
	for i in 0 ..< len(characters) {
		character := &characters[i]
		entity_type := Entity_Type_For_Sorting.PLAYER
		switch character.type {
		case .PLAYER: entity_type = .PLAYER
		case .ENEMY, .NPC: entity_type = .ENEMY
		}

		append(
			&entities,
			Drawable_Entity{position = character.position, type = entity_type, enemy_index = i},
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
	is_paused:  bool,
	test_level: LevelResource,
} {
	is_paused = false,
}

init_gameplay_screen :: proc() {
	init_camera()
	dialog_init()
	character_system_init()
	shader_init()

	gameplay_state.test_level = level_new()
	level_init(&gameplay_state.test_level)
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

	if !gameplay_state.is_paused {
		level_update()
		character_system_update() // Handles all characters (player, enemies, NPCs)
		update_camera()
		dialog_update()
	}
}

draw_gameplay_screen :: proc() {
	rl.BeginMode2D(camera)

	tilemap.draw(camera)
	draw_entities_sorted()
	rl.EndMode2D()

	// ui
	dialog_draw()

	if gameplay_state.is_paused {
		w := rl.GetScreenWidth()
		h := rl.GetRenderHeight()
		rl.DrawRectangle(0, 0, w, h, rl.Fade(rl.BLACK, 0.75))
		tx := w / 2 - 60
		ty := h / 2 - 30
		rl.DrawText("PAUSED", tx, ty, 20, rl.WHITE)
	}
}

unload_gameplay_screen :: proc() {
	shader_fini()
	level_fini()
	character_system_fini()
}

finish_gameplay_screen :: proc() -> int {
	return 0
}
