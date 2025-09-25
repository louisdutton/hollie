package hollie

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
	set_camera_bounds(res.camera_bounds)

	for spawn in res.entities {
		switch spawn.type {
		case .Enemy:
			// Check level ID to spawn appropriate enemy type
			if res.id == "olivewood" {
				enemy_spawn_race_at(spawn.position, .GOBLIN)
			} else if res.id == "desert" {
				enemy_spawn_race_at(spawn.position, .SKELETON)
			} else {
				enemy_spawn_at(spawn.position) // Default behavior for other levels
			}
		case .Player:
			player_set_spawn_position(spawn.position)
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
	player = nil

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

	entities := make([dynamic]Entity_Spawn)
	append(&entities, Entity_Spawn{{256, 256}, .Player})
	for i in 0 ..< 10 {
		x := rand.float32_range(128, 384)
		y := rand.float32_range(128, 384)
		append(&entities, Entity_Spawn{{x, y}, .Enemy})
	}

	return LevelResource {
		id = "olivewood",
		name = "Olivewood",
		tilemap_config = tilemap.TilemapResource {
			width = width,
			height = height,
			tileset_path = "res/art/tileset/spr_tileset_sunnysideworld_16px.png",
			base_data = base_data,
			deco_data = deco_data,
		},
		entities = entities,
		music_path = "res/audio/music/ambient.ogg",
		camera_bounds = {0, 0, 50 * 16, 30 * 16},
	}
}

level_new_sand :: proc(width := 50, height := 30) -> LevelResource {
	// Create base layer data
	base_data := make([]tilemap.TileType, width * height)
	for y in 0 ..< height {
		for x in 0 ..< width {
			index := y * width + x
			base_data[index] = rand.choice(
				[]tilemap.TileType {
					.SAND_1,
					.SAND_2,
					.SAND_3,
				},
			)
		}
	}

	// Create empty decorative layer (no decorations for sand level)
	deco_data := make([]tilemap.TileType, width * height)
	for i in 0 ..< width * height {
		deco_data[i] = .EMPTY
	}

	entities := make([dynamic]Entity_Spawn)
	append(&entities, Entity_Spawn{{256, 256}, .Player})
	for i in 0 ..< 10 {
		x := rand.float32_range(128, 384)
		y := rand.float32_range(128, 384)
		append(&entities, Entity_Spawn{{x, y}, .Enemy})
	}

	return LevelResource {
		id = "desert",
		name = "Desert Sands",
		tilemap_config = tilemap.TilemapResource {
			width = width,
			height = height,
			tileset_path = "res/art/tileset/spr_tileset_sunnysideworld_16px.png",
			base_data = base_data,
			deco_data = deco_data,
		},
		entities = entities,
		music_path = "res/audio/music/ambient.ogg",
		camera_bounds = {0, 0, 50 * 16, 30 * 16},
	}
}

level_draw_name :: proc() {
	if !level_state.is_loaded || level_state.current_bundle == nil do return
	if level_state.level_name_opacity <= 0.01 do return

	level_name := level_state.current_bundle.name
	if level_name == "" do return

	// Calculate text size and position for centering at top of screen
	text_size: i32 = 48
	text_width := rl.MeasureText(cstring(raw_data(level_name)), text_size)

	screen_width := f32(rl.GetScreenWidth())
	x := (screen_width - f32(text_width)) / 2
	y: f32 = 50

	// Create color with opacity for fade effect
	alpha := u8(level_state.level_name_opacity * 255)
	color := rl.Color{255, 255, 255, alpha}

	renderer.draw_text(level_name, int(x), int(y), text_size, color)
}
