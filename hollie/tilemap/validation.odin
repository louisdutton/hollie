package tilemap

import "../content"
import "core:fmt"
import "core:os"
import "core:strings"

Validation_Error :: struct {
	entity_index: int,
	message:      string,
}

validation_add_error :: proc(
	errors: ^[dynamic]Validation_Error,
	message: string,
	entity_index := -1,
) {
	append(errors, Validation_Error{entity_index = entity_index, message = strings.clone(message)})
}

validation_add_owned_error :: proc(
	errors: ^[dynamic]Validation_Error,
	message: string,
	entity_index := -1,
) {
	append(errors, Validation_Error{entity_index = entity_index, message = message})
}

destroy_validation_errors :: proc(errors: ^[dynamic]Validation_Error) {
	if errors == nil do return
	for error in errors^ do delete(error.message)
	delete(errors^)
	errors^ = nil
}

validation_check_asset :: proc(
	errors: ^[dynamic]Validation_Error,
	resource_root, asset_path, description: string,
	entity_index := -1,
) {
	if asset_path == "" {
		validation_add_owned_error(
			errors,
			fmt.aprintf("%s path is empty", description),
			entity_index,
		)
		return
	}

	if resource_root == "" do return

	full_path := fmt.aprintf("%s/%s", resource_root, asset_path)
	defer delete(full_path)
	if !os.is_file(full_path) {
		validation_add_owned_error(
			errors,
			fmt.aprintf("%s does not exist: %s", description, asset_path),
			entity_index,
		)
	}
}

validate_room_file :: proc(room: ^Room_File, resource_root := "") -> [dynamic]Validation_Error {
	errors := make([dynamic]Validation_Error)

	if room.id == "" do validation_add_error(&errors, "room id must not be empty")
	if room.name == "" do validation_add_error(&errors, "room name must not be empty")
	if room.size.width <= 0 do validation_add_error(&errors, "room width must be positive")
	if room.size.height <= 0 do validation_add_error(&errors, "room height must be positive")
	if room.tileset.tile_size <= 0 do validation_add_error(&errors, "tileset tile_size must be positive")
	if room.tileset.columns <= 0 do validation_add_error(&errors, "tileset columns must be positive")

	expected_tile_count := room.size.width * room.size.height
	if room.size.width > 0 && room.size.height > 0 {
		if len(room.layers.base) != expected_tile_count {
			validation_add_owned_error(
				&errors,
				fmt.aprintf(
					"base layer contains %d tiles; expected %d",
					len(room.layers.base),
					expected_tile_count,
				),
			)
		}
		if len(room.layers.decoration) != expected_tile_count {
			validation_add_owned_error(
				&errors,
				fmt.aprintf(
					"decoration layer contains %d tiles; expected %d",
					len(room.layers.decoration),
					expected_tile_count,
				),
			)
		}
	}

	if room.camera_bounds.width <= 0 || room.camera_bounds.height <= 0 {
		validation_add_error(&errors, "camera bounds must have positive dimensions")
	}
	if room.collision_bounds.width <= 0 || room.collision_bounds.height <= 0 {
		validation_add_error(&errors, "collision bounds must have positive dimensions")
	}

	validation_check_asset(&errors, resource_root, room.tileset.path, "tileset")
	if room.music_path != "" {
		validation_check_asset(&errors, resource_root, room.music_path, "music")
	}

	map_width := room.size.width * room.tileset.tile_size
	map_height := room.size.height * room.tileset.tile_size
	valid_map_bounds := map_width > 0 && map_height > 0

	for entity, entity_index in room.entities {
		if entity.id == "" {
			validation_add_error(&errors, "entity id must not be empty", entity_index)
		} else {
			for previous, previous_index in room.entities {
				if previous_index >= entity_index do break
				if previous.id == entity.id {
					validation_add_owned_error(
						&errors,
						fmt.aprintf("entity id %q is duplicated", entity.id),
						entity_index,
					)
					break
				}
			}
		}

		if valid_map_bounds &&
		   (entity.position.x < 0 ||
				   entity.position.y < 0 ||
				   entity.position.x >= map_width ||
				   entity.position.y >= map_height) {
			validation_add_error(&errors, "entity origin lies outside the room", entity_index)
		}

		switch properties in entity.properties {
		case Room_File_Player:
			if properties.player_index < 1 || properties.player_index > 2 {
				validation_add_error(&errors, "player_index must be 1 or 2", entity_index)
			}
			for previous, previous_index in room.entities {
				if previous_index >= entity_index do break
				if previous_player, ok := previous.properties.(Room_File_Player);
				   ok && previous_player.player_index == properties.player_index {
					validation_add_owned_error(
						&errors,
						fmt.aprintf("player_index %d is duplicated", properties.player_index),
						entity_index,
					)
					break
				}
			}

		case Room_File_Enemy:
			if _, valid := content.character_kind_to_wire(properties.kind); !valid {
					validation_add_error(&errors, "enemy kind is invalid", entity_index)
				}

		case Room_File_NPC, Room_File_Holdable:

		case Room_File_Door:
			if properties.size.width <= 0 || properties.size.height <= 0 {
				validation_add_error(&errors, "door size must be positive", entity_index)
			}
			if properties.target_room_id == "" {
				validation_add_error(
					&errors,
					"door target_room_id must not be empty",
					entity_index,
				)
			}
			if properties.target_door_id == "" {
				validation_add_error(
					&errors,
					"door target_door_id must not be empty",
					entity_index,
				)
			}

		case Room_File_Pressure_Plate:
			if properties.trigger_id <= 0 {
				validation_add_error(
					&errors,
					"pressure plate trigger_id must be positive",
					entity_index,
				)
			}
			for previous, previous_index in room.entities {
				if previous_index >= entity_index do break
				if previous_plate, ok := previous.properties.(Room_File_Pressure_Plate);
				   ok && previous_plate.trigger_id == properties.trigger_id {
					validation_add_owned_error(
						&errors,
						fmt.aprintf(
							"pressure plate trigger_id %d is duplicated",
							properties.trigger_id,
						),
						entity_index,
					)
					break
				}
			}

		case Room_File_Gate:
			if properties.gate_id <= 0 {
				validation_add_error(&errors, "gate_id must be positive", entity_index)
			}
			if properties.size.width <= 0 || properties.size.height <= 0 {
				validation_add_error(&errors, "gate size must be positive", entity_index)
			}
			for previous, previous_index in room.entities {
				if previous_index >= entity_index do break
				if previous_gate, ok := previous.properties.(Room_File_Gate);
				   ok && previous_gate.gate_id == properties.gate_id {
					validation_add_owned_error(
						&errors,
						fmt.aprintf("gate_id %d is duplicated", properties.gate_id),
						entity_index,
					)
					break
				}
			}

			if len(properties.required_trigger_ids) == 0 {
				validation_add_error(
					&errors,
					"gate must require at least one trigger",
					entity_index,
				)
			}
			for trigger_id, trigger_index in properties.required_trigger_ids {
				if trigger_id <= 0 {
					validation_add_error(
						&errors,
						"gate trigger IDs must be positive",
						entity_index,
					)
					continue
				}

				for previous_trigger, previous_index in properties.required_trigger_ids {
					if previous_index >= trigger_index do break
					if previous_trigger == trigger_id {
						validation_add_owned_error(
							&errors,
							fmt.aprintf("gate trigger ID %d is duplicated", trigger_id),
							entity_index,
						)
						break
					}
				}

				trigger_exists := false
				for candidate in room.entities {
					if plate, ok := candidate.properties.(Room_File_Pressure_Plate);
					   ok && plate.trigger_id == trigger_id {
						trigger_exists = true
						break
					}
				}
				if !trigger_exists {
					validation_add_owned_error(
						&errors,
						fmt.aprintf("gate references missing trigger ID %d", trigger_id),
						entity_index,
					)
				}
			}
		}
	}

	return errors
}

validate_tilemap :: proc(tm: ^TileMap, resource_root := "") -> [dynamic]Validation_Error {
	errors := make([dynamic]Validation_Error)

	if tm.width <= 0 do validation_add_error(&errors, "width must be positive")
	if tm.height <= 0 do validation_add_error(&errors, "height must be positive")
	if tm.config.tile_size <= 0 do validation_add_error(&errors, "tile_size must be positive")
	if tm.config.tileset_cols <= 0 do validation_add_error(&errors, "tileset_cols must be positive")
	if tm.room_id == "" do validation_add_error(&errors, "room_id must not be empty")
	if tm.room_name == "" do validation_add_error(&errors, "room_name must not be empty")

	expected_tile_count := tm.width * tm.height
	if tm.width > 0 && tm.height > 0 {
		if len(tm.base_tiles) != expected_tile_count {
			validation_add_owned_error(
				&errors,
				fmt.aprintf(
					"base layer contains %d tiles; expected %d",
					len(tm.base_tiles),
					expected_tile_count,
				),
			)
		}
		if len(tm.deco_tiles) != expected_tile_count {
			validation_add_owned_error(
				&errors,
				fmt.aprintf(
					"decoration layer contains %d tiles; expected %d",
					len(tm.deco_tiles),
					expected_tile_count,
				),
			)
		}
	}

	if tm.camera_bounds.width <= 0 || tm.camera_bounds.height <= 0 {
		validation_add_error(&errors, "camera bounds must have positive dimensions")
	}
	if tm.collision_bounds.width <= 0 || tm.collision_bounds.height <= 0 {
		validation_add_error(&errors, "collision bounds must have positive dimensions")
	}

	validation_check_asset(&errors, resource_root, tm.tileset_path, "tileset")
	if tm.music_path != "" {
		validation_check_asset(&errors, resource_root, tm.music_path, "music")
	}

	map_width := tm.width * tm.config.tile_size
	map_height := tm.height * tm.config.tile_size

	for entity, entity_index in tm.entities {
		entity_type := int(entity.entity_type)
		if entity_type < int(EntityType.PLAYER) || entity_type > int(EntityType.DOOR) {
			validation_add_error(&errors, "entity type is invalid", entity_index)
			continue
		}

		if entity.width <= 0 || entity.height <= 0 {
			validation_add_error(&errors, "entity dimensions must be positive", entity_index)
		}
		if entity.x < 0 || entity.y < 0 || entity.x >= map_width || entity.y >= map_height {
			validation_add_error(&errors, "entity origin lies outside the room", entity_index)
		}

		switch entity.entity_type {
		case .PRESSURE_PLATE:
			if entity.trigger_id <= 0 {
				validation_add_error(
					&errors,
					"pressure plate trigger_id must be positive",
					entity_index,
				)
			}

			for other, other_index in tm.entities {
				if other_index >= entity_index do break
				if other.entity_type == .PRESSURE_PLATE && other.trigger_id == entity.trigger_id {
					validation_add_owned_error(
						&errors,
						fmt.aprintf(
							"pressure plate trigger_id %d is duplicated",
							entity.trigger_id,
						),
						entity_index,
					)
					break
				}
			}

		case .GATE:
			if len(entity.required_triggers) == 0 {
				validation_add_error(
					&errors,
					"gate must require at least one trigger",
					entity_index,
				)
			}

			for required_trigger, trigger_index in entity.required_triggers {
				if required_trigger <= 0 {
					validation_add_error(
						&errors,
						"gate trigger IDs must be positive",
						entity_index,
					)
					continue
				}

				for previous_trigger, previous_index in entity.required_triggers {
					if previous_index >= trigger_index do break
					if previous_trigger == required_trigger {
						validation_add_owned_error(
							&errors,
							fmt.aprintf("gate trigger ID %d is duplicated", required_trigger),
							entity_index,
						)
					}
				}

				trigger_exists := false
				for candidate in tm.entities {
					if candidate.entity_type == .PRESSURE_PLATE &&
					   candidate.trigger_id == required_trigger {
						trigger_exists = true
						break
					}
				}
				if !trigger_exists {
					validation_add_owned_error(
						&errors,
						fmt.aprintf("gate references missing trigger ID %d", required_trigger),
						entity_index,
					)
				}
			}

		case .ENEMY: if _, valid := content.character_kind_to_wire(entity.character_kind); !valid {
					validation_add_error(&errors, "enemy kind is invalid", entity_index)
				}

		case .NPC, .HOLDABLE:

		case .DOOR:
			if entity.target_room == "" {
				validation_add_error(&errors, "door target_room must not be empty", entity_index)
			}
			if entity.target_door == "" {
				validation_add_error(&errors, "door target_door must not be empty", entity_index)
			}

		case .PLAYER:
		}
	}

	return errors
}
