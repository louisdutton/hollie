package hollie

import "asset"
import "core:fmt"
import "core:strings"
import "gui"
import "input"
import "renderer"
import "tilemap"
import rl "vendor:raylib"
import "window"

when ODIN_DEBUG {
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
		brush_size:         int,
		show_grid:          bool,
		show_layer_overlay: bool,
		show_hud:           bool,
		cursor_x:           int,
		cursor_y:           int,
		cursor_visible:     bool,
		cursor_move_timer:  f32,
		pre_edit_camera:    rl.Camera2D,
		pre_edit_players:   [dynamic]Vec2,
	}

	@(private)
	editor_state := Editor_State {
		mode               = .DISABLED,
		selected_tile      = .GRASS_1,
		selected_entity    = .PLAYER,
		selected_layer     = .BASE,
		brush_size         = 1,
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

	ui_button :: proc(rect: rl.Rectangle, text: string) -> bool {
		return gui.button(rect, text)
	}

	ui_panel :: proc(rect: rl.Rectangle, title: string) {
		gui.panel(rect, title)
	}

	ui_label :: proc(rect: rl.Rectangle, text: string) {
		gui.label(rect, text)
	}

	ui_slider :: proc(
		rect: rl.Rectangle,
		label: string,
		value: ^f32,
		min_val, max_val: f32,
	) -> bool {
		return gui.slider(rect, label, value, min_val, max_val)
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

		editor_handle_camera_input()
		editor_handle_tile_selection()
		editor_handle_painting_input()
		editor_handle_ui_input()
	}

	editor_draw :: proc() {
		if editor_state.mode != .EDITING do return

		editor_draw_grid()
		editor_draw_layer_overlay()
		editor_draw_entities()
		editor_draw_cursor()
	}

	editor_draw_ui :: proc() {
		if editor_state.mode != .EDITING do return

		ui_begin()
		defer ui_end()

		if editor_state.show_hud {
			editor_draw_minimal_hud()
		}
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

		if input.is_gamepad_button_pressed(.PLAYER_1, .RIGHT_TRIGGER_2) do zoom_change = 0.125
		if input.is_gamepad_button_pressed(.PLAYER_1, .LEFT_TRIGGER_2) do zoom_change = -0.125

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
			entities := []tilemap.EntityType {
				.PLAYER,
				.ENEMY,
				.NPC,
				.HOLDABLE,
				.PRESSURE_PLATE,
				.GATE,
				.DOOR,
			}

			current_index := -1
			for entity, i in entities {
				if entity == editor_state.selected_entity {
					current_index = i
					break
				}
			}

			if input.is_gamepad_button_pressed(.PLAYER_1, .RIGHT_TRIGGER_1) ||
			   input.is_key_pressed(.RIGHT) {
				current_index = (current_index + 1) % len(entities)
				editor_state.selected_entity = entities[current_index]
			}
			if input.is_gamepad_button_pressed(.PLAYER_1, .LEFT_TRIGGER_1) ||
			   input.is_key_pressed(.LEFT) {
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

			if input.is_gamepad_button_pressed(.PLAYER_1, .RIGHT_TRIGGER_1) ||
			   input.is_key_pressed(.RIGHT) {
				current_index = (current_index + 1) % len(tiles)
				editor_state.selected_tile = tiles[current_index]
			}
			if input.is_gamepad_button_pressed(.PLAYER_1, .LEFT_TRIGGER_1) ||
			   input.is_key_pressed(.LEFT) {
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
		editor_state.cursor_y = max(
			0,
			min(editor_state.cursor_y, tilemap.get_tilemap_height() - 1),
		)

		paint_x, paint_y := editor_state.cursor_x, editor_state.cursor_y

		if input.is_gamepad_button_down(.PLAYER_1, .RIGHT_FACE_RIGHT) {
			if !editor_state.is_painting {
				editor_state.is_painting = true
			}
			editor_paint_tile(paint_x, paint_y)
		} else {
			editor_state.is_painting = false
		}

		if input.is_gamepad_button_down(.PLAYER_1, .RIGHT_FACE_DOWN) {
			if !editor_state.is_erasing {
				editor_state.is_erasing = true
			}
			editor_erase_tile(paint_x, paint_y)
		} else {
			editor_state.is_erasing = false
		}
	}

	editor_handle_ui_input :: proc() {
		if input.is_key_pressed(.TAB) ||
		   input.is_gamepad_button_pressed(.PLAYER_1, .LEFT_FACE_UP) {
			switch editor_state.selected_layer {
			case .BASE: editor_state.selected_layer = .DECORATION
			case .DECORATION: editor_state.selected_layer = .ENTITY
			case .ENTITY: editor_state.selected_layer = .BASE
			}
		}

		if input.is_key_pressed(.G) ||
		   input.is_gamepad_button_pressed(.PLAYER_1, .LEFT_FACE_LEFT) {
			editor_state.show_grid = !editor_state.show_grid
		}

		if input.is_key_pressed(.L) ||
		   input.is_gamepad_button_pressed(.PLAYER_1, .LEFT_FACE_RIGHT) {
			editor_state.show_layer_overlay = !editor_state.show_layer_overlay
		}

		if input.is_key_pressed(.H) ||
		   input.is_gamepad_button_pressed(.PLAYER_1, .LEFT_FACE_DOWN) {
			editor_state.show_hud = !editor_state.show_hud
		}

		if (input.is_key_down(.LEFT_CONTROL) || input.is_key_down(.RIGHT_CONTROL)) &&
			   input.is_key_pressed(.S) ||
		   input.is_gamepad_button_pressed(.PLAYER_1, .MIDDLE_LEFT) {
			editor_save_current_tilemap()
		}

		if input.is_key_pressed(.EQUAL) {
			editor_state.brush_size = min(editor_state.brush_size + 1, 5)
		}
		if input.is_key_pressed(.MINUS) {
			editor_state.brush_size = max(editor_state.brush_size - 1, 1)
		}
	}

	editor_save_current_tilemap :: proc() {
		room_path := gameplay_get_current_room_path()
		full_path := asset.path(room_path)
		if tilemap.to_file(full_path) {
			fmt.println("Tilemap saved to:", full_path)
		} else {
			fmt.println("Failed to save tilemap to:", full_path)
		}
	}

	editor_paint_tile :: proc(tile_x, tile_y: int) {
		for dy in -(editor_state.brush_size / 2) ..= (editor_state.brush_size / 2) {
			for dx in -(editor_state.brush_size / 2) ..= (editor_state.brush_size / 2) {
				x := tile_x + dx
				y := tile_y + dy

				switch editor_state.selected_layer {
				case .BASE: if tile := tilemap.get_base_tile(x, y); tile != nil {
							tile^ = editor_state.selected_tile
						}
				case .DECORATION: if tile := tilemap.get_deco_tile(x, y); tile != nil {
							tile^ = editor_state.selected_tile
						}
				case .ENTITY:
					// Only place one entity per tile, so check if there's already one
					entities := tilemap.get_entities()
					tile_size := tilemap.get_tile_size()
					world_x := x * tile_size
					world_y := y * tile_size

					entity_exists := false
					for entity in entities {
						if entity.x == world_x && entity.y == world_y {
							entity_exists = true
							break
						}
					}

					if !entity_exists {
						tilemap.add_entity(world_x, world_y, editor_state.selected_entity)
					}
				}
			}
		}
	}

	editor_erase_tile :: proc(tile_x, tile_y: int) {
		for dy in -(editor_state.brush_size / 2) ..= (editor_state.brush_size / 2) {
			for dx in -(editor_state.brush_size / 2) ..= (editor_state.brush_size / 2) {
				x := tile_x + dx
				y := tile_y + dy

				switch editor_state.selected_layer {
				case .BASE: if tile := tilemap.get_base_tile(x, y); tile != nil {
							tile^ = .GRASS_1
						}
				case .DECORATION: if tile := tilemap.get_deco_tile(x, y); tile != nil {
							tile^ = .EMPTY
						}
				case .ENTITY:
					// Remove entity at this position
					tile_size := tilemap.get_tile_size()
					world_x := x * tile_size
					world_y := y * tile_size
					tilemap.remove_entity_at(world_x, world_y)
				}
			}
		}
	}

	editor_draw_grid :: proc() {
		if !editor_state.show_grid do return

		screen_width := f32(window.get_screen_width())
		screen_height := f32(window.get_screen_height())

		world_min := rl.GetScreenToWorld2D({0, 0}, camera)
		world_max := rl.GetScreenToWorld2D({screen_width, screen_height}, camera)

		tile_size := f32(tilemap.get_tile_size())
		start_x := max(0, int(world_min.x / tile_size))
		end_x := min(tilemap.get_tilemap_width(), int(world_max.x / tile_size) + 1)
		start_y := max(0, int(world_min.y / tile_size))
		end_y := min(tilemap.get_tilemap_height(), int(world_max.y / tile_size) + 1)

		grid_color := renderer.Colour{255, 255, 255, 64}

		for x in start_x ..= end_x {
			world_x := f32(x * tilemap.get_tile_size())
			start_world_y := f32(start_y * tilemap.get_tile_size())
			end_world_y := f32(end_y * tilemap.get_tile_size())
			rl.DrawLine(
				i32(world_x),
				i32(start_world_y),
				i32(world_x),
				i32(end_world_y),
				grid_color,
			)
		}

		for y in start_y ..= end_y {
			world_y := f32(y * tilemap.get_tile_size())
			start_world_x := f32(start_x * tilemap.get_tile_size())
			end_world_x := f32(end_x * tilemap.get_tile_size())
			rl.DrawLine(
				i32(start_world_x),
				i32(world_y),
				i32(end_world_x),
				i32(world_y),
				grid_color,
			)
		}
	}

	editor_draw_layer_overlay :: proc() {
		if !editor_state.show_layer_overlay do return

		overlay_color := renderer.Colour{}
		switch editor_state.selected_layer {
		case .BASE: return // No overlay for base layer
		case .DECORATION: overlay_color = {0, 255, 0, 32}
		case .ENTITY: overlay_color = {255, 0, 255, 32}
		}

		screen_min := rl.GetWorldToScreen2D({0, 0}, camera)
		screen_max := rl.GetWorldToScreen2D(
			{
				f32(tilemap.get_tilemap_width() * tilemap.get_tile_size()),
				f32(tilemap.get_tilemap_height() * tilemap.get_tile_size()),
			},
			camera,
		)

		rl.DrawRectangle(
			i32(screen_min.x),
			i32(screen_min.y),
			i32(screen_max.x - screen_min.x),
			i32(screen_max.y - screen_min.y),
			overlay_color,
		)
	}

	editor_draw_entities :: proc() {
		entities := tilemap.get_entities()
		tile_size := f32(tilemap.get_tile_size())

		for entity in entities {
			x := f32(entity.x)
			y := f32(entity.y)

			// Choose color based on entity type
			color := renderer.Colour{}
			icon_text := ""
			switch entity.entity_type {
			case .PLAYER:
				color = {0, 255, 0, 180}
				icon_text = "P"
			case .ENEMY:
				color = {255, 0, 0, 180}
				icon_text = "E"
			case .NPC:
				color = {0, 0, 255, 180}
				icon_text = "N"
			case .HOLDABLE:
				color = {255, 165, 0, 180}
				icon_text = "H"
			case .PRESSURE_PLATE:
				color = {128, 128, 128, 180}
				icon_text = "PP"
			case .GATE:
				color = {139, 69, 19, 180}
				icon_text = "G"
			case .DOOR:
				color = {255, 255, 255, 180}
				icon_text = "D"
			}

			// Draw entity rectangle
			renderer.draw_rect(x, y, tile_size, tile_size, color)
			renderer.draw_rect_outline(x, y, tile_size, tile_size, color = renderer.BLACK)

			// Draw entity icon/text
			text_x := x + tile_size / 2 - 4
			text_y := y + tile_size / 2 - 6
			renderer.draw_text(icon_text, int(text_x), int(text_y), 12, renderer.BLACK)
		}
	}

	editor_draw_cursor :: proc() {
		if !editor_state.cursor_visible do return

		cursor_x, cursor_y := editor_state.cursor_x, editor_state.cursor_y
		brush_half := editor_state.brush_size / 2
		tile_size := tilemap.get_tile_size()

		for dy in -brush_half ..= brush_half {
			for dx in -brush_half ..= brush_half {
				x := cursor_x + dx
				y := cursor_y + dy

				if x >= 0 &&
				   x < tilemap.get_tilemap_width() &&
				   y >= 0 &&
				   y < tilemap.get_tilemap_height() {
					world_x := f32(x * tile_size)
					world_y := f32(y * tile_size)

					renderer.draw_rect_outline(
						world_x,
						world_y,
						f32(tile_size),
						f32(tile_size),
						2,
						renderer.WHITE,
					)
				}
			}
		}
	}

	editor_draw_tile_preview :: proc(tile_type: tilemap.TileType, x, y, size: f32, alpha: u8) {
		if tile_type == .EMPTY do return

		source_rect := tilemap.get_tile_source_rect(tile_type)
		dest_rect := renderer.Rect{x, y, size, size}
		tileset := tilemap.get_tileset()

		color := renderer.Colour{255, 255, 255, alpha}
		renderer.draw_texture_pro(tileset, source_rect, dest_rect, {0, 0}, 0, color)
	}

	editor_draw_entity_preview :: proc(
		entity_type: tilemap.EntityType,
		x, y, size: f32,
		alpha: u8,
	) {
		color := renderer.Colour{}
		icon_text := ""
		switch entity_type {
		case .PLAYER:
			color = {0, 255, 0, alpha}
			icon_text = "P"
		case .ENEMY:
			color = {255, 0, 0, alpha}
			icon_text = "E"
		case .NPC:
			color = {0, 0, 255, alpha}
			icon_text = "N"
		case .HOLDABLE:
			color = {255, 165, 0, alpha}
			icon_text = "H"
		case .PRESSURE_PLATE:
			color = {128, 128, 128, alpha}
			icon_text = "PP"
		case .GATE:
			color = {139, 69, 19, alpha}
			icon_text = "G"
		case .DOOR:
			color = {255, 255, 255, alpha}
			icon_text = "D"
		}

		renderer.draw_rect(x, y, size, size, color)
		renderer.draw_rect_outline(x, y, size, size, color = renderer.BLACK)

		text_x := x + size / 2 - 4
		text_y := y + size / 2 - 6
		renderer.draw_text(icon_text, int(text_x), int(text_y), 12, renderer.BLACK)
	}

	editor_draw_tile_carousel :: proc() {
		carousel_y: f32 = 80
		carousel_x: f32 = 10
		tile_preview_size: f32 = 32
		spacing: f32 = 40
		bg_colour := renderer.fade(renderer.BLACK, 0.5)

		if editor_state.selected_layer == .ENTITY {
			entities := []tilemap.EntityType {
				.PLAYER,
				.ENEMY,
				.NPC,
				.HOLDABLE,
				.PRESSURE_PLATE,
				.GATE,
				.DOOR,
			}

			current_index := -1
			for entity, i in entities {
				if entity == editor_state.selected_entity {
					current_index = i
					break
				}
			}

			if current_index == -1 do return

			carousel_width: f32 = 5 * spacing
			renderer.draw_rect(
				carousel_x - 5,
				carousel_y - 5,
				carousel_width + 10,
				tile_preview_size + 10,
				bg_colour,
			)

			for i in 0 ..< 5 {
				entity_index := current_index - 2 + i
				if entity_index < 0 || entity_index >= len(entities) do continue

				entity := entities[entity_index]
				pos_x := carousel_x + f32(i) * spacing

				alpha := u8(max(255 - (abs(i - 2) * 128), 0))
				renderer.draw_rect_outline(
					pos_x - 2,
					carousel_y - 2,
					tile_preview_size + 4,
					tile_preview_size + 4,
					3,
					renderer.WHITE,
				)

				editor_draw_entity_preview(entity, pos_x, carousel_y, tile_preview_size, alpha)
			}
			return
		}

		tiles := editor_get_tiles_for_layer(editor_state.selected_layer)
		if len(tiles) == 0 do return

		current_index := -1
		for tile, i in tiles {
			if tile == editor_state.selected_tile {
				current_index = i
				break
			}
		}

		if current_index == -1 do return

		carousel_width: f32 = 5 * spacing
		renderer.draw_rect(
			carousel_x - 5,
			carousel_y - 5,
			carousel_width + 10,
			tile_preview_size + 10,
			bg_colour,
		)

		for i in 0 ..< 5 {
			tile_index := current_index - 2 + i
			if tile_index < 0 || tile_index >= len(tiles) do continue

			tile := tiles[tile_index]
			pos_x := carousel_x + f32(i) * spacing

			alpha := u8(max(255 - (abs(i - 2) * 64), 0))
			if i == 2 {
				renderer.draw_rect_outline(
					pos_x - 2,
					carousel_y - 2,
					tile_preview_size + 4,
					tile_preview_size + 4,
					3,
				)
			}

			editor_draw_tile_preview(tile, pos_x, carousel_y, tile_preview_size, alpha)
		}
	}

	editor_draw_minimal_hud :: proc() {
		design_height := f32(window.get_design_height())

		layer_text := ""
		layer_color := renderer.Colour{255, 255, 255, 200}
		switch editor_state.selected_layer {
		case .BASE:
			layer_text = "BASE"
			layer_color = {100, 255, 100, 200}
		case .DECORATION:
			layer_text = "DECO"
			layer_color = {255, 255, 100, 200}
		case .ENTITY:
			layer_text = "ENTS"
			layer_color = {255, 100, 255, 200}
		}

		selected_text := ""
		if editor_state.selected_layer == .ENTITY {
			selected_text = fmt.tprintf("%v", editor_state.selected_entity)
		} else {
			selected_text = fmt.tprintf("%v", editor_state.selected_tile)
		}

		rl.DrawRectangle(10, 10, 120, 60, {0, 0, 0, 150})
		rl.DrawRectangleLines(10, 10, 120, 60, {255, 255, 255, 100})

		text_y: i32 = 20
		rl.DrawText(strings.unsafe_string_to_cstring(layer_text), 15, text_y, 12, layer_color)
		rl.DrawText(
			strings.unsafe_string_to_cstring(fmt.tprintf("Brush: %d", editor_state.brush_size)),
			15,
			text_y + 15,
			10,
			{255, 255, 255, 200},
		)
		rl.DrawText(
			strings.unsafe_string_to_cstring(selected_text),
			15,
			text_y + 30,
			10,
			{200, 200, 200, 200},
		)

		editor_draw_tile_carousel()

		controls_y := design_height - 60
		rl.DrawRectangle(10, i32(controls_y), 300, 50, {0, 0, 0, 120})
		rl.DrawRectangleLines(10, i32(controls_y), 300, 50, {255, 255, 255, 80})

		controls_text := "Left Stick: Move Cursor  B: Paint  A: Erase  RB/LB: Select  Y: Layer  H: Hide HUD"
		rl.DrawText(
			strings.unsafe_string_to_cstring(controls_text),
			15,
			i32(controls_y + 10),
			10,
			{200, 200, 200, 180},
		)
		controls_text2 := "Right Stick: Camera  RT/LT: Zoom  +/-: Brush  Select: Save  Start: Exit"
		rl.DrawText(
			strings.unsafe_string_to_cstring(controls_text2),
			15,
			i32(controls_y + 25),
			10,
			{200, 200, 200, 180},
		)
	}

	editor_fini :: proc() {
		delete(editor_state.pre_edit_players)
	}
}
