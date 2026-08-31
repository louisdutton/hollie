package tilemap

import json "core:encoding/json"

Room_File_Size :: struct {
	width:  int,
	height: int,
}

Room_File_Bounds :: struct {
	x:      f32,
	y:      f32,
	width:  f32,
	height: f32,
}

Room_File_Tileset :: struct {
	path:      string,
	tile_size: int,
	columns:   int,
}

Room_File_Layers :: struct {
	base:       []u16,
	decoration: []u16,
}

Room_File :: struct {
	id:               string,
	name:             string,
	music_path:       string `json:"music_path,omitempty"`,
	size:             Room_File_Size,
	tileset:          Room_File_Tileset,
	camera_bounds:    Room_File_Bounds,
	collision_bounds: Room_File_Bounds,
	layers:           Room_File_Layers,
}

room_file_json5_options :: proc() -> json.Marshal_Options {
	return {
		spec = .JSON5,
		pretty = true,
		use_spaces = true,
		spaces = 2,
		sort_maps_by_key = true,
		use_enum_names = true,
	}
}

decode_room_file_json5 :: proc(
	content: string,
	allocator := context.allocator,
) -> (
	room: Room_File,
	err: json.Unmarshal_Error,
) {
	err = json.unmarshal_string(content, &room, .JSON5, allocator)
	if err != nil {
		destroy_room_file(&room, allocator)
	}
	return
}

encode_room_file_json5 :: proc(
	room: Room_File,
	allocator := context.allocator,
) -> (
	data: []byte,
	err: json.Marshal_Error,
) {
	return json.marshal(room, room_file_json5_options(), allocator)
}

destroy_room_file :: proc(room: ^Room_File, allocator := context.allocator) {
	if room == nil do return

	delete(room.id, allocator)
	delete(room.name, allocator)
	delete(room.music_path, allocator)
	delete(room.tileset.path, allocator)
	delete(room.layers.base, allocator)
	delete(room.layers.decoration, allocator)
	room^ = {}
}
