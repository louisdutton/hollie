package main

import tilemap "../tilemap"
import "core:fmt"
import "core:os"

Loaded_Map :: struct {
	path: string,
	tm:   tilemap.TileMap,
}

find_room :: proc(maps: []Loaded_Map, room_id: string) -> (^Loaded_Map, bool) {
	for &loaded_map in maps {
		if loaded_map.tm.room_id == room_id do return &loaded_map, true
	}
	return nil, false
}

room_has_door_marker :: proc(tm: ^tilemap.TileMap, marker: string) -> bool {
	for entity in tm.entities {
		if entity.entity_type == .DOOR && entity.target_door == marker do return true
	}
	return false
}

main :: proc() {
	context.allocator = context.temp_allocator

	if len(os.args) < 3 {
		fmt.eprintln("usage: content_validate <resource-root> <map> [map ...]")
		os.exit(2)
	}

	resource_root := os.args[1]
	maps := make([dynamic]Loaded_Map)
	error_count := 0

	for map_path in os.args[2:] {
		tm, ok := tilemap.from_file(map_path)
		if !ok {
			fmt.eprintfln("error: %s: map syntax is invalid", map_path)
			error_count += 1
			continue
		}

		append(&maps, Loaded_Map{path = map_path, tm = tm})
		errors := tilemap.validate_tilemap(&tm, resource_root)
		for validation_error in errors {
			if validation_error.entity_index >= 0 {
				fmt.eprintfln(
					"error: %s: entity %d: %s",
					map_path,
					validation_error.entity_index + 1,
					validation_error.message,
				)
			} else {
				fmt.eprintfln("error: %s: %s", map_path, validation_error.message)
			}
			error_count += 1
		}
	}

	for source, source_index in maps {
		for candidate, candidate_index in maps {
			if candidate_index >= source_index do break
			if candidate.tm.room_id == source.tm.room_id {
				fmt.eprintfln(
					"error: %s: room_id %s is also used by %s",
					source.path,
					source.tm.room_id,
					candidate.path,
				)
				error_count += 1
			}
		}

		for entity, entity_index in source.tm.entities {
			if entity.entity_type != .DOOR || entity.target_room == "" do continue

			target, found := find_room(maps[:], entity.target_room)
			if !found {
				fmt.eprintfln(
					"error: %s: entity %d: target room does not exist: %s",
					source.path,
					entity_index + 1,
					entity.target_room,
				)
				error_count += 1
				continue
			}

			if entity.target_door != "" && !room_has_door_marker(&target.tm, entity.target_door) {
				fmt.eprintfln(
					"error: %s: entity %d: room %s has no door marker %s",
					source.path,
					entity_index + 1,
					entity.target_room,
					entity.target_door,
				)
				error_count += 1
			}
		}
	}

	if error_count > 0 {
		fmt.eprintfln("content validation failed with %d error(s)", error_count)
		os.exit(1)
	}

	fmt.printfln("validated %d map(s)", len(maps))
}
