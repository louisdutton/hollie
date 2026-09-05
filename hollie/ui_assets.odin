package hollie

import "asset"
import "input"
import "renderer"
import rl "vendor:raylib"
import "window"

UI_ASSET_ROOT :: "ui/"

UI_KEY_PROMPT_PATHS :: [UI_Key_Prompt]string {
	.Arrows            = "ui/input/keyboard-arrows.png",
	.Arrows_Horizontal = "ui/input/keyboard-arrows-horizontal.png",
	.A                 = "ui/input/keyboard-a.png",
	.D                 = "ui/input/keyboard-d.png",
	.E                 = "ui/input/keyboard-e.png",
	.G                 = "ui/input/keyboard-g.png",
	.H                 = "ui/input/keyboard-h.png",
	.P                 = "ui/input/keyboard-p.png",
	.R                 = "ui/input/keyboard-r.png",
	.S                 = "ui/input/keyboard-s.png",
	.W                 = "ui/input/keyboard-w.png",
	.Control           = "ui/input/keyboard-ctrl.png",
	.Enter             = "ui/input/keyboard-enter.png",
	.Escape            = "ui/input/keyboard-escape.png",
	.F1                = "ui/input/keyboard-f1.png",
	.Left              = "ui/input/keyboard-arrow-left.png",
	.Right             = "ui/input/keyboard-arrow-right.png",
	.Shift             = "ui/input/keyboard-shift.png",
	.Space             = "ui/input/keyboard-space.png",
	.Tab               = "ui/input/keyboard-tab.png",
	.Backspace         = "ui/input/keyboard-backspace.png",
}

UI_GAMEPAD_PROMPT_PATHS :: [input.Gamepad_Layout][UI_Gamepad_Prompt]string {
	.Xbox = {
		.Face_Up = "ui/input/xbox-button-y.png", .Face_Right = "ui/input/xbox-button-b.png", .Face_Down = "ui/input/xbox-button-a.png", .Face_Left = "ui/input/xbox-button-x.png",
		.Left_Bumper = "ui/input/xbox-lb.png", .Left_Trigger = "ui/input/xbox-lt.png", .Right_Bumper = "ui/input/xbox-rb.png", .Right_Trigger = "ui/input/xbox-rt.png",
		.Middle_Left = "ui/input/xbox-button-view.png", .Middle_Right = "ui/input/xbox-button-menu.png",
		.Left_Stick_Click = "ui/input/xbox-ls.png", .Right_Stick_Click = "ui/input/xbox-rs.png", .Left_Stick = "ui/input/xbox-stick-l.png", .Right_Stick = "ui/input/xbox-stick-r.png", .Dpad_Horizontal = "ui/input/xbox-dpad-horizontal.png",
	},
	.Playstation = {
		.Face_Up = "ui/input/playstation-button-triangle.png", .Face_Right = "ui/input/playstation-button-circle.png", .Face_Down = "ui/input/playstation-button-cross.png", .Face_Left = "ui/input/playstation-button-square.png",
		.Left_Bumper = "ui/input/playstation-trigger-l1.png", .Left_Trigger = "ui/input/playstation-trigger-l2.png", .Right_Bumper = "ui/input/playstation-trigger-r1.png", .Right_Trigger = "ui/input/playstation-trigger-r2.png",
		.Middle_Left = "ui/input/playstation5-button-create.png", .Middle_Right = "ui/input/playstation5-button-options.png",
		.Left_Stick_Click = "ui/input/playstation-button-l3.png", .Right_Stick_Click = "ui/input/playstation-button-r3.png", .Left_Stick = "ui/input/playstation-stick-l.png", .Right_Stick = "ui/input/playstation-stick-r.png", .Dpad_Horizontal = "ui/input/playstation-dpad-horizontal.png",
	},
	.Nintendo = {
		.Face_Up = "ui/input/switch-button-x.png", .Face_Right = "ui/input/switch-button-a.png", .Face_Down = "ui/input/switch-button-b.png", .Face_Left = "ui/input/switch-button-y.png",
		.Left_Bumper = "ui/input/switch-button-l.png", .Left_Trigger = "ui/input/switch-button-zl.png", .Right_Bumper = "ui/input/switch-button-r.png", .Right_Trigger = "ui/input/switch-button-zr.png",
		.Middle_Left = "ui/input/switch-button-minus.png", .Middle_Right = "ui/input/switch-button-plus.png",
		.Left_Stick_Click = "ui/input/switch-stick-l-press.png", .Right_Stick_Click = "ui/input/switch-stick-r-press.png", .Left_Stick = "ui/input/switch-stick-l.png", .Right_Stick = "ui/input/switch-stick-r.png", .Dpad_Horizontal = "ui/input/switch-dpad-horizontal.png",
	},
}

UI_Key_Prompt :: enum {
	Arrows,
	Arrows_Horizontal,
	A,
	D,
	E,
	G,
	H,
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
	Title_Backdrop,
	Focus_Outline,
	Focus_Fill,
}

UI_Prompt_View :: struct {
	textures: [4]renderer.Texture2D,
	count:    int,
}

UI_Assets :: struct {
	frames:          [UI_Frame_Style]renderer.Texture2D,
	title_divider:   renderer.Texture2D,
	horizontal_fade: rl.Shader,
	key_prompts:     [UI_Key_Prompt]renderer.Texture2D,
	gamepad_prompts: [input.Gamepad_Layout][UI_Gamepad_Prompt]renderer.Texture2D,
}

@(private)
ui_assets: UI_Assets

ui_assets_init :: proc() {
	for style_index in 0 ..< len(ui_assets.frames) {
		style := UI_Frame_Style(style_index)
		texture := renderer.load_texture(asset.path(ui_frame_path(style)))
		rl.SetTextureFilter(texture, .POINT)
		ui_assets.frames[style] = texture
	}
	ui_assets.title_divider = renderer.load_texture(
		asset.path(
			UI_ASSET_ROOT + "frame/divider-fade-005.png",
		),
	)
	rl.SetTextureFilter(ui_assets.title_divider, .POINT)
	ui_assets.horizontal_fade = rl.LoadShader(
		nil,
		cstring(raw_data(asset.path("shaders/ui_horizontal_fade.frag"))),
	)

	for prompt_index in 0 ..< len(ui_assets.key_prompts) {
		prompt := UI_Key_Prompt(prompt_index)
		texture := renderer.load_texture(asset.path(UI_KEY_PROMPT_PATHS[prompt]))
		rl.GenTextureMipmaps(&texture)
		rl.SetTextureFilter(texture, .TRILINEAR)
		ui_assets.key_prompts[prompt] = texture
	}

	for layout_index in 0 ..< len(ui_assets.gamepad_prompts) {
		layout := input.Gamepad_Layout(layout_index)
		for prompt_index in 0 ..< len(ui_assets.gamepad_prompts[layout]) {
			prompt := UI_Gamepad_Prompt(prompt_index)
			texture := renderer.load_texture(asset.path(UI_GAMEPAD_PROMPT_PATHS[layout][prompt]))
			rl.GenTextureMipmaps(&texture)
			rl.SetTextureFilter(texture, .TRILINEAR)
			ui_assets.gamepad_prompts[layout][prompt] = texture
		}
	}
}

ui_assets_fini :: proc() {
	for texture in ui_assets.frames do renderer.unload_texture(texture)
	renderer.unload_texture(ui_assets.title_divider)
	rl.UnloadShader(ui_assets.horizontal_fade)
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

ui_draw_horizontally_faded_frame :: proc(
	style: UI_Frame_Style,
	bounds: renderer.Rect,
	fade_width: f32,
	tint := renderer.WHITE,
) {
	scale := window.get_ui_scale()
	screen_bounds := [2]f32{bounds.x * scale, (bounds.x + bounds.width) * scale}
	screen_fade_width := fade_width * scale
	shader := ui_assets.horizontal_fade
	rl.SetShaderValue(shader, rl.GetShaderLocation(shader, "fadeBounds"), &screen_bounds[0], .VEC2)
	rl.SetShaderValue(
		shader,
		rl.GetShaderLocation(shader, "fadeWidth"),
		&screen_fade_width,
		.FLOAT,
	)
	rl.BeginShaderMode(shader)
	ui_draw_frame(style, bounds, tint)
	rl.EndShaderMode()
}

ui_draw_title_divider :: proc(bounds: renderer.Rect, mirrored: bool, tint := renderer.WHITE) {
	texture := ui_assets.title_divider
	source := renderer.Rect{0, 0, f32(texture.width), f32(texture.height)}
	if mirrored {
		source.width = -source.width
	}
	renderer.draw_texture_pro(texture, source, bounds, {}, 0, tint)
}

@(private)
ui_frame_path :: proc(style: UI_Frame_Style) -> string {
	root :: UI_ASSET_ROOT + "frame/"
	switch style {
	case .Panel_Surface: return root + "Panel/panel-000.png"
	case .Panel_Outline: return root + "Border/panel-border-000.png"
	case .Action_Bar: return root + "Border/panel-border-005.png"
	case .Title_Backdrop: return root + "Transparent center/panel-transparent-center-015.png"
	case .Focus_Outline: return root + "Border/panel-border-008.png"
	case .Focus_Fill: return root + "Panel/panel-008.png"
	}
	return ""
}

ui_action_prompt_view :: proc(action: input.Action) -> UI_Prompt_View {
	binding := input.action_binding(action)
	if input.active_device() == .Gamepad && input.is_gamepad_available(.Player_1) {
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

ui_control_prompt_view :: proc(
	key: input.Key,
	gamepad_button: input.Gamepad_Button,
) -> UI_Prompt_View {
	if input.active_device() == .Gamepad && input.is_gamepad_available(.Player_1) {
		prompt, found := ui_gamepad_prompt_for_button(gamepad_button)
		if !found do return {}
		view := UI_Prompt_View {
			count = 1,
		}
		view.textures[0] = ui_assets.gamepad_prompts[input.active_gamepad_layout()][prompt]
		return view
	}
	return ui_key_prompt_view(key)
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
	case .H: return .H, true
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

