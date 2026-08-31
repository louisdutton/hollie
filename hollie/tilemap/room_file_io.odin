package tilemap

import "core:fmt"
import "core:os"
import "core:strings"

ROOM_FILE_RESOURCE_DIRECTORY :: "maps"
ROOM_FILE_EXTENSION :: ".json"

Room_File_IO_Error_Kind :: enum {
	none,
	invalid_extension,
	read_failed,
	decode_failed,
	validation_failed,
	conversion_failed,
	encode_failed,
	create_temp_failed,
	write_failed,
	sync_failed,
	close_failed,
	replace_failed,
}

Room_File_IO_Error :: struct {
	kind:         Room_File_IO_Error_Kind,
	entity_index: int,
	message:      string,
}

room_file_path_has_canonical_extension :: proc(path: string) -> bool {
	return strings.has_suffix(path, ROOM_FILE_EXTENSION)
}

room_file_io_error :: proc(
	kind: Room_File_IO_Error_Kind,
	path, reason: string,
	entity_index := -1,
) -> Room_File_IO_Error {
	return {
		kind = kind,
		entity_index = entity_index,
		message = fmt.aprintf("%s: %s", path, reason),
	}
}

room_file_validation_error :: proc(
	path: string,
	errors: []Validation_Error,
) -> Room_File_IO_Error {
	assert(len(errors) > 0)
	first := errors[0]
	remainder := len(errors) - 1
	reason := first.message

	if first.entity_index >= 0 {
		if remainder > 0 {
			reason = fmt.tprintf(
				"entity %d: %s (+%d more validation errors)",
				first.entity_index + 1,
				first.message,
				remainder,
			)
		} else {
			reason = fmt.tprintf("entity %d: %s", first.entity_index + 1, first.message)
		}
	} else if remainder > 0 {
		reason = fmt.tprintf("%s (+%d more validation errors)", first.message, remainder)
	}
	return room_file_io_error(.validation_failed, path, reason, first.entity_index)
}

load_room_file_json5 :: proc(
	path: string,
	resource_root := "",
	allocator := context.allocator,
) -> (
	room: Room_File,
	err: Room_File_IO_Error,
) {
	context.allocator = allocator
	if !room_file_path_has_canonical_extension(path) {
		return {}, room_file_io_error(.invalid_extension, path, fmt.tprintf("room filenames must end in %s", ROOM_FILE_EXTENSION))
	}

	data, read_error := os.read_entire_file(path, allocator)
	if read_error != nil {
		return {}, room_file_io_error(.read_failed, path, fmt.tprintf("could not read room file: %v", read_error))
	}
	defer delete(data, allocator)

	decode_error: Room_File_Decode_Error
	room, decode_error = decode_room_file_json5(string(data), allocator)
	if decode_error.kind != .none {
		err = room_file_io_error(
			.decode_failed,
			path,
			decode_error.message,
			decode_error.entity_index,
		)
		destroy_room_file_decode_error(&decode_error, allocator)
		return {}, err
	}

	validation_errors := validate_room_file(&room, resource_root)
	defer destroy_validation_errors(&validation_errors)
	if len(validation_errors) > 0 {
		err = room_file_validation_error(path, validation_errors[:])
		destroy_room_file(&room, allocator)
		return {}, err
	}
	return
}

load_tilemap_file :: proc(
	path: string,
	resource_root := "",
	allocator := context.allocator,
) -> (
	tm: TileMap,
	err: Room_File_IO_Error,
) {
	context.allocator = allocator
	room: Room_File
	room, err = load_room_file_json5(path, resource_root, allocator)
	if err.kind != .none do return
	defer destroy_room_file(&room, allocator)

	validation_errors: [dynamic]Validation_Error
	tm, validation_errors = room_file_to_tilemap(room, resource_root, allocator)
	defer destroy_validation_errors(&validation_errors)
	if len(validation_errors) > 0 {
		err = room_file_validation_error(path, validation_errors[:])
	}
	return
}

save_room_file_json5_atomic :: proc(
	path: string,
	room: ^Room_File,
	resource_root := "",
	allocator := context.allocator,
) -> Room_File_IO_Error {
	context.allocator = allocator
	if !room_file_path_has_canonical_extension(path) {
		return room_file_io_error(
			.invalid_extension,
			path,
			fmt.tprintf("room filenames must end in %s", ROOM_FILE_EXTENSION),
		)
	}

	validation_errors := validate_room_file(room, resource_root)
	defer destroy_validation_errors(&validation_errors)
	if len(validation_errors) > 0 {
		return room_file_validation_error(path, validation_errors[:])
	}

	data, encode_error := encode_room_file_json5(room^, allocator)
	if encode_error.kind != .none {
		if encode_error.entity_index >= 0 {
			return room_file_io_error(
				.encode_failed,
				path,
				fmt.tprintf("entity %d could not be encoded", encode_error.entity_index + 1),
				encode_error.entity_index,
			)
		}
		return room_file_io_error(.encode_failed, path, "room could not be encoded")
	}
	defer delete(data, allocator)

	temp_pattern := fmt.aprintf(".%s.*.tmp", os.base(path))
	defer delete(temp_pattern)
	temp_file, create_error := os.create_temp_file(os.dir(path), temp_pattern)
	if create_error != nil {
		return room_file_io_error(
			.create_temp_failed,
			path,
			fmt.tprintf("could not create a temporary room file: %v", create_error),
		)
	}

	temp_path := strings.clone(os.name(temp_file), allocator)
	defer delete(temp_path, allocator)
	temp_exists := true
	defer if temp_exists do _ = os.remove(temp_path)

	written, write_error := os.write(temp_file, data)
	if write_error != nil || written != len(data) {
		_ = os.close(temp_file)
		return room_file_io_error(
			.write_failed,
			path,
			fmt.tprintf("could not write the temporary room file: %v", write_error),
		)
	}

	if sync_error := os.sync(temp_file); sync_error != nil {
		_ = os.close(temp_file)
		return room_file_io_error(
			.sync_failed,
			path,
			fmt.tprintf("could not sync the temporary room file: %v", sync_error),
		)
	}

	if close_error := os.close(temp_file); close_error != nil {
		return room_file_io_error(
			.close_failed,
			path,
			fmt.tprintf("could not close the temporary room file: %v", close_error),
		)
	}

	if replace_error := os.rename(temp_path, path); replace_error != nil {
		return room_file_io_error(
			.replace_failed,
			path,
			fmt.tprintf("could not replace the room file: %v", replace_error),
		)
	}
	temp_exists = false
	return {}
}

save_tilemap_file_atomic :: proc(
	path: string,
	tm: ^TileMap,
	resource_root := "",
	allocator := context.allocator,
) -> Room_File_IO_Error {
	context.allocator = allocator
	room, conversion_error := tilemap_to_room_file(tm^, allocator)
	if conversion_error.kind != .none {
		return room_file_io_error(
			.conversion_failed,
			path,
			fmt.tprintf(
				"entity %d has an unsupported runtime type",
				conversion_error.entity_index + 1,
			),
			conversion_error.entity_index,
		)
	}
	defer destroy_room_file(&room, allocator)
	return save_room_file_json5_atomic(path, &room, resource_root, allocator)
}

destroy_room_file_io_error :: proc(err: ^Room_File_IO_Error, allocator := context.allocator) {
	if err == nil do return
	delete(err.message, allocator)
	err^ = {}
}
