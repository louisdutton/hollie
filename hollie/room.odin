package hollie

import "asset"
import "audio"
import "core:fmt"
import "core:time"
import "input"
import "renderer"
import "tilemap"
import "tween"
import rl "vendor:raylib"


RoomState :: struct {
	current_bundle:          ^tilemap.TilemapResource,
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


room_get_current :: proc() -> ^tilemap.TilemapResource {
	return room_state.current_bundle
}

room_draw_doors_debug :: proc() {
	if !room_state.is_loaded do return

	players := entity_get_players()
	defer delete(players)
	doors := entity_get_doors()
	defer delete(doors)

	for door in doors {
		door_entity := Entity(door^)
		door_pos := entity_get_world_collider_pos(&door_entity)
		door_size := entity_get_collider_size(&door_entity)
		door_rect := renderer.Rect{door_pos.x, door_pos.y, door_size.x, door_size.y}

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

		renderer.draw_rect(door_pos.x, door_pos.y, door_size.x, door_size.y, door_color)
		renderer.draw_rect_outline(
			door_pos.x,
			door_pos.y,
			door_size.x,
			door_size.y,
			color = outline_color,
		)

		renderer.draw_text(
			text = fmt.tprintf("%s", door.target_room),
			x = int(door_pos.x),
			y = int(door_pos.y - 20),
			size = 12,
		)
	}
}

room_init :: proc(res: ^tilemap.TilemapResource) {
	if room_state.is_loaded do room_fini()

	room_state.current_bundle = res

	if res.music_path != "" {
		room_state.room_music = audio.music_init(asset.path(res.music_path))
		audio.music_set_volume(room_state.room_music, 1.0)
		audio.music_play(room_state.room_music)
	}

	tilemap.load_from_config(res^)
	camera_set_bounds(res.camera_bounds)
	room_set_collision_bounds(res.collision_bounds)

	// Get entity data from tilemap and spawn entities
	entity_data := tilemap.get_entities()
	player_spawn_count := 0

	for entity in entity_data {
		position := Vec2{f32(entity.x), f32(entity.y)}

		switch entity.entity_type {
		case 0:
			// Player
			player_spawn_at(position, input.Player_Index(player_spawn_count))
			player_spawn_count += 1
		case 1: // Enemy
				switch res.room_id {
				case "olivewood": enemy_spawn_race_at(position, .GOBLIN)
				case "desert": enemy_spawn_race_at(position, .SKELETON)
				}
		case 2: // Pressure_Plate
				entity_create_pressure_plate(position, entity.trigger_id, entity.requires_both)
		case 3:
			// Gate
			gate := entity_create_gate(
				position,
				Vec2{f32(entity.width), f32(entity.height)},
				entity.gate_id,
				entity.inverted,
			)
			for trigger_id in entity.required_triggers {
				append(&gate.required_triggers, trigger_id)
			}
		case 4: // Holdable
				entity_create_holdable(position, asset.path(entity.texture_path))
		case 5: // NPC
				entity_create_npc(position, .HUMAN, human_animations[:])
		case 6: // Door
				entity_create_door(
					position,
					Vec2{f32(entity.width), f32(entity.height)},
					entity.target_room,
					entity.target_door,
				)
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

	// Clear entities for level unload/reload
	clear(&entities)

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


room_draw_name :: proc() {
	if !room_state.is_loaded || room_state.current_bundle == nil do return
	if room_state.room_name_opacity <= 0.01 do return

	room_name := room_state.current_bundle.room_name
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


// Draw puzzle elements with placeholder sprites
room_draw_puzzle_elements :: proc() {
	if !room_state.is_loaded do return

	// Draw pressure plates with simple circular sprites
	pressure_plates := entity_get_pressure_plates()
	defer delete(pressure_plates)

	for plate in pressure_plates {
		center_x := plate.position.x
		center_y := plate.position.y
		radius := plate.collider.size.x / 2

		// Draw outline first (slightly larger darker circle)
		renderer.draw_circle(center_x, center_y, radius + 2, renderer.BLACK)

		// Draw base plate (always visible)
		base_color := renderer.fade(renderer.WHITE, 0.8)
		renderer.draw_circle(center_x, center_y, radius, base_color)

		// Draw activation indicator
		if plate.active {
			active_color := renderer.fade(renderer.GREEN, 0.9)
			renderer.draw_circle(center_x, center_y, radius / 2, active_color)
		}
	}

	// Draw gates with stone block sprites
	gates := entity_get_gates()
	defer delete(gates)

	for gate in gates {
		if !gate.open {
			// Draw stone blocks to represent the gate
			block_size := f32(16)
			blocks_x := int(gate.collider.size.x / block_size)
			blocks_y := int(gate.collider.size.y / block_size)

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
