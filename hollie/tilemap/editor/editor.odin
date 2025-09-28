package main

import "../"
import "../../"
import "../../asset"
import "../../gui"
import "../../input"
import "../../renderer"
import "../../window"
import "core:fmt"
import "core:math"
import rl "vendor:raylib"

Vec2 :: renderer.Vec2

/// Editor state and configuration
Editor :: struct {
	camera:             rl.Camera2D,
	selected_tile:      tilemap.TileType,
	selected_layer:     Layer,
	is_painting:        bool,
	is_erasing:         bool,
	brush_size:         int,
	show_grid:          bool,
	show_layer_overlay: bool,
	palette_scroll:     f32,
	palette_visible:    bool,
	current_file_path:  string,
}

Layer :: enum {
	BASE,
	DECORATION,
}

@(private)
editor_state := Editor {
	camera = {target = {400, 225}, offset = {400, 225}, rotation = 0, zoom = 2.0},
	selected_tile = .GRASS_1,
	selected_layer = .BASE,
	brush_size = 1,
	show_grid = true,
	show_layer_overlay = false,
	palette_scroll = 0,
	palette_visible = true,
	current_file_path = "maps/default.map",
}

/// Initialize the tilemap editor
editor_init :: proc() {
	gui.init()

	// Try to load tilemap from file first
	res, map_ok := tilemap.load_tilemap_from_file(asset.path("maps/default.map"))
	if !map_ok {
		// Fallback to hardcoded default if file loading fails
		res = tilemap.TilemapResource {
			width = 50,
			height = 30,
			tileset_path = asset.path("art/tileset/spr_tileset_sunnysideworld_16px.png"),
			base_data = {},
			deco_data = {},
			config = tilemap.TilemapConfig{tile_size = 16, tileset_cols = 32},
		}
	}

	tilemap.load_from_config(res)
}

/// Update editor state and handle input
editor_update :: proc() {
	handle_camera_input()
	handle_tile_selection()
	handle_painting_input()
	handle_ui_input()
}

/// Draw the editor interface
editor_draw :: proc() {
	// Draw world content
	{
		renderer.begin_mode_2d(editor_state.camera)
		defer renderer.end_mode_2d()

		tilemap.draw(editor_state.camera)
		draw_grid()
		draw_layer_overlay()
		draw_cursor()
	}

	// Draw UI with scaling
	{
		ui_begin()
		defer ui_end()

		draw_control_panel()
		if editor_state.palette_visible {
			draw_tile_palette()
		}
	}
}

/// Handle camera movement and zoom
handle_camera_input :: proc() {
	dt := rl.GetFrameTime()
	move_speed: f32 = 300.0

	// Camera movement with WASD
	movement := Vec2{0, 0}
	if input.is_key_down(.W) do movement.y -= 1
	if input.is_key_down(.S) do movement.y += 1
	if input.is_key_down(.A) do movement.x -= 1
	if input.is_key_down(.D) do movement.x += 1

	if movement.x != 0 || movement.y != 0 {
		movement = input.vector2_normalize(movement)
		editor_state.camera.target.x += movement.x * move_speed * dt / editor_state.camera.zoom
		editor_state.camera.target.y += movement.y * move_speed * dt / editor_state.camera.zoom
	}

	// Zoom with mouse wheel
	wheel := rl.GetMouseWheelMove()
	if wheel != 0 {
		mouse_world_pos := rl.GetScreenToWorld2D(rl.GetMousePosition(), editor_state.camera)
		editor_state.camera.offset = rl.GetMousePosition()
		editor_state.camera.target = mouse_world_pos

		zoom_increment: f32 = 0.125
		editor_state.camera.zoom += wheel * zoom_increment
		editor_state.camera.zoom = max(0.25, min(editor_state.camera.zoom, 4.0))
	}
}

/// Handle tile type selection with number keys
handle_tile_selection :: proc() {
	// Number keys 1-9 for common tiles
	if input.is_key_pressed(.ONE) do editor_state.selected_tile = .GRASS_1
	if input.is_key_pressed(.TWO) do editor_state.selected_tile = .GRASS_2
	if input.is_key_pressed(.THREE) do editor_state.selected_tile = .GRASS_3
	if input.is_key_pressed(.FOUR) do editor_state.selected_tile = .GRASS_4
	if input.is_key_pressed(.FIVE) do editor_state.selected_tile = .GRASS_5
	if input.is_key_pressed(.SIX) do editor_state.selected_tile = .GRASS_6
	if input.is_key_pressed(.SEVEN) do editor_state.selected_tile = .GRASS_7
	if input.is_key_pressed(.EIGHT) do editor_state.selected_tile = .GRASS_8
	if input.is_key_pressed(.NINE) do editor_state.selected_tile = .SAND_1

	// Q/E for decoration tiles
	if input.is_key_pressed(.Q) do editor_state.selected_tile = .GRASS_DEC_1
	if input.is_key_pressed(.E) do editor_state.selected_tile = .GRASS_DEC_2
}

/// Handle painting and erasing input
handle_painting_input :: proc() {
	mouse_pos := rl.GetMousePosition()
	world_pos := rl.GetScreenToWorld2D(mouse_pos, editor_state.camera)
	tile_x, tile_y := tilemap.world_to_tile(world_pos)

	// Start painting/erasing
	if rl.IsMouseButtonPressed(.LEFT) {
		editor_state.is_painting = true
		paint_tile(tile_x, tile_y)
	} else if rl.IsMouseButtonPressed(.RIGHT) {
		editor_state.is_erasing = true
		erase_tile(tile_x, tile_y)
	}

	// Continue painting/erasing while held
	if editor_state.is_painting && rl.IsMouseButtonDown(.LEFT) {
		paint_tile(tile_x, tile_y)
	} else if editor_state.is_erasing && rl.IsMouseButtonDown(.RIGHT) {
		erase_tile(tile_x, tile_y)
	}

	// Stop painting/erasing
	if rl.IsMouseButtonReleased(.LEFT) {
		editor_state.is_painting = false
	}
	if rl.IsMouseButtonReleased(.RIGHT) {
		editor_state.is_erasing = false
	}
}

/// Handle UI and editor mode input
handle_ui_input :: proc() {
	// Toggle layer with TAB
	if input.is_key_pressed(.TAB) {
		editor_state.selected_layer = editor_state.selected_layer == .BASE ? .DECORATION : .BASE
	}

	// Toggle grid with G
	if input.is_key_pressed(.G) {
		editor_state.show_grid = !editor_state.show_grid
	}

	// Toggle layer overlay with L
	if input.is_key_pressed(.L) {
		editor_state.show_layer_overlay = !editor_state.show_layer_overlay
	}

	// Toggle palette with P
	if input.is_key_pressed(.P) {
		editor_state.palette_visible = !editor_state.palette_visible
	}

	// Save with Ctrl+S
	if (input.is_key_down(.LEFT_CONTROL) || input.is_key_down(.RIGHT_CONTROL)) &&
	   input.is_key_pressed(.S) {
		save_current_tilemap()
	}

	// Brush size with +/-
	if input.is_key_pressed(.EQUAL) {
		editor_state.brush_size = min(editor_state.brush_size + 1, 5)
	}
	if input.is_key_pressed(.MINUS) {
		editor_state.brush_size = max(editor_state.brush_size - 1, 1)
	}
}

/// Save the current tilemap to file
save_current_tilemap :: proc() {
	full_path := asset.path(editor_state.current_file_path)
	if tilemap.save_tilemap_to_file(full_path) {
		fmt.println("Tilemap saved to:", full_path)
	} else {
		fmt.println("Failed to save tilemap to:", full_path)
	}
}

/// Paint a tile at the specified coordinates
paint_tile :: proc(tile_x, tile_y: int) {
	for dy in -(editor_state.brush_size / 2) ..= (editor_state.brush_size / 2) {
		for dx in -(editor_state.brush_size / 2) ..= (editor_state.brush_size / 2) {
			x := tile_x + dx
			y := tile_y + dy

			switch editor_state.selected_layer {
			case .BASE: if tile := tilemap.get_base_tile(x, y); tile != nil {
						tile.type = editor_state.selected_tile
					}
			case .DECORATION: if tile := tilemap.get_deco_tile(x, y); tile != nil {
						tile.type = editor_state.selected_tile
					}
			}
		}
	}
}

/// Erase a tile at the specified coordinates
erase_tile :: proc(tile_x, tile_y: int) {
	for dy in -(editor_state.brush_size / 2) ..= (editor_state.brush_size / 2) {
		for dx in -(editor_state.brush_size / 2) ..= (editor_state.brush_size / 2) {
			x := tile_x + dx
			y := tile_y + dy

			switch editor_state.selected_layer {
			case .BASE: if tile := tilemap.get_base_tile(x, y); tile != nil {
						tile.type = .GRASS_1 // Default grass
					}
			case .DECORATION: if tile := tilemap.get_deco_tile(x, y); tile != nil {
						tile.type = .EMPTY
					}
			}
		}
	}
}

/// Draw grid overlay
draw_grid :: proc() {
	if !editor_state.show_grid do return

	screen_width := f32(rl.GetScreenWidth())
	screen_height := f32(rl.GetScreenHeight())

	world_min := rl.GetScreenToWorld2D({0, 0}, editor_state.camera)
	world_max := rl.GetScreenToWorld2D({screen_width, screen_height}, editor_state.camera)

	tile_size := f32(tilemap.get_tile_size())
	start_x := max(0, int(world_min.x / tile_size))
	end_x := min(tilemap.get_tilemap_width(), int(world_max.x / tile_size) + 1)
	start_y := max(0, int(world_min.y / tile_size))
	end_y := min(tilemap.get_tilemap_height(), int(world_max.y / tile_size) + 1)

	grid_color := renderer.Colour{255, 255, 255, 64}

	// Vertical lines
	for x in start_x ..= end_x {
		world_x := f32(x * tilemap.get_tile_size())
		start_world_y := f32(start_y * tilemap.get_tile_size())
		end_world_y := f32(end_y * tilemap.get_tile_size())
		rl.DrawLine(i32(world_x), i32(start_world_y), i32(world_x), i32(end_world_y), grid_color)
	}

	// Horizontal lines
	for y in start_y ..= end_y {
		world_y := f32(y * tilemap.get_tile_size())
		start_world_x := f32(start_x * tilemap.get_tile_size())
		end_world_x := f32(end_x * tilemap.get_tile_size())
		rl.DrawLine(i32(start_world_x), i32(world_y), i32(end_world_x), i32(world_y), grid_color)
	}
}

/// Draw layer overlay to highlight current layer
draw_layer_overlay :: proc() {
	if !editor_state.show_layer_overlay do return

	if editor_state.selected_layer == .DECORATION {
		overlay_color := renderer.Colour{0, 255, 0, 32}
		screen_min := rl.GetWorldToScreen2D({0, 0}, editor_state.camera)
		screen_max := rl.GetWorldToScreen2D(
			{
				f32(tilemap.get_tilemap_width() * tilemap.get_tile_size()),
				f32(tilemap.get_tilemap_height() * tilemap.get_tile_size()),
			},
			editor_state.camera,
		)

		rl.DrawRectangle(
			i32(screen_min.x),
			i32(screen_min.y),
			i32(screen_max.x - screen_min.x),
			i32(screen_max.y - screen_min.y),
			overlay_color,
		)
	}
}

/// Draw cursor showing current tile and brush size
draw_cursor :: proc() {
	mouse_pos := rl.GetMousePosition()
	world_pos := rl.GetScreenToWorld2D(mouse_pos, editor_state.camera)
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

/// Draw main control panel using custom GUI
draw_control_panel :: proc() {
	panel_rect := rl.Rectangle{10, 10, 300, 190}
	ui_panel(panel_rect, "Tilemap Editor")

	// Layer toggle
	layer_text := editor_state.selected_layer == .BASE ? "Layer: BASE" : "Layer: DECORATION"
	layer_rect := rl.Rectangle{20, 40, 100, 25}
	if ui_button(layer_rect, layer_text) {
		editor_state.selected_layer = editor_state.selected_layer == .BASE ? .DECORATION : .BASE
	}

	// Grid toggle
	grid_text := editor_state.show_grid ? "Grid: ON" : "Grid: OFF"
	grid_rect := rl.Rectangle{130, 40, 80, 25}
	if ui_button(grid_rect, grid_text) {
		editor_state.show_grid = !editor_state.show_grid
	}

	// Overlay toggle
	overlay_text := editor_state.show_layer_overlay ? "Overlay: ON" : "Overlay: OFF"
	overlay_rect := rl.Rectangle{220, 40, 80, 25}
	if ui_button(overlay_rect, overlay_text) {
		editor_state.show_layer_overlay = !editor_state.show_layer_overlay
	}

	// Brush size slider
	brush_rect := rl.Rectangle{20, 75, 200, 20}
	brush_value := f32(editor_state.brush_size)
	if ui_slider(brush_rect, "Brush Size:", &brush_value, 1, 5) {
		editor_state.brush_size = int(brush_value)
	}

	// Palette toggle
	palette_text := editor_state.palette_visible ? "Hide Palette" : "Show Palette"
	palette_rect := rl.Rectangle{20, 105, 120, 25}
	if ui_button(palette_rect, palette_text) {
		editor_state.palette_visible = !editor_state.palette_visible
	}

	// Save button
	save_rect := rl.Rectangle{150, 105, 80, 25}
	if ui_button(save_rect, "Save (Ctrl+S)") {
		save_current_tilemap()
	}

	// Current file info
	ui_label(
		rl.Rectangle{20, 135, 280, 20},
		fmt.tprintf("File: %s", editor_state.current_file_path),
	)

	// Current tile info
	ui_label(
		rl.Rectangle{20, 160, 280, 20},
		fmt.tprintf("Selected: %v", editor_state.selected_tile),
	)
}

/// Draw visual tile palette
draw_tile_palette :: proc() {
	if !editor_state.palette_visible do return

	// Use design coordinates that will be scaled by ui_begin/ui_end
	design_width := f32(window.get_design_width())
	palette_width: f32 = 320
	palette_height: f32 = 400
	palette_x := design_width - palette_width - 10
	palette_y: f32 = 10

	palette_rect := rl.Rectangle{palette_x, palette_y, palette_width, palette_height}
	ui_panel(palette_rect, "Tile Palette")

	// Define available tiles for each category
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

	tile_size: f32 = 32
	padding: f32 = 4
	tiles_per_row := int((palette_width - 20) / (tile_size + padding))

	y_offset: f32 = 40

	// Grass tiles section
	ui_label(rl.Rectangle{palette_x + 10, palette_y + y_offset, 200, 20}, "Grass Tiles")
	y_offset += 25
	y_offset += draw_tile_section(
		grass_tiles,
		palette_x + 10,
		palette_y + y_offset,
		tiles_per_row,
		tile_size,
		padding,
	)

	// Sand tiles section
	ui_label(rl.Rectangle{palette_x + 10, palette_y + y_offset, 200, 20}, "Sand Tiles")
	y_offset += 25
	y_offset += draw_tile_section(
		sand_tiles,
		palette_x + 10,
		palette_y + y_offset,
		tiles_per_row,
		tile_size,
		padding,
	)

	// Decoration tiles section
	ui_label(rl.Rectangle{palette_x + 10, palette_y + y_offset, 200, 20}, "Decoration Tiles")
	y_offset += 25
	y_offset += draw_tile_section(
		deco_tiles,
		palette_x + 10,
		palette_y + y_offset,
		tiles_per_row,
		tile_size,
		padding,
	)
}

/// Draw a section of tiles and return the height used
draw_tile_section :: proc(
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

		// Check if this tile is selected
		is_selected := editor_state.selected_tile == tile_type
		border_color := is_selected ? rl.YELLOW : rl.GRAY

		// Draw tile background
		rl.DrawRectangleRec(tile_rect, rl.WHITE)
		rl.DrawRectangleLinesEx(tile_rect, 2, border_color)

		// Draw tile sprite
		source_rect := tilemap.get_tile_source_rect(tile_type)
		tileset := tilemap.get_tileset()
		if tileset.id != 0 {
			rl.DrawTexturePro(tileset, source_rect, tile_rect, {0, 0}, 0, rl.WHITE)
		}

		// Handle click with transformed mouse coordinates
		mouse_pos := gui.get_mouse_pos()
		if rl.CheckCollisionPointRec(mouse_pos, tile_rect) && rl.IsMouseButtonPressed(.LEFT) {
			editor_state.selected_tile = tile_type
		}
	}

	return height
}

/// Clean up editor resources
editor_fini :: proc() {
	tilemap.fini()
}
