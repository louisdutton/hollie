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
		palette_scroll:     f32,
		palette_visible:    bool,
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
		palette_scroll     = 0,
		palette_visible    = true,
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

		camera.zoom = 1.0
		camera.target = {400, 300}
		camera.offset = {f32(design_width) / 2, f32(design_height) / 2}
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

		editor_draw_control_panel()
		if editor_state.palette_visible {
			editor_draw_tile_palette()
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

		if movement.x != 0 || movement.y != 0 {
			movement = input.vector2_normalize(movement)
			camera.target.x += movement.x * move_speed * dt / camera.zoom
			camera.target.y += movement.y * move_speed * dt / camera.zoom
		}

		wheel := rl.GetMouseWheelMove()
		if wheel != 0 {
			mouse_world_pos := rl.GetScreenToWorld2D(rl.GetMousePosition(), camera)
			camera.offset = rl.GetMousePosition()
			camera.target = mouse_world_pos

			zoom_increment: f32 = 0.125
			camera.zoom += wheel * zoom_increment
			camera.zoom = max(0.25, min(camera.zoom, 4.0))
		}
	}

	editor_handle_tile_selection :: proc() {
		if editor_state.selected_layer == .ENTITY {
			// Entity selection shortcuts
			if input.is_key_pressed(.ONE) do editor_state.selected_entity = .PLAYER
			if input.is_key_pressed(.TWO) do editor_state.selected_entity = .ENEMY
			if input.is_key_pressed(.THREE) do editor_state.selected_entity = .NPC
			if input.is_key_pressed(.FOUR) do editor_state.selected_entity = .HOLDABLE
			if input.is_key_pressed(.FIVE) do editor_state.selected_entity = .PRESSURE_PLATE
			if input.is_key_pressed(.SIX) do editor_state.selected_entity = .GATE
			if input.is_key_pressed(.SEVEN) do editor_state.selected_entity = .DOOR
		} else {
			// Tile selection shortcuts
			if input.is_key_pressed(.ONE) do editor_state.selected_tile = .GRASS_1
			if input.is_key_pressed(.TWO) do editor_state.selected_tile = .GRASS_2
			if input.is_key_pressed(.THREE) do editor_state.selected_tile = .GRASS_3
			if input.is_key_pressed(.FOUR) do editor_state.selected_tile = .GRASS_4
			if input.is_key_pressed(.FIVE) do editor_state.selected_tile = .GRASS_5
			if input.is_key_pressed(.SIX) do editor_state.selected_tile = .GRASS_6
			if input.is_key_pressed(.SEVEN) do editor_state.selected_tile = .GRASS_7
			if input.is_key_pressed(.EIGHT) do editor_state.selected_tile = .GRASS_8
			if input.is_key_pressed(.NINE) do editor_state.selected_tile = .SAND_1

			if input.is_key_pressed(.Q) do editor_state.selected_tile = .GRASS_DEC_1
			if input.is_key_pressed(.E) do editor_state.selected_tile = .GRASS_DEC_2
		}
	}

	editor_handle_painting_input :: proc() {
		mouse_pos := rl.GetMousePosition()
		world_pos := rl.GetScreenToWorld2D(mouse_pos, camera)
		tile_x, tile_y := tilemap.world_to_tile(world_pos)

		if rl.IsMouseButtonPressed(.LEFT) {
			editor_state.is_painting = true
			editor_paint_tile(tile_x, tile_y)
		} else if rl.IsMouseButtonPressed(.RIGHT) {
			editor_state.is_erasing = true
			editor_erase_tile(tile_x, tile_y)
		}

		if editor_state.is_painting && rl.IsMouseButtonDown(.LEFT) {
			editor_paint_tile(tile_x, tile_y)
		} else if editor_state.is_erasing && rl.IsMouseButtonDown(.RIGHT) {
			editor_erase_tile(tile_x, tile_y)
		}

		if rl.IsMouseButtonReleased(.LEFT) {
			editor_state.is_painting = false
		}
		if rl.IsMouseButtonReleased(.RIGHT) {
			editor_state.is_erasing = false
		}
	}

	editor_handle_ui_input :: proc() {
		if input.is_key_pressed(.TAB) {
			switch editor_state.selected_layer {
			case .BASE: editor_state.selected_layer = .DECORATION
			case .DECORATION: editor_state.selected_layer = .ENTITY
			case .ENTITY: editor_state.selected_layer = .BASE
			}
		}

		if input.is_key_pressed(.G) {
			editor_state.show_grid = !editor_state.show_grid
		}

		if input.is_key_pressed(.L) {
			editor_state.show_layer_overlay = !editor_state.show_layer_overlay
		}

		if input.is_key_pressed(.P) {
			editor_state.palette_visible = !editor_state.palette_visible
		}

		if (input.is_key_down(.LEFT_CONTROL) || input.is_key_down(.RIGHT_CONTROL)) &&
		   input.is_key_pressed(.S) {
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
			rl.DrawRectangle(i32(x), i32(y), i32(tile_size), i32(tile_size), color)
			rl.DrawRectangleLines(i32(x), i32(y), i32(tile_size), i32(tile_size), {0, 0, 0, 255})

			// Draw entity icon/text
			text_x := i32(x + tile_size / 2 - 4)
			text_y := i32(y + tile_size / 2 - 6)
			rl.DrawText(
				strings.unsafe_string_to_cstring(icon_text),
				text_x,
				text_y,
				12,
				{0, 0, 0, 255},
			)
		}
	}

	editor_draw_cursor :: proc() {
		mouse_pos := rl.GetMousePosition()
		world_pos := rl.GetScreenToWorld2D(mouse_pos, camera)
		tile_x, tile_y := tilemap.world_to_tile(world_pos)

		brush_half := editor_state.brush_size / 2
		cursor_color := renderer.Colour{255, 255, 0, 128}

		for dy in -brush_half ..= brush_half {
			for dx in -brush_half ..= brush_half {
				x := tile_x + dx
				y := tile_y + dy

				if x >= 0 &&
				   x < tilemap.get_tilemap_width() &&
				   y >= 0 &&
				   y < tilemap.get_tilemap_height() {
					world_x := f32(x * tilemap.get_tile_size())
					world_y := f32(y * tilemap.get_tile_size())

					rl.DrawRectangleLines(
						i32(world_x),
						i32(world_y),
						i32(tilemap.get_tile_size()),
						i32(tilemap.get_tile_size()),
						cursor_color,
					)
				}
			}
		}
	}

	editor_draw_control_panel :: proc() {
		panel_rect := rl.Rectangle{10, 10, 300, 220}
		ui_panel(panel_rect, "Tilemap Editor")

		layer_text := ""
		switch editor_state.selected_layer {
		case .BASE: layer_text = "Layer: BASE"
		case .DECORATION: layer_text = "Layer: DECORATION"
		case .ENTITY: layer_text = "Layer: ENTITY"
		}
		layer_rect := rl.Rectangle{20, 40, 100, 25}
		if ui_button(layer_rect, layer_text) {
			switch editor_state.selected_layer {
			case .BASE: editor_state.selected_layer = .DECORATION
			case .DECORATION: editor_state.selected_layer = .ENTITY
			case .ENTITY: editor_state.selected_layer = .BASE
			}
		}

		grid_text := editor_state.show_grid ? "Grid: ON" : "Grid: OFF"
		grid_rect := rl.Rectangle{130, 40, 80, 25}
		if ui_button(grid_rect, grid_text) {
			editor_state.show_grid = !editor_state.show_grid
		}

		overlay_text := editor_state.show_layer_overlay ? "Overlay: ON" : "Overlay: OFF"
		overlay_rect := rl.Rectangle{220, 40, 80, 25}
		if ui_button(overlay_rect, overlay_text) {
			editor_state.show_layer_overlay = !editor_state.show_layer_overlay
		}

		brush_rect := rl.Rectangle{20, 75, 200, 20}
		brush_value := f32(editor_state.brush_size)
		if ui_slider(brush_rect, "Brush Size:", &brush_value, 1, 5) {
			editor_state.brush_size = int(brush_value)
		}

		palette_text := editor_state.palette_visible ? "Hide Palette" : "Show Palette"
		palette_rect := rl.Rectangle{20, 105, 120, 25}
		if ui_button(palette_rect, palette_text) {
			editor_state.palette_visible = !editor_state.palette_visible
		}

		save_rect := rl.Rectangle{150, 105, 80, 25}
		if ui_button(save_rect, "Save (Ctrl+S)") {
			editor_save_current_tilemap()
		}

		exit_rect := rl.Rectangle{20, 135, 100, 25}
		if ui_button(exit_rect, "Exit Editor (F1)") {
			editor_exit_edit_mode()
		}

		current_room_name := ""
		switch gameplay_get_current_room() {
		case 0: current_room_name = "olivewood.map"
		case 1: current_room_name = "desert.map"
		case 2: current_room_name = "room.map"
		}

		ui_label(rl.Rectangle{20, 165, 280, 20}, fmt.tprintf("Room: %s", current_room_name))

		if editor_state.selected_layer == .ENTITY {
			ui_label(
				rl.Rectangle{20, 190, 280, 20},
				fmt.tprintf("Selected: %v", editor_state.selected_entity),
			)
		} else {
			ui_label(
				rl.Rectangle{20, 190, 280, 20},
				fmt.tprintf("Selected: %v", editor_state.selected_tile),
			)
		}
	}

	editor_draw_tile_palette :: proc() {
		if !editor_state.palette_visible do return

		design_width := f32(window.get_design_width())
		palette_width: f32 = 320
		palette_height: f32 = 400
		palette_x := design_width - palette_width - 10
		palette_y: f32 = 10

		palette_rect := rl.Rectangle{palette_x, palette_y, palette_width, palette_height}

		switch editor_state.selected_layer {
		case .BASE, .DECORATION:
			ui_panel(palette_rect, "Tile Palette")
			editor_draw_tile_sections(palette_x, palette_y, palette_width)
		case .ENTITY:
			ui_panel(palette_rect, "Entity Palette")
			editor_draw_entity_sections(palette_x, palette_y, palette_width)
		}
	}

	editor_draw_tile_sections :: proc(palette_x, palette_y, palette_width: f32) {
		tile_size: f32 = 32
		padding: f32 = 4
		tiles_per_row := int((palette_width - 20) / (tile_size + padding))
		y_offset: f32 = 40

		if editor_state.selected_layer == .BASE {
			grass_tiles := []tilemap.TileType {
				.GRASS_1,
				.GRASS_2,
				.GRASS_3,
				.GRASS_4,
				.GRASS_5,
				.GRASS_6,
				.GRASS_7,
				.GRASS_8,
			}
			sand_tiles := []tilemap.TileType{.SAND_1, .SAND_2, .SAND_3}

			ui_label(rl.Rectangle{palette_x + 10, palette_y + y_offset, 200, 20}, "Grass Tiles")
			y_offset += 25
			y_offset += editor_draw_tile_section(
				grass_tiles,
				palette_x + 10,
				palette_y + y_offset,
				tiles_per_row,
				tile_size,
				padding,
			)

			ui_label(rl.Rectangle{palette_x + 10, palette_y + y_offset, 200, 20}, "Sand Tiles")
			y_offset += 25
			y_offset += editor_draw_tile_section(
				sand_tiles,
				palette_x + 10,
				palette_y + y_offset,
				tiles_per_row,
				tile_size,
				padding,
			)
		} else if editor_state.selected_layer == .DECORATION {
			deco_tiles := []tilemap.TileType {
				.GRASS_DEC_1,
				.GRASS_DEC_2,
				.GRASS_DEC_3,
				.GRASS_DEC_4,
				.GRASS_DEC_5,
				.GRASS_DEC_6,
				.GRASS_DEC_7,
				.GRASS_DEC_8,
				.GRASS_DEC_9,
				.GRASS_DEC_10,
				.GRASS_DEC_11,
				.GRASS_DEC_12,
				.GRASS_DEC_13,
				.GRASS_DEC_14,
				.GRASS_DEC_15,
				.GRASS_DEC_16,
				.SAND_DEC_13,
				.SAND_DEC_14,
				.SAND_DEC_15,
				.SAND_DEC_16,
			}

			ui_label(
				rl.Rectangle{palette_x + 10, palette_y + y_offset, 200, 20},
				"Decoration Tiles",
			)
			y_offset += 25
			y_offset += editor_draw_tile_section(
				deco_tiles,
				palette_x + 10,
				palette_y + y_offset,
				tiles_per_row,
				tile_size,
				padding,
			)
		}
	}

	editor_draw_entity_sections :: proc(palette_x, palette_y, palette_width: f32) {
		button_width: f32 = 120
		button_height: f32 = 30
		padding: f32 = 5
		y_offset: f32 = 40

		entities := []tilemap.EntityType {
			.PLAYER,
			.ENEMY,
			.NPC,
			.HOLDABLE,
			.PRESSURE_PLATE,
			.GATE,
			.DOOR,
		}

		for entity_type in entities {
			button_rect := rl.Rectangle {
				palette_x + 10,
				palette_y + y_offset,
				button_width,
				button_height,
			}

			is_selected := editor_state.selected_entity == entity_type
			button_text := fmt.tprintf("%v", entity_type)

			if is_selected {
				rl.DrawRectangleRec(button_rect, {255, 255, 0, 128})
			}

			if ui_button(button_rect, button_text) {
				editor_state.selected_entity = entity_type
			}

			y_offset += button_height + padding
		}
	}

	editor_draw_tile_section :: proc(
		tiles: []tilemap.TileType,
		start_x, start_y: f32,
		tiles_per_row: int,
		tile_size, padding: f32,
	) -> f32 {
		rows := int(math.ceil(f32(len(tiles)) / f32(tiles_per_row)))
		height := f32(rows) * (tile_size + padding)

		for i in 0 ..< len(tiles) {
			tile_type := tiles[i]
			row := i / tiles_per_row
			col := i % tiles_per_row

			x := start_x + f32(col) * (tile_size + padding)
			y := start_y + f32(row) * (tile_size + padding)

			tile_rect := rl.Rectangle{x, y, tile_size, tile_size}

			is_selected := editor_state.selected_tile == tile_type
			border_color := is_selected ? rl.YELLOW : rl.GRAY

			rl.DrawRectangleRec(tile_rect, rl.WHITE)
			rl.DrawRectangleLinesEx(tile_rect, 2, border_color)

			source_rect := tilemap.get_tile_source_rect(tile_type)
			tileset := tilemap.get_tileset()
			if tileset.id != 0 {
				rl.DrawTexturePro(tileset, source_rect, tile_rect, {0, 0}, 0, rl.WHITE)
			}

			mouse_pos := gui.get_mouse_pos()
			if rl.CheckCollisionPointRec(mouse_pos, tile_rect) && rl.IsMouseButtonPressed(.LEFT) {
				editor_state.selected_tile = tile_type
			}
		}

		return height
	}

	editor_fini :: proc() {
		delete(editor_state.pre_edit_players)
	}
}
