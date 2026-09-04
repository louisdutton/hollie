package tilemap

import "core:strings"

Room_File_Conversion_Error_Kind :: enum {
	none,
	invalid_entity_type,
}

Room_File_Conversion_Error :: struct {
	kind:         Room_File_Conversion_Error_Kind,
	entity_index: int,
}

room_file_to_tilemap :: proc(
	room: Room_File,
	resource_root := "",
	allocator := context.allocator,
) -> (
	tm: TileMap,
	errors: [dynamic]Validation_Error,
) {
	context.allocator = allocator
	room_to_validate := room
	errors = validate_room_file(&room_to_validate, resource_root)
	if len(errors) > 0 do return
	tm = room_file_to_tilemap_unchecked(room, allocator)
	return
}

@(private = "file")
room_file_to_tilemap_unchecked :: proc(
	room: Room_File,
	allocator := context.allocator,
) -> TileMap {
	tm := TileMap {
		width = room.size.width,
		height = room.size.height,
		tile_size = room.grid.tile_size,
		config = {world_tile_size = room.grid.tile_size},
		room_id = strings.clone(room.id, allocator),
		room_name = strings.clone(room.name, allocator),
		music_path = strings.clone(room.music_path, allocator),
		camera_bounds = {
			x = room.camera_bounds.x,
			y = room.camera_bounds.y,
			width = room.camera_bounds.width,
			height = room.camera_bounds.height,
		},
		collision_bounds = {
			x = room.collision_bounds.x,
			y = room.collision_bounds.y,
			width = room.collision_bounds.width,
			height = room.collision_bounds.height,
		},
	}

	tm.base_tiles = make([]TileType, len(room.layers.base), allocator)
	for tile, index in room.layers.base {
		tm.base_tiles[index] = TileType(tile)
	}
	tm.deco_tiles = make([]TileType, len(room.layers.decoration), allocator)
	for tile, index in room.layers.decoration {
		tm.deco_tiles[index] = TileType(tile)
	}
	tm.collision_tiles = make([]CollisionType, room.size.width * room.size.height, allocator)
	for tile, index in room.layers.collision {
		tm.collision_tiles[index] = CollisionType(tile)
	}
	tm.structures = make([]Structure_Data, len(room.structures), allocator)
	for structure, index in room.structures {
		tm.structures[index] = {
			instance_id = strings.clone(structure.id, allocator),
			position    = {f32(structure.position.x), f32(structure.position.y)},
			size        = {f32(structure.size.width), f32(structure.size.height)},
		}
	}

	tm.entities = make([]EntityData, len(room.entities), allocator)
	for file_entity, entity_index in room.entities {
		entity := &tm.entities[entity_index]
		entity.instance_id = strings.clone(file_entity.id, allocator)
		entity.x = file_entity.position.x
		entity.y = file_entity.position.y
		entity.width = TILE_SIZE
		entity.height = TILE_SIZE
		entity.required_triggers = make([dynamic]int, allocator)

		switch properties in file_entity.properties {
		case Room_File_Player:
			entity.entity_type = .Player
			entity.player_index = properties.player_index
		case Room_File_Enemy:
			entity.entity_type = .Enemy
			entity.character_kind = properties.kind
		case Room_File_NPC: entity.entity_type = .Npc
		case Room_File_Holdable: entity.entity_type = .Holdable
		case Room_File_Door:
			entity.entity_type = .Door
			entity.width = properties.size.width
			entity.height = properties.size.height
			entity.target_room = strings.clone(properties.target_room_id, allocator)
			entity.target_door = strings.clone(properties.target_door_id, allocator)
		case Room_File_Pressure_Plate:
			entity.entity_type = .Pressure_Plate
			entity.width = 32
			entity.height = 32
			entity.trigger_id = properties.trigger_id
			entity.requires_both = properties.requires_both
		case Room_File_Gate:
			entity.entity_type = .Gate
			entity.gate_id = properties.gate_id
			entity.width = properties.size.width
			entity.height = properties.size.height
			entity.inverted = properties.inverted
			for trigger_id in properties.required_trigger_ids {
				append(&entity.required_triggers, trigger_id)
			}
		}
	}

	return tm
}

tilemap_to_room_file :: proc(
	tm: TileMap,
	allocator := context.allocator,
) -> (
	room: Room_File,
	err: Room_File_Conversion_Error,
) {
	room.id = strings.clone(tm.room_id, allocator)
	room.name = strings.clone(tm.room_name, allocator)
	room.music_path = strings.clone(tm.music_path, allocator)
	room.size = {
		width  = tm.width,
		height = tm.height,
	}
	room.grid = {
		tile_size = tm.config.world_tile_size,
	}
	room.camera_bounds = {
		x      = tm.camera_bounds.x,
		y      = tm.camera_bounds.y,
		width  = tm.camera_bounds.width,
		height = tm.camera_bounds.height,
	}
	room.collision_bounds = {
		x      = tm.collision_bounds.x,
		y      = tm.collision_bounds.y,
		width  = tm.collision_bounds.width,
		height = tm.collision_bounds.height,
	}
	room.layers.base = make([]u16, len(tm.base_tiles), allocator)
	for tile, index in tm.base_tiles {
		room.layers.base[index] = u16(tile)
	}
	room.layers.decoration = make([]u16, len(tm.deco_tiles), allocator)
	for tile, index in tm.deco_tiles {
		room.layers.decoration[index] = u16(tile)
	}
	room.layers.collision = make([]u8, len(tm.collision_tiles), allocator)
	for tile, index in tm.collision_tiles {
		room.layers.collision[index] = u8(tile)
	}
	room.structures = make([]Room_File_Structure, len(tm.structures), allocator)
	for structure, index in tm.structures {
		room.structures[index] = {
			id       = strings.clone(structure.instance_id, allocator),
			position = {int(structure.position.x), int(structure.position.y)},
			size     = {int(structure.size.x), int(structure.size.y)},
		}
	}

	room.entities = make([]Room_File_Entity, len(tm.entities), allocator)
	for entity, entity_index in tm.entities {
		if !entity_type_is_valid(entity.entity_type) {
			destroy_room_file(&room, allocator)
			return {}, {kind = .invalid_entity_type, entity_index = entity_index}
		}

		file_entity := &room.entities[entity_index]
		file_entity.id = strings.clone(entity.instance_id, allocator)
		file_entity.position = {
			x = entity.x,
			y = entity.y,
		}

		switch entity.entity_type {
		case .Player: file_entity.properties = Room_File_Player {
					player_index = entity.player_index,
				}
		case .Enemy: file_entity.properties = Room_File_Enemy {
					kind = entity.character_kind,
				}
		case .Npc: file_entity.properties = Room_File_NPC{}
		case .Holdable: file_entity.properties = Room_File_Holdable{}
		case .Door: file_entity.properties = Room_File_Door {
					size = {width = entity.width, height = entity.height},
					target_room_id = strings.clone(entity.target_room, allocator),
					target_door_id = strings.clone(entity.target_door, allocator),
				}
		case .Pressure_Plate: file_entity.properties = Room_File_Pressure_Plate {
					trigger_id    = entity.trigger_id,
					requires_both = entity.requires_both,
				}
		case .Gate:
			required_trigger_ids := make([]int, len(entity.required_triggers), allocator)
			copy(required_trigger_ids, entity.required_triggers[:])
			file_entity.properties = Room_File_Gate {
				gate_id = entity.gate_id,
				size = {width = entity.width, height = entity.height},
				required_trigger_ids = required_trigger_ids,
				inverted = entity.inverted,
			}
		}
	}

	return
}
