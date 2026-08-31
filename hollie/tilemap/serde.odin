package tilemap

import "../renderer"
import "core:fmt"
import "core:os"
import "core:strconv"
import "core:strings"

// Load complete tilemap from file
from_file :: proc(map_path: string) -> (tm: TileMap, ok: bool) {
	data, err := os.read_entire_file(map_path, context.allocator)
	if err != nil do return {}, false
	defer delete(data)

	return deserialise_tilemap(string(data))
}

// Save current tilemap to file
to_file :: proc(path: string) -> bool {
	builder := strings.builder_make()
	defer strings.builder_destroy(&builder)

	build_tilemap_content(&builder, &tilemap)

	content := strings.to_string(builder)
	return os.write_entire_file(path, content) == nil
}

// Build tilemap content into a builder
@(private)
build_tilemap_content :: proc(builder: ^strings.Builder, tm: ^TileMap) {
	// metadata
	section_start(builder, "config")
	write(builder, "width", tm.width)
	write(builder, "height", tm.height)
	write(builder, "tileset_path", tm.tileset_path)
	write(builder, "tile_size", tm.config.tile_size)
	write(builder, "tileset_cols", tm.config.tileset_cols)
	write(builder, "room_id", tm.room_id)
	write(builder, "room_name", tm.room_name)
	write(builder, "music_path", tm.music_path)
	write(builder, "camera_bounds", tm.camera_bounds)
	write(builder, "collision_bounds", tm.collision_bounds)
	section_end(builder)

	// base layer
	section_start(builder, "base_data")
	write_tiles(builder, tm.width, tm.height, tm.base_tiles)
	section_end(builder)

	// decorative layer
	section_start(builder, "deco_data")
	write_tiles(builder, tm.width, tm.height, tm.deco_tiles)
	section_end(builder)

	// entity layer
	section_start(builder, "entity_data")
	for entity in tm.entities {
		// Basic format: x,y,type
		strings.write_string(
			builder,
			fmt.tprintf("%d,%d,%d", entity.x, entity.y, int(entity.entity_type)),
		)

		// Check if entity needs extended format (has non-default values)
		has_extended_data :=
			entity.trigger_id != 0 ||
			entity.gate_id != 0 ||
			entity.requires_both ||
			entity.inverted ||
			entity.width != 16 ||
			entity.height != 16 ||
			entity.texture_path != "" ||
			entity.target_room != "" ||
			entity.target_door != "" ||
			len(entity.required_triggers) > 0

		if has_extended_data {
			strings.write_string(
				builder,
				fmt.tprintf(
					",%d,%d,%s,%s,%d,%d,%s,%s,%s",
					entity.trigger_id,
					entity.gate_id,
					entity.requires_both ? "true" : "false",
					entity.inverted ? "true" : "false",
					entity.width,
					entity.height,
					entity.texture_path,
					entity.target_room,
					entity.target_door,
				),
			)

			// Append required triggers
			for trigger in entity.required_triggers {
				strings.write_string(builder, fmt.tprintf(",%d", trigger))
			}
		}

		strings.write_string(builder, "\n")
	}
	section_end(builder)
}

// Serialise tilemap to string
@(private)
serialise_tilemap :: proc(tm: ^TileMap) -> string {
	builder := strings.builder_make()
	defer strings.builder_destroy(&builder)

	build_tilemap_content(&builder, tm)

	result := strings.clone(strings.to_string(builder))
	return result
}

// Parse tilemap from string
@(private)
deserialise_tilemap :: proc(content: string) -> (TileMap, bool) {
	lines := strings.split_lines(content)
	defer delete(lines)

	tm := TileMap {
		config = TilemapConfig{tile_size = TILE_SIZE, tileset_cols = 32},
	}

	current_section := ""
	parse_ok := true
	base_tiles := make([dynamic]TileType)
	deco_tiles := make([dynamic]TileType)
	entity_data := make([dynamic]EntityData)
	defer delete(base_tiles)
	defer delete(deco_tiles)
	defer delete(entity_data)

	for &line in lines {
		line = strings.trim_space(line)
		if len(line) == 0 || strings.has_prefix(line, "#") {
			continue
		}

		// Check for section headers
		if strings.has_prefix(line, "[") && strings.has_suffix(line, "]") {
			current_section = strings.trim(line, "[]")
			continue
		}

		switch current_section {
		case "config":
			parts := strings.split(line, "=")
			if len(parts) != 2 {
				parse_ok = false
				continue
			}
			defer delete(parts)

			key := strings.trim_space(parts[0])
			value := strings.trim_space(parts[1])

			switch key {
			case "width": if parsed_value, value_ok := strconv.parse_int(value); value_ok {
						tm.width = parsed_value
					} else {
						parse_ok = false
					}
			case "height": if parsed_value, value_ok := strconv.parse_int(value); value_ok {
						tm.height = parsed_value
					} else {
						parse_ok = false
					}
			case "tileset_path": tm.tileset_path = strings.clone(value)
			case "tile_size": if parsed_value, value_ok := strconv.parse_int(value); value_ok {
						tm.config.tile_size = parsed_value
						tm.tile_size = parsed_value
					} else {
						parse_ok = false
					}
			case "tileset_cols": if parsed_value, value_ok := strconv.parse_int(value); value_ok {
						tm.config.tileset_cols = parsed_value
					} else {
						parse_ok = false
					}
			case "room_id": tm.room_id = strings.clone(value)
			case "room_name": tm.room_name = strings.clone(value)
			case "music_path": tm.music_path = strings.clone(value)
			case "camera_bounds":
				bounds, bounds_ok := parse_rect(value)
				if bounds_ok {
					tm.camera_bounds = bounds
				} else {
					parse_ok = false
				}
			case "collision_bounds":
				bounds, bounds_ok := parse_rect(value)
				if bounds_ok {
					tm.collision_bounds = bounds
				} else {
					parse_ok = false
				}
			}

		case "base_data":
			// Parse comma-separated tile IDs
			tile_strs := strings.split(line, ",")
			defer delete(tile_strs)
			for &tile_str in tile_strs {
				tile_str = strings.trim_space(tile_str)
				if tile_id, tile_ok := strconv.parse_int(tile_str); tile_ok {
					append(&base_tiles, TileType(tile_id))
				} else {
					parse_ok = false
				}
			}

		case "deco_data":
			// Parse comma-separated tile IDs
			tile_strs := strings.split(line, ",")
			defer delete(tile_strs)
			for &tile_str in tile_strs {
				tile_str = strings.trim_space(tile_str)
				if tile_id, tile_ok := strconv.parse_int(tile_str); tile_ok {
					append(&deco_tiles, TileType(tile_id))
				} else {
					parse_ok = false
				}
			}

		case "entity_data":
			// Parse entity line: x,y,type,trigger_id,gate_id,requires_both,inverted,width,height,texture_path,target_room,target_door,required_triggers...
			parts := strings.split(line, ",")
			defer delete(parts)
			if len(parts) >= 3 {
				entity := EntityData {
					width  = TILE_SIZE,
					height = TILE_SIZE,
				}

				if x, x_ok := strconv.parse_int(strings.trim_space(parts[0])); x_ok {
					entity.x = x
				} else {
					parse_ok = false
				}
				if y, y_ok := strconv.parse_int(strings.trim_space(parts[1])); y_ok {
					entity.y = y
				} else {
					parse_ok = false
				}
				if entity_type_int, type_ok := strconv.parse_int(strings.trim_space(parts[2]));
				   type_ok &&
				   entity_type_int >= int(EntityType.PLAYER) &&
				   entity_type_int <= int(EntityType.DOOR) {
					entity.entity_type = EntityType(entity_type_int)
				} else {
					parse_ok = false
				}

				// Optional parameters
				if len(parts) > 3 {
					value := strings.trim_space(parts[3])
					if trigger_id, tid_ok := strconv.parse_int(value); tid_ok {
						entity.trigger_id = trigger_id
					} else if value != "" {
						parse_ok = false
					}
				}
				if len(parts) > 4 {
					value := strings.trim_space(parts[4])
					if gate_id, gid_ok := strconv.parse_int(value); gid_ok {
						entity.gate_id = gate_id
					} else if value != "" {
						parse_ok = false
					}
				}
				if len(parts) > 5 {
					value := strings.trim_space(parts[5])
					if value == "true" || value == "false" {
						entity.requires_both = value == "true"
					} else if value != "" {
						parse_ok = false
					}
				}
				if len(parts) > 6 {
					value := strings.trim_space(parts[6])
					if value == "true" || value == "false" {
						entity.inverted = value == "true"
					} else if value != "" {
						parse_ok = false
					}
				}
				if len(parts) > 7 {
					value := strings.trim_space(parts[7])
					if width, width_ok := strconv.parse_int(value); width_ok {
						if width > 0 do entity.width = width
					} else if value != "" {
						parse_ok = false
					}
				}
				if len(parts) > 8 {
					value := strings.trim_space(parts[8])
					if height, height_ok := strconv.parse_int(value); height_ok {
						if height > 0 do entity.height = height
					} else if value != "" {
						parse_ok = false
					}
				}
				if len(parts) > 9 do entity.texture_path = strings.clone(strings.trim_space(parts[9]))
				if len(parts) > 10 do entity.target_room = strings.clone(strings.trim_space(parts[10]))
				if len(parts) > 11 do entity.target_door = strings.clone(strings.trim_space(parts[11]))

				// Parse required_triggers after the common optional fields.
				entity.required_triggers = make([dynamic]int)
				start_index := 12
				for i in start_index ..< len(parts) {
					part := strings.trim_space(parts[i])
					if part != "" {
						if trigger_id, rt_ok := strconv.parse_int(part); rt_ok {
							append(&entity.required_triggers, trigger_id)
						} else {
							parse_ok = false
						}
					}
				}

				append(&entity_data, entity)
			} else {
				parse_ok = false
			}

		}
	}

	// Convert dynamic arrays to slices
	tm.base_tiles = make([]TileType, len(base_tiles))
	copy(tm.base_tiles, base_tiles[:])

	tm.deco_tiles = make([]TileType, len(deco_tiles))
	copy(tm.deco_tiles, deco_tiles[:])

	tm.entities = make([]EntityData, len(entity_data))
	copy(tm.entities, entity_data[:])

	return tm, parse_ok
}

@(private = "file")
write_rect :: proc(b: ^strings.Builder, key: string, rect: renderer.Rect) {
	strings.write_string(
		b,
		fmt.tprintf("%s=%.0f,%.0f,%.0f,%.0f\n", key, rect.x, rect.y, rect.width, rect.height),
	)
}

@(private = "file")
write_int :: proc(b: ^strings.Builder, key: string, value: int) {
	strings.write_string(b, fmt.tprintf("%s=%d\n", key, value))
}

@(private = "file")
write_string :: proc(b: ^strings.Builder, key: string, value: string) {
	strings.write_string(b, fmt.tprintf("%s=%s\n", key, value))
}

@(private = "file")
write_tiles :: proc(b: ^strings.Builder, w, h: int, tiles: []TileType) {
	for y in 0 ..< h {
		for x in 0 ..< w {
			idx := y * w + x
			if x > 0 {
				strings.write_string(b, ",")
			}
			tile_value := idx < len(tiles) ? int(tiles[idx]) : 0
			strings.write_string(b, fmt.tprintf("%d", tile_value))
		}
		strings.write_string(b, "\n")
	}
}

@(private = "file")
write :: proc {
	write_rect,
	write_int,
	write_string,
}

@(private = "file")
section_start :: proc(b: ^strings.Builder, key: string) {
	strings.write_string(b, fmt.tprintf("[%s]\n", key))
}

@(private = "file")
section_end :: proc(b: ^strings.Builder) {
	strings.write_string(b, "\n")
}

@(private = "file")
parse_rect :: proc(v: string) -> (renderer.Rect, bool) {
	parts := strings.split(v, ",")
	defer delete(parts)
	if len(parts) != 4 do return {}, false

	x, x_ok := strconv.parse_f32(strings.trim_space(parts[0]))
	y, y_ok := strconv.parse_f32(strings.trim_space(parts[1]))
	width, width_ok := strconv.parse_f32(strings.trim_space(parts[2]))
	height, height_ok := strconv.parse_f32(strings.trim_space(parts[3]))
	if !x_ok || !y_ok || !width_ok || !height_ok do return {}, false

	return {x = x, y = y, width = width, height = height}, true
}
