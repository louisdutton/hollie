package hollie

import "asset"
import "audio"
import "core:time"
import "graphics"
import "input"
import "tilemap"
import "tween"


RoomState :: struct {
	current_tilemap:         ^tilemap.TileMap,
	is_loaded:               bool,
	room_music:              audio.Music,
	room_name_opacity:       f32,
	room_name_display_timer: f32,
}

@(private)
room_state := RoomState{}

@(private)
room_collision_bounds: graphics.Rect

room_set_collision_bounds :: proc(bounds: graphics.Rect) {
	room_collision_bounds = bounds
}

room_get_collision_bounds :: proc() -> graphics.Rect {
	return room_collision_bounds
}


room_get_current :: proc() -> ^tilemap.TileMap {
	return room_state.current_tilemap
}

@(private = "file")
room_find_door_spawn_position :: proc(door: ^Door) -> Vec2 {
	player_collider := model_character_collider(true)
	player_size := player_collider.size
	door_center := door.position + Vec2{door.collider.size.x, door.collider.size.z} / 2
	candidates := [5]Vec2 {
		{door_center.x, door.position.y + door.collider.size.z + player_size.z},
		{door_center.x, door.position.y - player_size.y},
		{door.position.x + door.collider.size.x + player_size.x, door_center.y},
		{door.position.x - player_size.x, door_center.y},
		door_center,
	}

	for candidate in candidates {
		box := collision_box_at(candidate, player_collider)
		if !tilemap.check_collision(box) do return candidate
	}

	return door_center
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

		for &door_entity_value in entities {
			door, ok := &door_entity_value.(Door)
			if !ok do continue
			door_entity := Entity(door^)
			door_box := collision_entity_box(&door_entity)

			is_intersection := false
			for &player_entity in entities {
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

			door_pos := Vec2{door_box.min.x, door_box.min.z}
			door_size := Vec2{door_box.max.x - door_box.min.x, door_box.max.z - door_box.min.z}
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

room_init :: proc(tm: ^tilemap.TileMap, target_door: string = "") {
	if room_state.is_loaded do room_fini()

	room_state.current_tilemap = tm

	if tm.music_path != "" {
		room_state.room_music = audio.music_init(asset.path(tm.music_path))
		audio.music_set_volume(room_state.room_music, 1.0)
		audio.music_play(room_state.room_music)
	}

	tilemap.load_tilemap(tm^)
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
		for &entity in entities {
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
			for &entity in entities {
				if door, ok := &entity.(Door); ok {
					first_door = door
					break
				}
			}
		}
		spawn_door = first_door
	}

	if spawn_door != nil {
		spawn_pos := room_find_door_spawn_position(spawn_door)
		player_spawn_at(spawn_pos, input.Player_Index.Player_1)
		if game.player_count == 2 {
			player_spawn_at(spawn_pos + Vec2{16, 0}, input.Player_Index.Player_2)
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
	if !room_state.is_loaded do return

	if room_state.room_music.stream.buffer != nil {
		audio.music_stop(room_state.room_music)
		audio.music_fini(room_state.room_music)
	}

	tilemap.fini()

	// Clear entities for level unload/reload
	entity_destroy_all()

	room_state.current_tilemap = nil
	room_state.is_loaded = false
}

room_update :: proc() {
	if room_state.is_loaded && room_state.room_music.stream.buffer != nil {
		audio.music_update(room_state.room_music)
	}

	// Update level name display timer and fade out after 3 seconds
	if room_state.is_loaded && room_state.room_name_opacity > 0.0 {
		room_state.room_name_display_timer += graphics.get_frame_time()

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

	// Match the ornamental location title treatment from the Fantasy UI Borders sample.
	text_size := 42
	text_width := ui_measure_text(room_name, text_size)

	x := (int(design_width) - text_width) / 2
	y := 48

	// Create color with opacity for fade effect
	alpha := u8(room_state.room_name_opacity * 255)
	color := graphics.Colour{244, 242, 234, alpha}

	divider_gap: f32 = 14
	divider_height: f32 = 16
	max_divider_width: f32 = 96
	available_width := f32(design_width) - 40
	divider_width := min(
		max_divider_width,
		max((available_width - f32(text_width) - divider_gap * 2) / 2, 0),
	)
	divider_y := f32(y) + (f32(text_size) - divider_height) / 2

	content_left := f32(x)
	content_right := f32(x + text_width)
	if divider_width >= 24 {
		content_left -= divider_gap + divider_width
		content_right += divider_gap + divider_width
	}
	band_padding: f32 = 48
	band_y := f32(y) - 10
	band_height := f32(text_size) + 20
	band_left := max(content_left - band_padding, 0)
	band_right := min(content_right + band_padding, f32(design_width))
	band_fade_width := (band_right - band_left) * 0.42
	ui_draw_horizontally_faded_frame(
		.Title_Backdrop,
		{band_left, band_y, band_right - band_left, band_height},
		band_fade_width,
		graphics.Colour{42, 56, 63, u8(room_state.room_name_opacity * 255)},
	)

	if divider_width >= 24 {
		ui_draw_title_divider(
			{f32(x) - divider_gap - divider_width, divider_y, divider_width, divider_height},
			false,
			color,
		)
		ui_draw_title_divider(
			{f32(x + text_width) + divider_gap, divider_y, divider_width, divider_height},
			true,
			color,
		)
	}

	graphics.draw_text(room_name, x, y, text_size, color)
}


when ODIN_DEBUG {
	room_draw_puzzle_debug :: proc() {
		if !room_state.is_loaded do return

		// Draw pressure plate collision boxes
		for &entity in entities {
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
		for &entity in entities {
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
