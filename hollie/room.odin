package hollie

import "asset"
import "audio"
import "core:math"
import "core:time"
import "graphics"
import "input"
import "tilemap"
import "tween"
import "window"


Room_State :: struct {
	current_tilemap:         ^tilemap.Tile_Map,
	is_loaded:               bool,
	room_music:              audio.Music,
	room_name_opacity:       f32,
	room_name_display_timer: f32,
	name_font:               graphics.Font,
	name_atlas_size:         i32,
}

ROOM_NAME_TEXT_SIZE :: f32(42)

room_name_atlas_size :: proc(scale: f32) -> i32 {
	return max(64, i32(math.ceil(ROOM_NAME_TEXT_SIZE * scale)))
}

@(private)
room_state := Room_State{}

@(private)
room_collision_bounds: graphics.Rect

room_set_collision_bounds :: proc(bounds: graphics.Rect) {
	room_collision_bounds = bounds
}

room_get_collision_bounds :: proc() -> graphics.Rect {
	return room_collision_bounds
}


room_get_current :: proc() -> ^tilemap.Tile_Map {
	return room_state.current_tilemap
}

room_door_spawn_candidates :: proc(door: Aabb, player: Collider, interior: bool) -> [14]Vec2 {
	GAP :: f32(2)
	center_x := (door.min.x + door.max.x - player.size.x) / 2 - player.offset.x
	center_z := (door.min.z + door.max.z - player.size.z) / 2 - player.offset.z
	north := Vec2{center_x, door.min.z - player.offset.z - player.size.z - GAP}
	south := Vec2{center_x, door.max.z - player.offset.z + GAP}
	west := Vec2{door.min.x - player.offset.x - player.size.x - GAP, center_z}
	east := Vec2{door.max.x - player.offset.x + GAP, center_z}
	first, second := south, north
	if interior do first, second = north, south
	x_spacing := Vec2{player.size.x + GAP, 0}
	z_spacing := Vec2{0, player.size.z + GAP}
	return {
		first,
		first - x_spacing,
		first + x_spacing,
		first - 2 * x_spacing,
		first + 2 * x_spacing,
		second,
		second - x_spacing,
		second + x_spacing,
		west,
		west - z_spacing,
		west + z_spacing,
		east,
		east - z_spacing,
		east + z_spacing,
	}
}

room_spawn_is_clear :: proc(position: Vec2, collider: Collider, occupied: []Aabb) -> bool {
	aabb := collision_aabb_at(position, collider)
	bounds := room_get_collision_bounds()
	if aabb.min.x < bounds.x ||
	   aabb.max.x > bounds.x + bounds.width ||
	   aabb.min.z < bounds.y ||
	   aabb.max.z > bounds.y + bounds.height {
		return false
	}
	// Exterior arrivals must remain outside the house, even though its interior is hollow.
	if tm := room_get_current(); tm != nil && !tm.interior {
		for structure in tm.structures {
			footprint := Aabb {
				min = {structure.position.x, 0, structure.position.y},
				max = {
					structure.position.x + structure.size.x,
					HOUSE_WALL_HEIGHT,
					structure.position.y + structure.size.y,
				},
			}
			if physics_overlap_horizontal(aabb, footprint) do return false
		}
	}
	if tilemap.check_collision(aabb) || collision_check_solid(position, collider) do return false
	for other in occupied {
		if aabbs_intersect(aabb, other) do return false
	}
	for &entity in world.entities {
		if _, ok := &entity.(Door); ok && aabbs_intersect(aabb, collision_entity_aabb(&entity)) {
			return false
		}
	}
	return true
}

room_find_door_spawn_position :: proc(door: Door, occupied: []Aabb = nil) -> Vec2 {
	player_collider := model_character_collider(true)
	door_bounds := collision_aabb_at(door.position, door.collider, door.height)
	candidates := room_door_spawn_candidates(
		door_bounds,
		player_collider,
		room_get_current().interior,
	)
	for candidate in candidates {
		if room_spawn_is_clear(candidate, player_collider, occupied) do return candidate
	}
	// Search for the nearest clear floor position if the doorway is crowded.
	door_center := Vec2 {
		(door_bounds.min.x + door_bounds.max.x) / 2,
		(door_bounds.min.z + door_bounds.max.z) / 2,
	}
	best: Vec2
	best_distance := f32(1e9)
	tile_size := f32(tilemap.get_tile_size())
	for y in 0 ..< tilemap.get_tilemap_height() {
		for x in 0 ..< tilemap.get_tilemap_width() {
			candidate := Vec2{(f32(x) + 0.5) * tile_size, (f32(y) + 0.5) * tile_size}
			if !tilemap.has_floor(x, y) || !room_spawn_is_clear(candidate, player_collider, occupied) do continue
			distance := get_distance(candidate, door_center)
			if distance < best_distance do best, best_distance = candidate, distance
		}
	}
	assert(best_distance < 1e9, "room has no clear player spawn outside its door triggers")
	return best
}

when ODIN_DEBUG {
	room_draw_collision_debug :: proc() {
		if !room_state.is_loaded do return

		tile_size := tilemap.get_tile_size()
		for y in 0 ..< tilemap.get_tilemap_height() {
			for x in 0 ..< tilemap.get_tilemap_width() {
				collision := tilemap.get_collision_tile(x, y)
				if collision == nil || collision^ != .Solid do continue
				world_x := f32(x * tile_size)
				world_y := f32(y * tile_size)
				graphics.draw_rect(
					world_x,
					world_y,
					f32(tile_size),
					f32(tile_size),
					graphics.Colour{255, 48, 48, 104},
				)
				graphics.draw_rect_outline(
					world_x,
					world_y,
					f32(tile_size),
					f32(tile_size),
					color = graphics.Colour{255, 96, 96, 192},
				)
			}
		}
	}

	room_draw_doors_debug :: proc() {
		if !room_state.is_loaded do return

		for &door_entity_value in world.entities {
			door, ok := &door_entity_value.(Door)
			if !ok do continue
			door_entity := Entity(door^)
			door_aabb := collision_entity_aabb(&door_entity)

			is_intersection := false
			for &player_entity in world.entities {
				player, ok := &player_entity.(Player)
				if !ok do continue
				player_entity_value := Entity(player^)
				if collision_entities_intersect(&door_entity, &player_entity_value) {
					is_intersection = true
					break
				}
			}

			outline_color := is_intersection ? graphics.GREEN : graphics.RED
			door_color := graphics.fade(outline_color, 0.5)

			door_pos := Vec2{door_aabb.min.x, door_aabb.min.z}
			door_size := Vec2{door_aabb.max.x - door_aabb.min.x, door_aabb.max.z - door_aabb.min.z}
			graphics.draw_rect(door_pos.x, door_pos.y, door_size.x, door_size.y, door_color)
			graphics.draw_rect_outline(
				door_pos.x,
				door_pos.y,
				door_size.x,
				door_size.y,
				color = outline_color,
			)

			graphics.draw_text(
				text = door.target_room,
				x = int(door_pos.x),
				y = int(door_pos.y - 20),
				size = 12,
			)
		}
	}
}

room_init :: proc(tm: ^tilemap.Tile_Map, target_door: string = "") {
	if room_state.is_loaded do room_fini()

	room_state.current_tilemap = tm

	if tm.music_path != "" {
		music_path := asset.path(tm.music_path)
		defer delete(music_path)
		room_state.room_music = audio.music_init(music_path)
		audio.music_set_volume(room_state.room_music, 1.0)
		audio.music_play(room_state.room_music)
	}

	tilemap.load_tilemap(tm^)
	shoreline_init()
	water_prepare_shore()
	camera_set_bounds(tm.camera_bounds)
	room_set_collision_bounds(tm.collision_bounds)

	// Get entity data from tilemap and spawn entities
	entity_data := tilemap.get_entities()

	for entity in entity_data {
		position := Vec2{f32(entity.x), f32(entity.y)}

		switch entity.entity_type {
		case .Player: // Player spawn markers are editor metadata; spawning is handled below.
				continue
		case .Enemy: enemy_spawn_kind_at(position, entity.character_kind)
		case .Pressure_Plate:
			pressure_plate_create(position, entity.trigger_id, entity.requires_both)
		case .Gate:
			gate := gate_create(
				position,
				Vec2{f32(entity.width), f32(entity.height)},
				entity.gate_id,
				entity.inverted,
			)
			for trigger_id in entity.required_triggers {
				append(&gate.required_triggers, trigger_id)
			}
			gate.breakable = entity.breakable
		case .Holdable: holdable_spawn_at(position)
		case .Npc: npc_spawn_at(position)
		case .Door:
			door_create(
					position,
					Vec2{f32(entity.width), f32(entity.height)},
					entity.target_room,
					entity.target_door,
				)
		}
	}

	// Spawn players at the target door (or first door if no target specified)
	spawn_door: ^Door = nil
	first_door: ^Door = nil
	if target_door != "" {
		// Find the door with matching target_door field
		for &entity in world.entities {
			door, ok := &entity.(Door)
			if !ok do continue
			if first_door == nil do first_door = door
			if door.target_door == target_door {
				spawn_door = door
				break
			}
		}
	}

	// If no target door specified or not found, use first door
	if spawn_door == nil {
		if first_door == nil {
			for &entity in world.entities {
				if door, ok := &entity.(Door); ok {
					first_door = door
					break
				}
			}
		}
		spawn_door = first_door
	}

	if spawn_door != nil {
		// Resolve both positions before appending can invalidate the door pointer.
		spawn_pos := room_find_door_spawn_position(spawn_door^)
		second_spawn: Vec2
		if game.player_count == 2 {
			occupied := [1]Aabb{collision_aabb_at(spawn_pos, model_character_collider(true))}
			second_spawn = room_find_door_spawn_position(spawn_door^, occupied[:])
		}
		player_spawn_at(spawn_pos, input.Player_Index.Player_1)
		if game.player_count == 2 {
			player_spawn_at(second_spawn, input.Player_Index.Player_2)
		}
	}

	room_state.is_loaded = true

	// Start level name fade-in effect
	room_state.room_name_opacity = 0.0
	room_state.room_name_display_timer = 0.0
	tween.to(&room_state.room_name_opacity, 1.0, .Quadratic_Out, 500 * time.Millisecond)
}

room_reload :: proc() {
	if room_state.current_tilemap != nil {
		tm := room_state.current_tilemap
		room_fini()
		room_init(tm)
	}
}

room_fini :: proc() {
	if room_state.name_atlas_size > 0 do graphics.unload_font(room_state.name_font)
	room_state.name_font = {}
	room_state.name_atlas_size = 0
	water_interaction_fini()
	water_unload_shore()
	shoreline_fini()
	grass_unload_geometry()
	grass_reset_trail()
	if !room_state.is_loaded do return

	if room_state.room_music.stream.buffer != nil {
		audio.music_stop(room_state.room_music)
		audio.music_fini(room_state.room_music)
	}

	room_state.room_music = {}
	dialog_fini()
	tilemap.fini()

	// Clear entities for level unload/reload
	clear(&particle_system.particles)
	world_clear_entities(&world)

	room_state.current_tilemap = nil
	room_state.is_loaded = false
}

room_update :: proc(dt: f32) {
	if room_state.is_loaded && room_state.room_music.stream.buffer != nil {
		audio.music_update(room_state.room_music)
	}

	// Update level name display timer and fade out after 3 seconds
	if room_state.is_loaded && room_state.room_name_opacity > 0.0 {
		room_state.room_name_display_timer += dt

		// Start fading out after 2.5 seconds (0.5s fade in + 2s display)
		if room_state.room_name_display_timer > 2.5 && room_state.room_name_opacity > 0.01 {
			// Only start fade-out tween if we haven't already
			if room_state.room_name_opacity >= 0.99 {
				tween.to(&room_state.room_name_opacity, 0.0, .Quadratic_In, time.Second)
			}
		}
	}
}


room_draw_name :: proc() {
	if !room_state.is_loaded || room_state.current_tilemap == nil do return
	if room_state.room_name_opacity <= 0.01 do return

	room_name := room_state.current_tilemap.room_name
	if room_name == "" do return

	// Rasterize at the physical display size instead of magnifying the UI atlas.
	atlas_size := room_name_atlas_size(window.get_ui_scale())
	if atlas_size != room_state.name_atlas_size {
		if room_state.name_atlas_size > 0 do graphics.unload_font(room_state.name_font)
		path := asset.path("font/aoboshi-one/AoboshiOne-Regular.ttf")
		defer delete(path)
		room_state.name_font = graphics.load_font(path, atlas_size)
		graphics.set_texture_filter(room_state.name_font.texture, .BILINEAR)
		room_state.name_atlas_size = atlas_size
	}
	text_width :=
		graphics.measure_text_ex(room_state.name_font, room_name, ROOM_NAME_TEXT_SIZE, 0).x
	x := (f32(design_width) - text_width) * 0.5
	color := graphics.Colour{244, 242, 234, u8(room_state.room_name_opacity * 255)}
	graphics.draw_text_ex(room_state.name_font, room_name, {x, 48}, ROOM_NAME_TEXT_SIZE, 0, color)
}


when ODIN_DEBUG {
	room_draw_puzzle_debug :: proc() {
		if !room_state.is_loaded do return

		// Draw pressure plate collision boxes
		for &entity in world.entities {
			plate, ok := &entity.(Pressure_Plate)
			if !ok do continue
			outline_color := plate.active ? graphics.GREEN : graphics.RED
			graphics.draw_rect_outline(
				plate.position.x + plate.collider.offset.x,
				plate.position.y + plate.collider.offset.z,
				plate.collider.size.x,
				plate.collider.size.z,
				color = outline_color,
			)
		}

		// Draw gate collision boxes
		for &entity in world.entities {
			gate, ok := &entity.(Gate)
			if !ok do continue
			if !gate.open {
				graphics.draw_rect_outline(
					gate.position.x + gate.collider.offset.x,
					gate.position.y + gate.collider.offset.z,
					gate.collider.size.x,
					gate.collider.size.z,
					color = graphics.RED,
				)
			}
		}
	}
}
