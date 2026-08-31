package hollie

import "core:fmt"
import "core:os"
import "core:slice"
import "core:strings"
import "tilemap"

Room_Registry_Entry :: struct {
	id:   string,
	name: string,
	path: string,
}

Room_Registry :: struct {
	entries: [dynamic]Room_Registry_Entry,
}

Room_Registry_Error_Kind :: enum {
	none,
	directory_read_failed,
	room_load_failed,
	room_id_mismatch,
	duplicate_room_id,
	no_rooms_found,
}

Room_Registry_Error :: struct {
	kind:    Room_Registry_Error_Kind,
	message: string,
}

room_registry_error :: proc(
	kind: Room_Registry_Error_Kind,
	message: string,
) -> Room_Registry_Error {
	return {kind = kind, message = strings.clone(message)}
}

room_registry_load :: proc(
	directory, resource_root: string,
	allocator := context.allocator,
) -> (
	registry: Room_Registry,
	err: Room_Registry_Error,
) {
	context.allocator = allocator
	registry.entries = make([dynamic]Room_Registry_Entry, allocator)

	files, read_error := os.read_all_directory_by_path(directory, allocator)
	if read_error != nil {
		destroy_room_registry(&registry, allocator)
		return {}, room_registry_error(
			.directory_read_failed,
			fmt.tprintf("%s: could not discover rooms: %v", directory, read_error),
		)
	}
	defer os.file_info_slice_delete(files, allocator)

	for file in files {
		if !os.is_file(file.fullpath) ||
		   !strings.has_suffix(file.name, tilemap.ROOM_FILE_EXTENSION) {
			continue
		}

		room, load_error := tilemap.load_room_file_json5(
			file.fullpath,
			resource_root,
			allocator,
		)
		if load_error.kind != .none {
			err = room_registry_error(.room_load_failed, load_error.message)
			tilemap.destroy_room_file_io_error(&load_error, allocator)
			destroy_room_registry(&registry, allocator)
			return {}, err
		}
		tilemap.destroy_room_file_io_error(&load_error, allocator)

		filename_id, _ := os.split_filename(file.name)
		if filename_id != room.id {
			err = room_registry_error(
				.room_id_mismatch,
				fmt.tprintf(
					"%s: room id %q must match filename %q",
					file.fullpath,
					room.id,
					filename_id,
				),
			)
			tilemap.destroy_room_file(&room, allocator)
			destroy_room_registry(&registry, allocator)
			return {}, err
		}

		for existing in registry.entries {
			if existing.id == room.id {
				err = room_registry_error(
					.duplicate_room_id,
					fmt.tprintf(
						"%s: room id %q is already registered by %s",
						file.fullpath,
						room.id,
						existing.path,
					),
				)
				tilemap.destroy_room_file(&room, allocator)
				destroy_room_registry(&registry, allocator)
				return {}, err
			}
		}

		append(
			&registry.entries,
			Room_Registry_Entry {
				id = strings.clone(room.id, allocator),
				name = strings.clone(room.name, allocator),
				path = strings.clone(file.fullpath, allocator),
			},
		)
		tilemap.destroy_room_file(&room, allocator)
	}

	if len(registry.entries) == 0 {
		destroy_room_registry(&registry, allocator)
		return {}, room_registry_error(
			.no_rooms_found,
			fmt.tprintf("%s: no %s room files found", directory, tilemap.ROOM_FILE_EXTENSION),
		)
	}

	slice.sort_by(
		registry.entries[:],
		proc(a, b: Room_Registry_Entry) -> bool {return a.id < b.id},
	)
	return
}

room_registry_find :: proc(
	registry: ^Room_Registry,
	room_id: string,
) -> (^Room_Registry_Entry, bool) {
	if registry == nil do return nil, false
	for &entry in registry.entries {
		if entry.id == room_id do return &entry, true
	}
	return nil, false
}

destroy_room_registry :: proc(
	registry: ^Room_Registry,
	allocator := context.allocator,
) {
	if registry == nil do return
	for entry in registry.entries {
		delete(entry.id, allocator)
		delete(entry.name, allocator)
		delete(entry.path, allocator)
	}
	delete(registry.entries)
	registry^ = {}
}

destroy_room_registry_error :: proc(
	err: ^Room_Registry_Error,
	allocator := context.allocator,
) {
	if err == nil do return
	delete(err.message, allocator)
	err^ = {}
}
