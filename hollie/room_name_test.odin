package hollie

import "core:testing"

@(test)
test_room_name_atlas_matches_display_resolution :: proc(t: ^testing.T) {
	testing.expect_value(t, room_name_atlas_size(1), i32(64))
	testing.expect_value(t, room_name_atlas_size(2.4), i32(101))
	testing.expect_value(t, room_name_atlas_size(4.8), i32(202))
}
