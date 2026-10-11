package input

import "core:testing"

@(test)
face_buttons_follow_controller_layout :: proc(t: ^testing.T) {
	cases := []struct {
		action:   Action,
		xbox:     Gamepad_Button,
		nintendo: Gamepad_Button,
	} {
		{.Menu_Confirm, .RIGHT_FACE_DOWN, .RIGHT_FACE_RIGHT},
		{.Menu_Back, .RIGHT_FACE_RIGHT, .RIGHT_FACE_DOWN},
		{.Game_Jump, .RIGHT_FACE_DOWN, .RIGHT_FACE_RIGHT},
		{.Game_Interact, .RIGHT_FACE_LEFT, .RIGHT_FACE_UP},
		{.Editor_Paint, .RIGHT_FACE_DOWN, .RIGHT_FACE_RIGHT},
		{.Editor_Erase, .RIGHT_FACE_RIGHT, .RIGHT_FACE_DOWN},
		{.Editor_Change_Layer, .RIGHT_FACE_UP, .RIGHT_FACE_LEFT},
		{.Editor_Edit_Entity, .RIGHT_FACE_LEFT, .RIGHT_FACE_UP},
		{.Editor_Value_Previous, .RIGHT_FACE_RIGHT, .RIGHT_FACE_DOWN},
		{.Editor_Value_Next, .RIGHT_FACE_DOWN, .RIGHT_FACE_RIGHT},
		{.Editor_Value_Toggle, .RIGHT_FACE_UP, .RIGHT_FACE_LEFT},
	}
	for player in Player_Index {
		for layout in Gamepad_Layout {
			for item in cases {
				binding := action_binding_for_layout(item.action, layout, player)
				expected := layout == .Nintendo ? item.nintendo : item.xbox
				testing.expect_value(t, binding.gamepad_button, expected)
			}
		}
	}
}

@(test)
keyboard_and_other_buttons_are_preserved :: proc(t: ^testing.T) {
	for layout in Gamepad_Layout {
		for action in Action {
			binding := action_binding_for_layout(action, layout)
			original := action_bindings[action]
			if action != .Game_Jump && action != .Game_Interact {
				testing.expect_value(t, binding.key, original.key)
			}
			testing.expect_value(t, binding.key_modifier, original.key_modifier)
			#partial switch original.gamepad_button {
			case .RIGHT_FACE_DOWN, .RIGHT_FACE_RIGHT, .RIGHT_FACE_LEFT, .RIGHT_FACE_UP:
			case: testing.expect_value(t, binding.gamepad_button, original.gamepad_button)
			}
		}
		testing.expect_value(t, action_binding_for_layout(.Game_Jump, layout).key, settings.jump)
		testing.expect_value(
			t,
			action_binding_for_layout(.Game_Interact, layout).key,
			settings.interact,
		)
		testing.expect_value(
			t,
			action_binding_for_layout(.Game_Jump, layout, .Player_2).key,
			Key.SEMICOLON,
		)
		testing.expect_value(
			t,
			action_binding_for_layout(.Game_Interact, layout, .Player_2).key,
			Key.L,
		)
	}
}
