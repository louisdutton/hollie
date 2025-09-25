package hollie

import "audio"
import "core:math/rand"
import "tilemap"
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
	current_bundle: ^LevelResource,
	is_loaded:      bool,
	level_music:    audio.Music,
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
			enemy_spawn_at(spawn.position)
		case .Player:
			player_set_spawn_position(spawn.position)
		}
	}

	level_state.is_loaded = true
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
}

// returns an example level
level_new :: proc(width := 50, height := 30) -> LevelResource {
	tile_data := make([]tilemap.TileType, width * height)

	for y in 0 ..< height {
		for x in 0 ..< width {
			index := y * width + x
			tile_data[index] = rand.choice(
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

	entities := make([dynamic]Entity_Spawn)
	append(&entities, Entity_Spawn{{256, 256}, .Player})
	for i in 0 ..< 10 {
		x := rand.float32_range(128, 384)
		y := rand.float32_range(128, 384)
		append(&entities, Entity_Spawn{{x, y}, .Enemy})
	}

	return LevelResource {
		id = "example",
		name = "Example",
		tilemap_config = tilemap.TilemapResource {
			width = width,
			height = height,
			tileset_path = "res/art/tileset/spr_tileset_sunnysideworld_16px.png",
			tile_data = tile_data,
		},
		entities = entities,
		music_path = "res/audio/music/ambient.ogg",
		camera_bounds = {0, 0, 50 * 16, 30 * 16},
	}
}
