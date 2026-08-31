package tilemap

import "core:fmt"
import "core:os"
import "core:strings"
import "core:testing"

@(test)
test_room_file_io_validates_and_replaces_atomically :: proc(t: ^testing.T) {
	room, decode_error := decode_room_file_json5(ROOM_FILE_CONTRACT_TEST_JSON5)
	testing.expect_value(t, decode_error.kind, Room_File_Decode_Error_Kind.none)
	if decode_error.kind != .none do return
	defer destroy_room_file(&room)

	temp_directory, temp_error := os.make_directory_temp(
		"",
		"hollie-room-file-io-*",
		context.allocator,
	)
	testing.expect(t, temp_error == nil, "a temporary test directory should be created")
	if temp_error != nil do return
	defer delete(temp_directory)

	path := fmt.aprintf("%s/roundtrip%s", temp_directory, ROOM_FILE_EXTENSION)
	defer delete(path)
	defer {
		_ = os.remove(path)
		_ = os.remove(temp_directory)
	}

	testing.expect(t, room_file_path_has_canonical_extension(path))
	testing.expect(t, !room_file_path_has_canonical_extension("roundtrip.room.json5"))

	save_error := save_room_file_json5_atomic(path, &room)
	defer destroy_room_file_io_error(&save_error)
	testing.expect_value(t, save_error.kind, Room_File_IO_Error_Kind.none)
	if save_error.kind != .none do return

	loaded, load_error := load_room_file_json5(path)
	defer destroy_room_file_io_error(&load_error)
	testing.expect_value(t, load_error.kind, Room_File_IO_Error_Kind.none)
	if load_error.kind != .none do return
	defer destroy_room_file(&loaded)
	expect_room_file_contract(t, loaded)

	before, before_error := os.read_entire_file(path, context.allocator)
	testing.expect(t, before_error == nil, "the saved room should be readable")
	if before_error != nil do return
	defer delete(before)

	room.size.width = 0
	invalid_save_error := save_room_file_json5_atomic(path, &room)
	defer destroy_room_file_io_error(&invalid_save_error)
	testing.expect_value(t, invalid_save_error.kind, Room_File_IO_Error_Kind.validation_failed)
	testing.expect(
		t,
		strings.contains(invalid_save_error.message, path),
		"save diagnostics should include the target path",
	)

	after, after_error := os.read_entire_file(path, context.allocator)
	testing.expect(t, after_error == nil, "a rejected save should preserve the previous file")
	if after_error == nil {
		defer delete(after)
		testing.expect_value(t, string(after), string(before))
	}

	malformed_write_error := os.write_entire_file(path, "{")
	testing.expect(t, malformed_write_error == nil, "the malformed test fixture should be written")
	if malformed_write_error != nil do return

	_, malformed_load_error := load_room_file_json5(path)
	defer destroy_room_file_io_error(&malformed_load_error)
	testing.expect_value(t, malformed_load_error.kind, Room_File_IO_Error_Kind.decode_failed)
	testing.expect(
		t,
		strings.contains(malformed_load_error.message, path),
		"load diagnostics should include the source path",
	)
}
