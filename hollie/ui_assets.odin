package hollie

import "asset"
import "input"
import "renderer"
import rl "vendor:raylib"

UI_Key_Prompt :: enum {
	Arrows,
	Arrows_Horizontal,
	A,
	D,
	E,
	G,
	P,
	R,
	S,
	W,
	Control,
	Enter,
	Escape,
	F1,
	Left,
	Right,
	Shift,
	Space,
	Tab,
	Backspace,
}

UI_Gamepad_Prompt :: enum {
	Face_Up,
	Face_Right,
	Face_Down,
	Face_Left,
	Left_Bumper,
	Left_Trigger,
	Right_Bumper,
	Right_Trigger,
	Middle_Left,
	Middle_Right,
	Left_Stick_Click,
	Right_Stick_Click,
	Left_Stick,
	Right_Stick,
	Dpad_Horizontal,
}

UI_Frame_Style :: enum {
	Panel_Surface,
	Panel_Outline,
	Action_Bar,
	Focus_Outline,
	Focus_Fill,
}

UI_Prompt_View :: struct {
	textures: [4]renderer.Texture2D,
	count:    int,
}

UI_Assets :: struct {
	frames:          [UI_Frame_Style]renderer.Texture2D,
	key_prompts:     [UI_Key_Prompt]renderer.Texture2D,
	gamepad_prompts: [input.Gamepad_Layout][UI_Gamepad_Prompt]renderer.Texture2D,
}

@(private)
ui_assets: UI_Assets

ui_assets_init :: proc() {
	for style_index in 0 ..< len(ui_assets.frames) {
		style := UI_Frame_Style(style_index)
		texture := renderer.load_texture(asset.path(ui_frame_path(style)))
		rl.SetTextureFilter(texture, .BILINEAR)
		ui_assets.frames[style] = texture
	}

	for prompt_index in 0 ..< len(ui_assets.key_prompts) {
		prompt := UI_Key_Prompt(prompt_index)
		texture := renderer.load_texture(asset.path(ui_key_prompt_path(prompt)))
		rl.GenTextureMipmaps(&texture)
		rl.SetTextureFilter(texture, .TRILINEAR)
		ui_assets.key_prompts[prompt] = texture
	}

	for layout_index in 0 ..< len(ui_assets.gamepad_prompts) {
		layout := input.Gamepad_Layout(layout_index)
		for prompt_index in 0 ..< len(ui_assets.gamepad_prompts[layout]) {
			prompt := UI_Gamepad_Prompt(prompt_index)
			texture := renderer.load_texture(asset.path(ui_gamepad_prompt_path(layout, prompt)))
			rl.GenTextureMipmaps(&texture)
			rl.SetTextureFilter(texture, .TRILINEAR)
			ui_assets.gamepad_prompts[layout][prompt] = texture
		}
	}
}

ui_assets_fini :: proc() {
	for texture in ui_assets.frames do renderer.unload_texture(texture)
	for texture in ui_assets.key_prompts do renderer.unload_texture(texture)
	for prompts in ui_assets.gamepad_prompts {
		for texture in prompts do renderer.unload_texture(texture)
	}
	ui_assets = {}
}

ui_draw_frame :: proc(style: UI_Frame_Style, bounds: renderer.Rect, tint := renderer.WHITE) {
	texture := ui_assets.frames[style]
	patch := rl.NPatchInfo {
		source = {0, 0, f32(texture.width), f32(texture.height)},
		left   = 16,
		top    = 16,
		right  = 16,
		bottom = 16,
		layout = .NINE_PATCH,
	}
	rl.DrawTextureNPatch(texture, patch, bounds, {}, 0, tint)
}

@(private)
ui_frame_path :: proc(style: UI_Frame_Style) -> string {
	root :: "art/ui/kenney/fantasy-ui-borders/PNG/Default/"
	switch style {
	case .Panel_Surface: return root + "Panel/panel-000.png"
	case .Panel_Outline: return root + "Border/panel-border-000.png"
	case .Action_Bar: return root + "Border/panel-border-005.png"
	case .Focus_Outline: return root + "Border/panel-border-008.png"
	case .Focus_Fill: return root + "Panel/panel-008.png"
	}
	return ""
}

ui_action_prompt_view :: proc(action: input.Action) -> UI_Prompt_View {
	binding := input.action_binding(action)
	if input.active_device() == .Gamepad && input.is_gamepad_available(.PLAYER_1) {
		layout := input.active_gamepad_layout()
		view := UI_Prompt_View{}
		#partial switch action {
		case .Menu_Navigate:
			view.textures[0] = ui_assets.gamepad_prompts[layout][.Left_Stick]
			view.textures[1] = ui_assets.gamepad_prompts[layout][.Dpad_Horizontal]
			view.count = 2
			return view
		case .Menu_Adjust:
			view.textures[0] = ui_assets.gamepad_prompts[layout][.Dpad_Horizontal]
			view.count = 1
			return view
		case .Editor_Move_Cursor:
			view.textures[0] = ui_assets.gamepad_prompts[layout][.Left_Stick]
			view.count = 1
			return view
		case .Editor_Move_Camera:
			view.textures[0] = ui_assets.gamepad_prompts[layout][.Right_Stick]
			view.count = 1
			return view
		case:
		}

		prompt, found := ui_gamepad_prompt_for_button(binding.gamepad_button)
		if !found do return {}
		view.textures[0] = ui_assets.gamepad_prompts[layout][prompt]
		view.count = 1
		return view
	}

	view := UI_Prompt_View{}
	#partial switch action {
	case .Menu_Navigate:
		view.textures[0] = ui_assets.key_prompts[.Arrows]
		view.count = 1
		return view
	case .Menu_Adjust:
		view.textures[0] = ui_assets.key_prompts[.Arrows_Horizontal]
		view.count = 1
		return view
	case .Editor_Move_Camera:
		view.textures[0] = ui_assets.key_prompts[.W]
		view.textures[1] = ui_assets.key_prompts[.A]
		view.textures[2] = ui_assets.key_prompts[.S]
		view.textures[3] = ui_assets.key_prompts[.D]
		view.count = 4
		return view
	case:
	}

	if binding.key == .KEY_NULL do return {}
	if binding.key_modifier == .Control {
		view.textures[0] = ui_assets.key_prompts[.Control]
		view.count = 1
		if prompt, found := ui_key_prompt_for_key(binding.key); found {
			view.textures[1] = ui_assets.key_prompts[prompt]
			view.count = 2
		}
		return view
	}

	prompt, found := ui_key_prompt_for_key(binding.key)
	if !found do return {}
	view.textures[0] = ui_assets.key_prompts[prompt]
	view.count = 1
	return view
}

ui_key_prompt_view :: proc(key: input.Key) -> UI_Prompt_View {
	prompt, found := ui_key_prompt_for_key(key)
	if !found do return {}
	view := UI_Prompt_View {
		count = 1,
	}
	view.textures[0] = ui_assets.key_prompts[prompt]
	return view
}

ui_prompt_view_width :: proc(view: UI_Prompt_View, size: f32 = 18, gap: f32 = 2) -> f32 {
	if view.count == 0 do return 0
	return f32(view.count) * size + f32(view.count - 1) * gap
}

ui_draw_prompt_view :: proc(view: UI_Prompt_View, x, y: f32, size: f32 = 18, gap: f32 = 2) {
	for index in 0 ..< view.count {
		texture := view.textures[index]
		destination := renderer.Rect{x + f32(index) * (size + gap), y, size, size}
		renderer.draw_texture_pro(
			texture,
			{0, 0, f32(texture.width), f32(texture.height)},
			destination,
			{},
			0,
			renderer.WHITE,
		)
	}
}

@(private)
ui_key_prompt_for_key :: proc(key: input.Key) -> (UI_Key_Prompt, bool) {
	#partial switch key {
	case .A: return .A, true
	case .D: return .D, true
	case .E: return .E, true
	case .G: return .G, true
	case .P: return .P, true
	case .R: return .R, true
	case .S: return .S, true
	case .W: return .W, true
	case .ENTER: return .Enter, true
	case .ESCAPE: return .Escape, true
	case .F1: return .F1, true
	case .LEFT: return .Left, true
	case .RIGHT: return .Right, true
	case .LEFT_SHIFT, .RIGHT_SHIFT: return .Shift, true
	case .SPACE: return .Space, true
	case .TAB: return .Tab, true
	case .BACKSPACE: return .Backspace, true
	case:
	}
	return {}, false
}

@(private)
ui_gamepad_prompt_for_button :: proc(button: input.Gamepad_Button) -> (UI_Gamepad_Prompt, bool) {
	#partial switch button {
	case .RIGHT_FACE_UP: return .Face_Up, true
	case .RIGHT_FACE_RIGHT: return .Face_Right, true
	case .RIGHT_FACE_DOWN: return .Face_Down, true
	case .RIGHT_FACE_LEFT: return .Face_Left, true
	case .LEFT_TRIGGER_1: return .Left_Bumper, true
	case .LEFT_TRIGGER_2: return .Left_Trigger, true
	case .RIGHT_TRIGGER_1: return .Right_Bumper, true
	case .RIGHT_TRIGGER_2: return .Right_Trigger, true
	case .MIDDLE_LEFT: return .Middle_Left, true
	case .MIDDLE_RIGHT: return .Middle_Right, true
	case .LEFT_THUMB: return .Left_Stick_Click, true
	case .RIGHT_THUMB: return .Right_Stick_Click, true
	case:
	}
	return {}, false
}

@(private)
ui_key_prompt_path :: proc(prompt: UI_Key_Prompt) -> string {
	root :: "art/ui/kenney/input-prompts/Keyboard & Mouse/Default/"
	switch prompt {
	case .Arrows: return root + "keyboard_arrows.png"
	case .Arrows_Horizontal: return root + "keyboard_arrows_horizontal.png"
	case .A: return root + "keyboard_a.png"
	case .D: return root + "keyboard_d.png"
	case .E: return root + "keyboard_e.png"
	case .G: return root + "keyboard_g.png"
	case .P: return root + "keyboard_p.png"
	case .R: return root + "keyboard_r.png"
	case .S: return root + "keyboard_s.png"
	case .W: return root + "keyboard_w.png"
	case .Control: return root + "keyboard_ctrl.png"
	case .Enter: return root + "keyboard_enter.png"
	case .Escape: return root + "keyboard_escape.png"
	case .F1: return root + "keyboard_f1.png"
	case .Left: return root + "keyboard_arrow_left.png"
	case .Right: return root + "keyboard_arrow_right.png"
	case .Shift: return root + "keyboard_shift.png"
	case .Space: return root + "keyboard_space.png"
	case .Tab: return root + "keyboard_tab.png"
	case .Backspace: return root + "keyboard_backspace.png"
	}
	return ""
}

@(private)
ui_gamepad_prompt_path :: proc(layout: input.Gamepad_Layout, prompt: UI_Gamepad_Prompt) -> string {
	switch layout {
	case .Xbox:
		root :: "art/ui/kenney/input-prompts/Xbox Series/Default/"
		switch prompt {
		case .Face_Up: return root + "xbox_button_y.png"
		case .Face_Right: return root + "xbox_button_b.png"
		case .Face_Down: return root + "xbox_button_a.png"
		case .Face_Left: return root + "xbox_button_x.png"
		case .Left_Bumper: return root + "xbox_lb.png"
		case .Left_Trigger: return root + "xbox_lt.png"
		case .Right_Bumper: return root + "xbox_rb.png"
		case .Right_Trigger: return root + "xbox_rt.png"
		case .Middle_Left: return root + "xbox_button_view.png"
		case .Middle_Right: return root + "xbox_button_menu.png"
		case .Left_Stick_Click: return root + "xbox_ls.png"
		case .Right_Stick_Click: return root + "xbox_rs.png"
		case .Left_Stick: return root + "xbox_stick_l.png"
		case .Right_Stick: return root + "xbox_stick_r.png"
		case .Dpad_Horizontal: return root + "xbox_dpad_horizontal.png"
		}
	case .Playstation:
		root :: "art/ui/kenney/input-prompts/PlayStation Series/Default/"
		switch prompt {
		case .Face_Up: return root + "playstation_button_triangle.png"
		case .Face_Right: return root + "playstation_button_circle.png"
		case .Face_Down: return root + "playstation_button_cross.png"
		case .Face_Left: return root + "playstation_button_square.png"
		case .Left_Bumper: return root + "playstation_trigger_l1.png"
		case .Left_Trigger: return root + "playstation_trigger_l2.png"
		case .Right_Bumper: return root + "playstation_trigger_r1.png"
		case .Right_Trigger: return root + "playstation_trigger_r2.png"
		case .Middle_Left: return root + "playstation5_button_create.png"
		case .Middle_Right: return root + "playstation5_button_options.png"
		case .Left_Stick_Click: return root + "playstation_button_l3.png"
		case .Right_Stick_Click: return root + "playstation_button_r3.png"
		case .Left_Stick: return root + "playstation_stick_l.png"
		case .Right_Stick: return root + "playstation_stick_r.png"
		case .Dpad_Horizontal: return root + "playstation_dpad_horizontal.png"
		}
	case .Nintendo:
		root :: "art/ui/kenney/input-prompts/Nintendo Switch/Default/"
		switch prompt {
		case .Face_Up: return root + "switch_button_x.png"
		case .Face_Right: return root + "switch_button_a.png"
		case .Face_Down: return root + "switch_button_b.png"
		case .Face_Left: return root + "switch_button_y.png"
		case .Left_Bumper: return root + "switch_button_l.png"
		case .Left_Trigger: return root + "switch_button_zl.png"
		case .Right_Bumper: return root + "switch_button_r.png"
		case .Right_Trigger: return root + "switch_button_zr.png"
		case .Middle_Left: return root + "switch_button_minus.png"
		case .Middle_Right: return root + "switch_button_plus.png"
		case .Left_Stick_Click: return root + "switch_stick_l_press.png"
		case .Right_Stick_Click: return root + "switch_stick_r_press.png"
		case .Left_Stick: return root + "switch_stick_l.png"
		case .Right_Stick: return root + "switch_stick_r.png"
		case .Dpad_Horizontal: return root + "switch_dpad_horizontal.png"
		}
	}
	return ""
}
