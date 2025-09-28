package hollie

import "asset"
import "audio"
import "core:math/rand"
import "core:time"
import "renderer"
import "tilemap"
import "tween"
import rl "vendor:raylib"

LevelResource :: struct {
	id:             string,
	name:           string,
	tilemap_config: tilemap.TilemapResource,
	entities:       [dynamic]Entity_Spawn,
	music_path:     string,
	camera_bounds:  rl.Rectangle,
}

Entity_Spawn :: struct {
	position: Vec2,
	type:     Entity_Type,
}

Entity_Type :: enum {
	Player,
	Enemy,
}

LevelState :: struct {
	current_bundle:           ^LevelResource,
	is_loaded:                bool,
	level_music:              audio.Music,
	level_name_opacity:       f32,
	level_name_display_timer: f32,
}

@(private)
level_state := LevelState{}

level_init :: proc(res: ^LevelResource) {
	if level_state.is_loaded {
		level_fini()
	}

	level_state.current_bundle = res

	if res.music_path != "" {
		level_state.level_music = audio.music_init(res.music_path)
		audio.music_set_volume(level_state.level_music, 1.0)
		audio.music_play(level_state.level_music)
	}

	tilemap.load_from_config(res.tilemap_config)
	camera_set_bounds(res.camera_bounds)

	for spawn in res.entities {
		switch spawn.type {
		case .Enemy: // Check level ID to spawn appropriate enemy type
				if res.id == "olivewood" {
					enemy_spawn_race_at(spawn.position, .GOBLIN)
				} else if res.id == "desert" {
					enemy_spawn_race_at(spawn.position, .SKELETON)
				} else {
					enemy_spawn_at(spawn.position) // Default behavior for other levels
				}
		case .Player: player_spawn_at(spawn.position)
		}
	}

	level_state.is_loaded = true

	// Start level name fade-in effect
	level_state.level_name_opacity = 0.0
	level_state.level_name_display_timer = 0.0
	tween.to(&level_state.level_name_opacity, 1.0, .Quadratic_Out, 500 * time.Millisecond)
}

level_reload :: proc() {
	if level_state.current_bundle != nil {
		bundle := level_state.current_bundle
		level_fini()
		level_init(bundle)
	}
}

level_fini :: proc() {
	if !level_state.is_loaded do return

	if level_state.level_music.stream.buffer != nil {
		audio.music_stop(level_state.level_music)
		audio.music_fini(level_state.level_music)
	}

	tilemap.fini()

	// Clear characters for level unload/reload
	for &character in characters {
		character_destroy(&character)
	}
	clear(&characters)

	level_state.current_bundle = nil
	level_state.is_loaded = false
}

level_update :: proc() {
	if level_state.is_loaded && level_state.level_music.stream.buffer != nil {
		audio.music_update(level_state.level_music)
	}

	// Update level name display timer and fade out after 3 seconds
	if level_state.is_loaded && level_state.level_name_opacity > 0.0 {
		level_state.level_name_display_timer += rl.GetFrameTime()

		// Start fading out after 2.5 seconds (0.5s fade in + 2s display)
		if level_state.level_name_display_timer > 2.5 && level_state.level_name_opacity > 0.01 {
			// Only start fade-out tween if we haven't already
			if level_state.level_name_opacity >= 0.99 {
				tween.to(&level_state.level_name_opacity, 0.0, .Quadratic_In, time.Second)
			}
		}
	}
}

// returns an example level
level_new :: proc(width := 50, height := 30) -> LevelResource {
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
	append(&entities, Entity_Spawn{{256, 256}, .Player})
	for _ in 0 ..< 10 {
		x := rand.float32_range(128, 384)
		y := rand.float32_range(128, 384)
		append(&entities, Entity_Spawn{{x, y}, .Enemy})
	}

	return LevelResource {
		id = "olivewood",
		name = "Olivewood",
		tilemap_config = tilemap_config,
		entities = entities,
		music_path = asset.path("audio/music/ambient.ogg"),
		camera_bounds = {
			0,
			0,
			f32(tilemap_config.width * tilemap_config.config.tile_size),
			f32(tilemap_config.height * tilemap_config.config.tile_size),
		},
	}
}

level_new_sand :: proc(width := 50, height := 30) -> LevelResource {
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
	append(&entities, Entity_Spawn{{256, 256}, .Player})
	for _ in 0 ..< 10 {
		x := rand.float32_range(128, 384)
		y := rand.float32_range(128, 384)
		append(&entities, Entity_Spawn{{x, y}, .Enemy})
	}

	return LevelResource {
		id = "desert",
		name = "Blisterwind",
		tilemap_config = tilemap_config,
		entities = entities,
		music_path = asset.path("audio/music/ambient.ogg"),
		camera_bounds = {
			0,
			0,
			f32(tilemap_config.width * tilemap_config.config.tile_size),
			f32(tilemap_config.height * tilemap_config.config.tile_size),
		},
	}
}

level_draw_name :: proc() {
	if !level_state.is_loaded || level_state.current_bundle == nil do return
	if level_state.level_name_opacity <= 0.01 do return

	level_name := level_state.current_bundle.name
	if level_name == "" do return

	// Calculate text size and position for centering using design resolution
	text_size := 48
	text_width := ui_measure_text(level_name, text_size)

	x := (int(design_width) - text_width) / 2
	y := 50

	// Create color with opacity for fade effect
	alpha := u8(level_state.level_name_opacity * 255)
	color := rl.Color{255, 255, 255, alpha}

	renderer.draw_text(level_name, x, y, text_size, color)
}
