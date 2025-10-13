package hollie

import "asset"
import "audio"
import "core:fmt"
import "core:math/rand"
import "core:time"
import "input"
import "renderer"
import "tilemap"
import "tween"
import rl "vendor:raylib"

Door :: struct {
	position:    Vec2,
	size:        Vec2,
	target_room: string,
	target_door: string,
}

RoomResource :: struct {
	id:               string,
	name:             string,
	tilemap_config:   tilemap.TilemapResource,
	entities:         [dynamic]Entity_Spawn,
	music_path:       string,
	camera_bounds:    rl.Rectangle,
	collision_bounds: rl.Rectangle,
	doors:            [dynamic]Door,
}

Entity_Spawn :: struct {
	position: Vec2,
	type:     Entity_Type,
}

Entity_Type :: enum {
	Player,
	Enemy,
}

RoomState :: struct {
	current_bundle:          ^RoomResource,
	is_loaded:               bool,
	room_music:              audio.Music,
	room_name_opacity:       f32,
	room_name_display_timer: f32,
}

@(private)
room_state := RoomState{}

@(private)
room_collision_bounds: rl.Rectangle

room_set_collision_bounds :: proc(bounds: rl.Rectangle) {
	room_collision_bounds = bounds
}

room_get_collision_bounds :: proc() -> rl.Rectangle {
	return room_collision_bounds
}

room_check_door_collision :: proc(player_pos: Vec2) -> ^Door {
	if !room_state.is_loaded || room_state.current_bundle == nil do return nil

	for &door in room_state.current_bundle.doors {
		door_rect := rl.Rectangle{door.position.x, door.position.y, door.size.x, door.size.y}
		player_rect := rl.Rectangle{player_pos.x - 8, player_pos.y - 8, 16, 16}
		if rl.CheckCollisionRecs(door_rect, player_rect) {
			return &door
		}
	}
	return nil
}

room_get_current :: proc() -> ^RoomResource {
	return room_state.current_bundle
}

room_draw_doors_debug :: proc() {
	if !room_state.is_loaded || room_state.current_bundle == nil do return

	players := character_get_players()

	for &door in room_state.current_bundle.doors {
		door_rect := renderer.Rect{door.position.x, door.position.y, door.size.x, door.size.y}

		is_intersection := false
		for player in players {
			player_rect := renderer.Rect{player.position.x - 8, player.position.y - 8, 16, 16}
			if rects_intersect(door_rect, player_rect) {
				is_intersection = true
				break
			}
		}

		outline_color := is_intersection ? renderer.GREEN : renderer.RED
		door_color := renderer.fade(outline_color, 0.5)

		renderer.draw_rect(door.position.x, door.position.y, door.size.x, door.size.y, door_color)
		renderer.draw_rect_outline(
			door.position.x,
			door.position.y,
			door.size.x,
			door.size.y,
			color = outline_color,
		)

		renderer.draw_text(
			text = fmt.tprintf("%s", door.target_room),
			x = int(door.position.x),
			y = int(door.position.y - 20),
			size = 12,
		)
	}
}

room_init :: proc(res: ^RoomResource) {
	if room_state.is_loaded do room_fini()

	room_state.current_bundle = res

	if res.music_path != "" {
		room_state.room_music = audio.music_init(res.music_path)
		audio.music_set_volume(room_state.room_music, 1.0)
		audio.music_play(room_state.room_music)
	}

	tilemap.load_from_config(res.tilemap_config)
	camera_set_bounds(res.camera_bounds)
	room_set_collision_bounds(res.collision_bounds)

	player_spawn_count := 0
	for spawn in res.entities {
		switch spawn.type {
		case .Enemy: switch res.id {
				case "olivewood": enemy_spawn_race_at(spawn.position, .GOBLIN)
				case "desert": enemy_spawn_race_at(spawn.position, .SKELETON)
				}
		case .Player:
			player_spawn_at(spawn.position, input.Player_Index(player_spawn_count))
			player_spawn_count += 1
		}
	}

	room_state.is_loaded = true

	// Start level name fade-in effect
	room_state.room_name_opacity = 0.0
	room_state.room_name_display_timer = 0.0
	tween.to(&room_state.room_name_opacity, 1.0, .Quadratic_Out, 500 * time.Millisecond)
}

room_reload :: proc() {
	if room_state.current_bundle != nil {
		bundle := room_state.current_bundle
		room_fini()
		room_init(bundle)
	}
}

room_fini :: proc() {
	if !room_state.is_loaded do return

	if room_state.room_music.stream.buffer != nil {
		audio.music_stop(room_state.room_music)
		audio.music_fini(room_state.room_music)
	}

	tilemap.fini()

	// Clear characters for level unload/reload
	for &character in characters {
		character_destroy(&character)
	}
	clear(&characters)

	room_state.current_bundle = nil
	room_state.is_loaded = false
}

room_update :: proc() {
	if room_state.is_loaded && room_state.room_music.stream.buffer != nil {
		audio.music_update(room_state.room_music)
	}

	// Update level name display timer and fade out after 3 seconds
	if room_state.is_loaded && room_state.room_name_opacity > 0.0 {
		room_state.room_name_display_timer += rl.GetFrameTime()

		// Start fading out after 2.5 seconds (0.5s fade in + 2s display)
		if room_state.room_name_display_timer > 2.5 && room_state.room_name_opacity > 0.01 {
			// Only start fade-out tween if we haven't already
			if room_state.room_name_opacity >= 0.99 {
				tween.to(&room_state.room_name_opacity, 0.0, .Quadratic_In, time.Second)
			}
		}
	}
}

// returns an example level
room_new :: proc(width := 50, height := 30) -> RoomResource {
	// Try to load tilemap from file
	tilemap_config, map_ok := tilemap.load_tilemap_from_file(asset.path("maps/olivewood.map"))
	if !map_ok {
		// Fallback to procedural generation if file loading fails
		cfg := tilemap.TilemapConfig {
			tile_size    = 16,
			tileset_cols = 32,
		}

		// Create base layer data
		base_data := make([]tilemap.TileType, width * height)
		for y in 0 ..< height {
			for x in 0 ..< width {
				index := y * width + x
				base_data[index] = rand.choice(
					[]tilemap.TileType {
						.GRASS_1,
						.GRASS_2,
						.GRASS_3,
						.GRASS_4,
						.GRASS_5,
						.GRASS_6,
						.GRASS_7,
						.GRASS_8,
					},
				)
			}
		}

		// Create decorative layer data (sparse decorations)
		deco_data := make([]tilemap.TileType, width * height)
		for y in 0 ..< height {
			for x in 0 ..< width {
				index := y * width + x
				// 10% chance for decorative tiles, 90% empty
				if rand.float32() < 0.1 {
					deco_data[index] = rand.choice(
						[]tilemap.TileType {
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
						},
					)
				} else {
					deco_data[index] = .EMPTY
				}
			}
		}

		tilemap_config = tilemap.TilemapResource {
			width        = width,
			height       = height,
			tileset_path = asset.path("art/tileset/spr_tileset_sunnysideworld_16px.png"),
			base_data    = base_data,
			deco_data    = deco_data,
			config       = cfg,
		}
	}

	entities := make([dynamic]Entity_Spawn)
	append(&entities, Entity_Spawn{{240, 256}, .Player}) // Player 1
	append(&entities, Entity_Spawn{{272, 256}, .Player}) // Player 2
	for _ in 0 ..< 10 {
		x := rand.float32_range(128, 384)
		y := rand.float32_range(128, 384)
		append(&entities, Entity_Spawn{{x, y}, .Enemy})
	}

	camera_bounds := rl.Rectangle {
		0,
		0,
		f32(tilemap_config.width * tilemap_config.config.tile_size),
		f32(tilemap_config.height * tilemap_config.config.tile_size),
	}

	// Collision bounds are smaller than camera bounds for indoor feel
	collision_bounds := rl.Rectangle{32, 32, camera_bounds.width - 64, camera_bounds.height - 64}

	doors := make([dynamic]Door)
	// Add a door to the desert room on the right side
	append(
		&doors,
		Door {
			position = {camera_bounds.width - 48, camera_bounds.height / 2 - 32},
			size = {32, 64},
			target_room = "desert",
			target_door = "from_olivewood",
		},
	)

	// Setup basic 2-player puzzle: two pressure plates that open a gate
	room_setup_basic_puzzle()

	return RoomResource {
		id = "olivewood",
		name = "Olivewood",
		tilemap_config = tilemap_config,
		entities = entities,
		music_path = asset.path("audio/music/ambient.ogg"),
		camera_bounds = camera_bounds,
		collision_bounds = collision_bounds,
		doors = doors,
	}
}

room_new_sand :: proc(width := 50, height := 30) -> RoomResource {
	// Try to load tilemap from file
	tilemap_config, map_ok := tilemap.load_tilemap_from_file(asset.path("maps/desert.map"))
	if !map_ok {
		// Fallback to procedural generation if file loading fails
		cfg := tilemap.TilemapConfig {
			tile_size    = 16,
			tileset_cols = 32,
		}

		// Create base layer data
		base_data := make([]tilemap.TileType, width * height)
		for y in 0 ..< height {
			for x in 0 ..< width {
				index := y * width + x
				base_data[index] = rand.choice([]tilemap.TileType{.SAND_1, .SAND_2, .SAND_3})
			}
		}

		// Create decorative layer data (sparse sand decorations)
		deco_data := make([]tilemap.TileType, width * height)
		for y in 0 ..< height {
			for x in 0 ..< width {
				index := y * width + x
				// 10% chance for decorative tiles, 90% empty
				if rand.float32() < 0.1 {
					deco_data[index] = rand.choice(
						[]tilemap.TileType{.SAND_DEC_13, .SAND_DEC_14, .SAND_DEC_15, .SAND_DEC_16},
					)
				} else {
					deco_data[index] = .EMPTY
				}
			}
		}

		tilemap_config = tilemap.TilemapResource {
			width        = width,
			height       = height,
			tileset_path = asset.path("art/tileset/spr_tileset_sunnysideworld_16px.png"),
			base_data    = base_data,
			deco_data    = deco_data,
			config       = cfg,
		}
	}

	entities := make([dynamic]Entity_Spawn)
	append(&entities, Entity_Spawn{{240, 256}, .Player}) // Player 1
	append(&entities, Entity_Spawn{{272, 256}, .Player}) // Player 2
	for _ in 0 ..< 10 {
		x := rand.float32_range(128, 384)
		y := rand.float32_range(128, 384)
		append(&entities, Entity_Spawn{{x, y}, .Enemy})
	}

	camera_bounds := rl.Rectangle {
		0,
		0,
		f32(tilemap_config.width * tilemap_config.config.tile_size),
		f32(tilemap_config.height * tilemap_config.config.tile_size),
	}

	// Collision bounds are smaller than camera bounds for indoor feel
	collision_bounds := rl.Rectangle{32, 32, camera_bounds.width - 64, camera_bounds.height - 64}

	doors := make([dynamic]Door)
	// Add a door back to the olivewood room on the left side
	append(
		&doors,
		Door {
			position = {16, camera_bounds.height / 2 - 32},
			size = {32, 64},
			target_room = "olivewood",
			target_door = "from_desert",
		},
	)

	return RoomResource {
		id = "desert",
		name = "Blisterwind",
		tilemap_config = tilemap_config,
		entities = entities,
		music_path = asset.path("audio/music/ambient.ogg"),
		camera_bounds = camera_bounds,
		collision_bounds = collision_bounds,
		doors = doors,
	}
}

room_draw_name :: proc() {
	if !room_state.is_loaded || room_state.current_bundle == nil do return
	if room_state.room_name_opacity <= 0.01 do return

	room_name := room_state.current_bundle.name
	if room_name == "" do return

	// Calculate text size and position for centering using design resolution
	text_size := 48
	text_width := ui_measure_text(room_name, text_size)

	x := (int(design_width) - text_width) / 2
	y := 50

	// Create color with opacity for fade effect
	alpha := u8(room_state.room_name_opacity * 255)
	color := rl.Color{255, 255, 255, alpha}

	renderer.draw_text(room_name, x, y, text_size, color)
}

// Setup a basic puzzle for the olivewood room
room_setup_basic_puzzle :: proc() {
	// Create two pressure plates that both players must stand on simultaneously
	puzzle_trigger_create(1, .PRESSURE_PLATE, {150, 200}, {32, 32}, false) // Individual activation
	puzzle_trigger_create(2, .PRESSURE_PLATE, {350, 200}, {32, 32}, false) // Individual activation

	// Create a gate that blocks access to the upper area
	puzzle_gate_create(1, {240, 150}, {64, 16})

	// Link both plates to control the gate - gate opens only when BOTH are active
	puzzle_link_trigger_to_gate(1, 1)
	puzzle_link_trigger_to_gate(2, 1)
}

// Draw puzzle elements with placeholder sprites
room_draw_puzzle_elements :: proc() {
	if !room_state.is_loaded do return

	// Draw pressure plates with simple circular sprites
	for trigger in puzzle_system.triggers {
		if trigger.type == .PRESSURE_PLATE {
			center_x := trigger.position.x + trigger.size.x / 2
			center_y := trigger.position.y + trigger.size.y / 2
			radius := trigger.size.x / 2

			// Draw outline first (slightly larger darker circle)
			renderer.draw_circle(center_x, center_y, radius + 2, renderer.BLACK)

			// Draw base plate (always visible)
			base_color := renderer.fade(renderer.WHITE, 0.8)
			renderer.draw_circle(center_x, center_y, radius, base_color)

			// Draw activation indicator
			if trigger.active {
				active_color := renderer.fade(renderer.GREEN, 0.9)
				renderer.draw_circle(center_x, center_y, radius / 2, active_color)
			}
		}
	}

	// Draw gates with stone block sprites
	for gate in puzzle_system.gates {
		if !gate.open {
			// Draw stone blocks to represent the gate
			block_size := f32(16)
			blocks_x := int(gate.size.x / block_size)
			blocks_y := int(gate.size.y / block_size)

			for y in 0 ..< blocks_y {
				for x in 0 ..< blocks_x {
					block_x := gate.position.x + f32(x) * block_size
					block_y := gate.position.y + f32(y) * block_size

					// Alternating gray shades for texture
					stone_color: renderer.Colour
					if (x + y) % 2 == 0 {
						stone_color = renderer.fade(renderer.WHITE, 0.7)
					} else {
						stone_color = renderer.fade(renderer.WHITE, 0.5)
					}

					renderer.draw_rect(block_x, block_y, block_size, block_size, stone_color)
					renderer.draw_rect_outline(
						block_x,
						block_y,
						block_size,
						block_size,
						color = renderer.BLACK,
					)
				}
			}
		}
	}
}

// Draw puzzle debug info (debug mode only)
room_draw_puzzle_debug :: proc() {
	if !room_state.is_loaded do return

	// Draw trigger collision boxes
	for trigger in puzzle_system.triggers {
		outline_color := trigger.active ? renderer.GREEN : renderer.RED
		renderer.draw_rect_outline(
			trigger.position.x,
			trigger.position.y,
			trigger.size.x,
			trigger.size.y,
			color = outline_color,
		)
	}

	// Draw gate collision boxes
	for gate in puzzle_system.gates {
		if !gate.open {
			renderer.draw_rect_outline(
				gate.position.x,
				gate.position.y,
				gate.size.x,
				gate.size.y,
				color = renderer.RED,
			)
		}
	}
}
