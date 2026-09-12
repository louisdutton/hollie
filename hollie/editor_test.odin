package hollie

import "core:strings"
import "core:testing"
import "tilemap"

@(test)
test_editor_can_be_reset_and_reentered_repeatedly :: proc(t: ^testing.T) {
	state: Editor_State
	defer editor_reset(&state)
	hovered: tilemap.Entity_Data
	for session in 0 ..< 3 {
		editor_reset(&state)
		testing.expect_value(t, state.mode, Editor_Mode.Disabled)
		testing.expect_value(t, state.selected_tile, tilemap.Tile_Type.Grass_1)
		testing.expect_value(t, state.selected_entity, tilemap.Entity_Type.Enemy)
		testing.expect(t, state.show_grid && state.show_hud && state.cursor_visible)
		state.mode = .Editing
		state.is_editing_entity = true
		state.hovered_entity = &hovered
		state.is_painting = true
		state.selected_layer = .Entity
		state.cursor_x = 7
		append(&state.pre_edit_players, Vec2{20, 30})
		state.save_message = strings.clone("Room saved")
		state.save_message_timer = 4
		editor_reset(&state)
		testing.expect(t, state.pre_edit_players == nil && cap(state.pre_edit_players) == 0)
		testing.expect_value(t, state.save_message, "")
		testing.expect(t, state.hovered_entity == nil)
		testing.expect(t, !state.is_editing_entity && !state.is_painting)
		testing.expect_value(t, state.selected_layer, Editor_Layer.Base)
		testing.expect_value(t, state.cursor_x, 0)
		testing.expect_value(t, state.save_message_timer, f32(0))
		// Teardown is safe even when invoked twice before the next entry.
		editor_reset(&state)
	}
}
