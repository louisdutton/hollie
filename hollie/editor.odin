package hollie

import "asset"
import "content"
import "core:fmt"
import "core:strings"
import "input"
import "renderer"
import "tilemap"
import "window"

Editor_Mode :: enum {
	DISABLED,
	EDITING,
}

Editor_Layer :: enum {
	BASE,
	DECORATION,
	ENTITY,
}

Editor_State :: struct {
	mode:               Editor_Mode,
	selected_tile:      tilemap.TileType,
	selected_entity:    tilemap.EntityType,
	selected_layer:     Editor_Layer,
	is_painting:        bool,
	is_erasing:         bool,
	show_grid:          bool,
	show_layer_overlay: bool,
	show_hud:           bool,
	cursor_x:           int,
	cursor_y:           int,
	cursor_visible:     bool,
	cursor_move_timer:  f32,
	pre_edit_camera:    renderer.Camera2D,
	pre_edit_players:   [dynamic]Vec2,
	hovered_entity:     ^tilemap.EntityData,
	is_editing_entity:  bool,
	edit_input_timer:   f32,
	save_message:       string,
	save_succeeded:     bool,
	save_message_timer: f32,
}

@(private)
editor_state := Editor_State {
	mode               = .DISABLED,
	selected_tile      = .GRASS_1,
	selected_entity    = .ENEMY,
	selected_layer     = .BASE,
	show_grid          = true,
	show_layer_overlay = false,
	show_hud           = true,
	cursor_x           = 0,
	cursor_y           = 0,
	cursor_visible     = true,
	cursor_move_timer  = 0.0,
}

editor_init :: proc() {

}

editor_is_active :: proc() -> bool {
	return editor_state.mode == .EDITING
}

editor_toggle :: proc() {
	switch editor_state.mode {
	case .DISABLED: editor_enter_edit_mode()
	case .EDITING: editor_exit_edit_mode()
	}
}

editor_enter_edit_mode :: proc() {
	editor_state.mode = .EDITING

	editor_state.pre_edit_camera = camera

	players := entity_get_players()
	defer delete(players)

	clear(&editor_state.pre_edit_players)
	for player in players {
		append(&editor_state.pre_edit_players, player.position)
	}
}

editor_exit_edit_mode :: proc() {
	editor_state.mode = .DISABLED

	camera = editor_state.pre_edit_camera

	players := entity_get_players()
	defer delete(players)

	for i in 0 ..< min(len(players), len(editor_state.pre_edit_players)) {
		players[i].position = editor_state.pre_edit_players[i]
	}

	editor_reload_current_level()
}

editor_reload_current_level :: proc() {
	current_room := gameplay_get_current_room()
	gameplay_load_room(current_room)
}

editor_update :: proc() {
	if editor_state.mode != .EDITING do return
	if editor_state.save_message_timer > 0 {
		editor_state.save_message_timer -= window.get_frame_time()
		if editor_state.save_message_timer <= 0 {
			delete(editor_state.save_message)
			editor_state.save_message = ""
		}
	}

	editor_handle_camera_input()
	editor_handle_tile_selection()
	editor_handle_painting_input()
	editor_handle_ui_input()
	editor_handle_cursor_hover()
	editor_handle_entity_editing()
}

editor_handle_cursor_hover :: proc() {
	editor_state.hovered_entity = nil

	cursor_x, cursor_y := editor_state.cursor_x, editor_state.cursor_y
	entities := tilemap.get_entities()
	tile_size := tilemap.get_tile_size()

	cursor_world_x := cursor_x * tile_size
	cursor_world_y := cursor_y * tile_size

	for &entity in entities {
		if entity.x == cursor_world_x && entity.y == cursor_world_y {
			editor_state.hovered_entity = &entity
			break
		}
	}
}

editor_handle_entity_editing :: proc() {
	dt := window.get_frame_time()
	editor_state.edit_input_timer -= dt

	// Enter/exit edit mode
	if input.action_pressed(.Editor_Edit_Entity) &&
	   (editor_state.hovered_entity != nil || editor_state.is_editing_entity) {
		editor_state.is_editing_entity = !editor_state.is_editing_entity
		editor_state.edit_input_timer = 0.2
	}

	if editor_state.hovered_entity == nil do return
	if !editor_state.is_editing_entity do return
	if editor_state.edit_input_timer > 0 do return

	entity := editor_state.hovered_entity

	// Handle editing based on entity type
	#partial switch entity.entity_type {
	case .PRESSURE_PLATE:
		if input.action_pressed(.Editor_Value_Next) {
			entity.trigger_id += 1
			editor_state.edit_input_timer = 0.15
		}
		if input.action_pressed(.Editor_Value_Previous) && entity.trigger_id > 0 {
			entity.trigger_id -= 1
			editor_state.edit_input_timer = 0.15
		}
		if input.action_pressed(.Editor_Value_Toggle) {
			entity.requires_both = !entity.requires_both
			editor_state.edit_input_timer = 0.15
		}

	case .GATE:
		if input.action_pressed(.Editor_Value_Next) {
			entity.gate_id += 1
			editor_state.edit_input_timer = 0.15
		}
		if input.action_pressed(.Editor_Value_Previous) && entity.gate_id > 0 {
			entity.gate_id -= 1
			editor_state.edit_input_timer = 0.15
		}
		if input.action_pressed(.Editor_Value_Toggle) {
			entity.inverted = !entity.inverted
			editor_state.edit_input_timer = 0.15
		}

	case .DOOR:
		if input.action_pressed(.Editor_Value_Next) {
			editor_cycle_room_name(&entity.target_room, 1)
			editor_state.edit_input_timer = 0.15
		}
		if input.action_pressed(.Editor_Value_Previous) {
			editor_cycle_room_name(&entity.target_room, -1)
			editor_state.edit_input_timer = 0.15
		}
		if input.action_pressed(.Editor_Value_Toggle) {
			editor_cycle_door_name(&entity.target_door)
			editor_state.edit_input_timer = 0.15
		}

	case .ENEMY:
		if input.action_pressed(.Editor_Value_Next) {
			editor_cycle_character_kind(entity, 1)
			editor_state.edit_input_timer = 0.15
		}
		if input.action_pressed(.Editor_Value_Previous) {
			editor_cycle_character_kind(entity, -1)
			editor_state.edit_input_timer = 0.15
		}
	}
}

editor_entity_has_data :: proc(entity: ^tilemap.EntityData) -> bool {
	#partial switch entity.entity_type {
	case .PRESSURE_PLATE: return entity.trigger_id != 0
	case .GATE: return entity.gate_id != 0 || len(entity.required_triggers) > 0
	case .DOOR: return entity.target_room != "" || entity.target_door != ""
	case .ENEMY: return true
	}
	return false
}

editor_handle_camera_input :: proc() {
	dt := window.get_frame_time()
	move_speed: f32 = 300.0

	movement := Vec2{0, 0}

	if input.is_key_down(.W) do movement.y -= 1
	if input.is_key_down(.S) do movement.y += 1
	if input.is_key_down(.A) do movement.x -= 1
	if input.is_key_down(.D) do movement.x += 1

	gamepad_x := input.get_gamepad_axis_movement(.PLAYER_1, .RIGHT_X)
	gamepad_y := input.get_gamepad_axis_movement(.PLAYER_1, .RIGHT_Y)
	if abs(gamepad_x) > input.JS_DEADZONE do movement.x += gamepad_x
	if abs(gamepad_y) > input.JS_DEADZONE do movement.y += gamepad_y

	if movement.x != 0 || movement.y != 0 {
		movement = input.vector2_normalize(movement)
		camera.target.x += movement.x * move_speed * dt / camera.zoom
		camera.target.y += movement.y * move_speed * dt / camera.zoom
	}

	zoom_change: f32 = 0

	if input.action_pressed(.Editor_Zoom_In) do zoom_change = 0.125
	if input.action_pressed(.Editor_Zoom_Out) do zoom_change = -0.125

	if zoom_change != 0 {
		camera.zoom += zoom_change
		camera.zoom = max(0.25, min(camera.zoom, 4.0))
	}
}

BASE_TILES := []tilemap.TileType {
	.GRASS_1,
	.GRASS_2,
	.GRASS_3,
	.GRASS_4,
	.GRASS_5,
	.GRASS_6,
	.GRASS_7,
	.GRASS_8,
	.SAND_1,
	.SAND_2,
	.SAND_3,
}

DECORATION_TILES := []tilemap.TileType {
	.EMPTY,
	.GRASS_DEC_1,
	.GRASS_DEC_2,
	.GRASS_DEC_3,
	.GRASS_DEC_4,
	.GRASS_DEC_5,
}

editor_get_tiles_for_layer :: proc(layer: Editor_Layer) -> []tilemap.TileType {
	switch layer {
	case .BASE: return BASE_TILES
	case .DECORATION: return DECORATION_TILES
	case .ENTITY: return {}
	}
	return {}
}

editor_handle_tile_selection :: proc() {
	if editor_state.selected_layer == .ENTITY {
		entities := []tilemap.EntityType{.ENEMY, .NPC, .HOLDABLE, .PRESSURE_PLATE, .GATE, .DOOR}

		current_index := -1
		for entity, i in entities {
			if entity == editor_state.selected_entity {
				current_index = i
				break
			}
		}

		if input.action_pressed(.Editor_Select_Next) {
			current_index = (current_index + 1) % len(entities)
			editor_state.selected_entity = entities[current_index]
		}
		if input.action_pressed(.Editor_Select_Previous) {
			current_index = (current_index - 1 + len(entities)) % len(entities)
			editor_state.selected_entity = entities[current_index]
		}
	} else {
		tiles := editor_get_tiles_for_layer(editor_state.selected_layer)
		if len(tiles) == 0 do return

		current_index := -1
		for tile, i in tiles {
			if tile == editor_state.selected_tile {
				current_index = i
				break
			}
		}

		if current_index == -1 {
			editor_state.selected_tile = tiles[0]
			current_index = 0
		}

		if input.action_pressed(.Editor_Select_Next) {
			current_index = (current_index + 1) % len(tiles)
			editor_state.selected_tile = tiles[current_index]
		}
		if input.action_pressed(.Editor_Select_Previous) {
			current_index = (current_index - 1 + len(tiles)) % len(tiles)
			editor_state.selected_tile = tiles[current_index]
		}
	}
}

editor_handle_painting_input :: proc() {
	dt := window.get_frame_time()
	move_threshold: f32 = 0.15

	editor_state.cursor_move_timer -= dt

	gamepad_move_x := input.get_gamepad_axis_movement(.PLAYER_1, .LEFT_X)
	gamepad_move_y := input.get_gamepad_axis_movement(.PLAYER_1, .LEFT_Y)
	dpad_x :=
		int(input.is_gamepad_button_pressed(.PLAYER_1, .LEFT_FACE_RIGHT)) -
		int(input.is_gamepad_button_pressed(.PLAYER_1, .LEFT_FACE_LEFT))
	dpad_y :=
		int(input.is_gamepad_button_pressed(.PLAYER_1, .LEFT_FACE_DOWN)) -
		int(input.is_gamepad_button_pressed(.PLAYER_1, .LEFT_FACE_UP))

	if dpad_x != 0 {
		editor_state.cursor_x += dpad_x
	}
	if dpad_y != 0 {
		editor_state.cursor_y += dpad_y
	}

	if abs(gamepad_move_x) > input.JS_DEADZONE && editor_state.cursor_move_timer <= 0 {
		if gamepad_move_x > 0 {
			editor_state.cursor_x += 1
		} else {
			editor_state.cursor_x -= 1
		}
		editor_state.cursor_move_timer = move_threshold
	}
	if abs(gamepad_move_y) > input.JS_DEADZONE && editor_state.cursor_move_timer <= 0 {
		if gamepad_move_y > 0 {
			editor_state.cursor_y += 1
		} else {
			editor_state.cursor_y -= 1
		}
		editor_state.cursor_move_timer = move_threshold
	}


	editor_state.cursor_x = max(0, min(editor_state.cursor_x, tilemap.get_tilemap_width() - 1))
	editor_state.cursor_y = max(0, min(editor_state.cursor_y, tilemap.get_tilemap_height() - 1))

	paint_x, paint_y := editor_state.cursor_x, editor_state.cursor_y
	if editor_state.is_editing_entity {
		editor_state.is_painting = false
		editor_state.is_erasing = false
		return
	}

	if input.action_down(.Editor_Paint) {
		if !editor_state.is_painting {
			editor_state.is_painting = true
		}
		editor_paint_tile(paint_x, paint_y)
	} else {
		editor_state.is_painting = false
	}

	if input.action_down(.Editor_Erase) {
		if !editor_state.is_erasing {
			editor_state.is_erasing = true
		}
		editor_erase_tile(paint_x, paint_y)
	} else {
		editor_state.is_erasing = false
	}
}

editor_handle_ui_input :: proc() {
	if !editor_state.is_editing_entity && input.action_pressed(.Editor_Change_Layer) {
		switch editor_state.selected_layer {
		case .BASE: editor_state.selected_layer = .DECORATION
		case .DECORATION: editor_state.selected_layer = .ENTITY
		case .ENTITY: editor_state.selected_layer = .BASE
		}
	}

	if input.action_pressed(.Editor_Toggle_Grid) {
		editor_state.show_grid = !editor_state.show_grid
	}

	if input.is_key_pressed(.L) {
		editor_state.show_layer_overlay = !editor_state.show_layer_overlay
	}

	if input.is_key_pressed(.H) {
		editor_state.show_hud = !editor_state.show_hud
	}

	if input.action_pressed(.Editor_Save) {
		editor_save_current_tilemap()
	}

}

editor_save_current_tilemap :: proc() {
	full_path := gameplay_get_current_room_path()
	resource_root := asset.path("")
	defer delete(resource_root)
	save_error := tilemap.save_tilemap_file_atomic(
		full_path,
		tilemap.get_current_tilemap(),
		resource_root,
	)
	defer tilemap.destroy_room_file_io_error(&save_error)
	if save_error.kind == .none {
		fmt.println("Tilemap saved to:", full_path)
		editor_set_save_message("Room saved", true)
	} else {
		fmt.println("Failed to save tilemap:", save_error.message)
		message := fmt.tprintf("Save failed: %s", save_error.message)
		editor_set_save_message(message, false)
	}
}

editor_set_save_message :: proc(message: string, succeeded: bool) {
	delete(editor_state.save_message)
	editor_state.save_message = strings.clone(message)
	editor_state.save_succeeded = succeeded
	editor_state.save_message_timer = 4
}

editor_paint_tile :: proc(tile_x, tile_y: int) {
	switch editor_state.selected_layer {
	case .BASE: if tile := tilemap.get_base_tile(tile_x, tile_y); tile != nil {
				tile^ = editor_state.selected_tile
			}
	case .DECORATION: if tile := tilemap.get_deco_tile(tile_x, tile_y); tile != nil {
				tile^ = editor_state.selected_tile
			}
	case .ENTITY:
		// Only place one entity per tile, so check if there's already one
		entities := tilemap.get_entities()
		tile_size := tilemap.get_tile_size()
		world_x := tile_x * tile_size
		world_y := tile_y * tile_size

		for entity in entities {
			if entity.x == world_x && entity.y == world_y do return
		}

		tilemap.add_entity(world_x, world_y, editor_state.selected_entity)
	}
}

editor_erase_tile :: proc(tile_x, tile_y: int) {
	switch editor_state.selected_layer {
	case .BASE: if tile := tilemap.get_base_tile(tile_x, tile_y); tile != nil {
				tile^ = .GRASS_1
			}
	case .DECORATION: if tile := tilemap.get_deco_tile(tile_x, tile_y); tile != nil {
				tile^ = .EMPTY
			}
	case .ENTITY:
		tile_size := tilemap.get_tile_size()
		world_x := tile_x * tile_size
		world_y := tile_y * tile_size
		tilemap.remove_entity_at(world_x, world_y)
	}
}


editor_cycle_room_name :: proc(room_name: ^string, direction: int) {
	registry := gameplay_get_room_registry()
	if len(registry.entries) == 0 do return

	current_index := -1
	for room, i in registry.entries {
		if room.id == room_name^ {
			current_index = i
			break
		}
	}

	if current_index == -1 do current_index = 0

	new_index := (current_index + direction + len(registry.entries)) % len(registry.entries)
	editor_replace_string(room_name, registry.entries[new_index].id)
}

editor_cycle_door_name :: proc(door_name: ^string) {
	door_names := []string {
		"",
		"main",
		"from_desert",
		"from_small_room",
		"to_desert",
		"to_small_room",
	}

	current_index := -1
	for name, i in door_names {
		if name == door_name^ {
			current_index = i
			break
		}
	}

	if current_index == -1 do current_index = 0

	new_index := (current_index + 1) % len(door_names)
	editor_replace_string(door_name, door_names[new_index])
}

editor_cycle_character_kind :: proc(entity: ^tilemap.EntityData, direction: int) {
	if entity.entity_type != .ENEMY do return

	kind_count := len(content.Character_Kind)
	current_index := int(entity.character_kind)
	if current_index < 0 || current_index >= kind_count do current_index = 0

	new_index := (current_index + direction + kind_count) % kind_count
	entity.character_kind = content.Character_Kind(new_index)
}

editor_replace_string :: proc(destination: ^string, value: string) {
	if destination^ == value do return
	delete(destination^)
	destination^ = strings.clone(value)
}

editor_fini :: proc() {
	delete(editor_state.pre_edit_players)
	delete(editor_state.save_message)
}
