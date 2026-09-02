package hollie

import "content"
import "core:fmt"
import "input"
import "renderer"
import "tilemap"
import "window"

EDITOR_ACTIONS := []input.Action {
	.Editor_Move_Cursor,
	.Editor_Paint,
	.Editor_Erase,
	.Editor_Change_Layer,
	.Editor_Select_Previous,
	.Editor_Select_Next,
	.Editor_Move_Camera,
	.Editor_Zoom_Out,
	.Editor_Zoom_In,
	.Editor_Edit_Entity,
	.Editor_Toggle_Grid,
	.Editor_Save,
	.Editor_Toggle,
}

EDITOR_EDIT_ACTIONS := []input.Action {
	.Editor_Move_Cursor,
	.Editor_Value_Previous,
	.Editor_Value_Next,
	.Editor_Value_Toggle,
	.Editor_Edit_Entity,
	.Editor_Save,
	.Editor_Toggle,
}

EDITOR_CAROUSEL_SLOT_COUNT :: 5
EDITOR_CAROUSEL_SELECTED_SLOT :: EDITOR_CAROUSEL_SLOT_COUNT / 2

Editor_Carousel_Slot :: struct {
	item_index: int,
	x:          f32,
	alpha:      u8,
	selected:   bool,
}

editor_draw_ui :: proc() {
	if editor_state.mode != .EDITING do return

	ui_begin()
	defer ui_end()

	if editor_state.hovered_entity != nil {
		editor_draw_entity_inspector(editor_state.hovered_entity)
	}

	if editor_state.show_hud {
		editor_draw_minimal_hud()
	}
}

editor_draw_tile_preview :: proc(tile_type: tilemap.TileType, x, y, size: f32, alpha: u8) {
	if tile_type == .EMPTY do return

	color := renderer.Colour{120, 170, 120, alpha}
	renderer.draw_rect(x, y, size, size, color)
	renderer.draw_rect_outline(x, y, size, size, color = renderer.WHITE)
}

editor_draw_entity_preview :: proc(entity_type: tilemap.EntityType, x, y, size: f32, alpha: u8) {
	color := renderer.Colour{}
	icon_text := ""
	switch entity_type {
	case .PLAYER:
		color = {80, 160, 255, alpha}
		icon_text = "P"
	case .ENEMY:
		color = {255, 0, 0, alpha}
		icon_text = "E"
	case .NPC:
		color = {0, 0, 255, alpha}
		icon_text = "N"
	case .HOLDABLE:
		color = {255, 165, 0, alpha}
		icon_text = "H"
	case .PRESSURE_PLATE:
		color = {128, 128, 128, alpha}
		icon_text = "PP"
	case .GATE:
		color = {139, 69, 19, alpha}
		icon_text = "G"
	case .DOOR:
		color = {255, 255, 255, alpha}
		icon_text = "D"
	}

	renderer.draw_rect(x, y, size, size, color)
	renderer.draw_rect_outline(x, y, size, size, color = renderer.BLACK)

	text_x := x + size / 2 - 4
	text_y := y + size / 2 - 6
	renderer.draw_text(icon_text, int(text_x), int(text_y), 12, renderer.BLACK)
}

editor_draw_tile_carousel :: proc(carousel_x, carousel_y: f32) {
	tile_preview_size: f32 = 32
	spacing: f32 = 40
	label_y := carousel_y + tile_preview_size + 8
	carousel_width := f32(EDITOR_CAROUSEL_SLOT_COUNT - 1) * spacing + tile_preview_size
	if editor_state.selected_layer == .COLLISION {
		renderer.draw_rect(
			carousel_x + f32(EDITOR_CAROUSEL_SELECTED_SLOT) * spacing,
			carousel_y,
			tile_preview_size,
			tile_preview_size,
			renderer.Colour{255, 64, 64, 180},
		)
		editor_draw_carousel_label("Solid", carousel_x, carousel_width, label_y)
		return
	}

	if editor_state.selected_layer == .ENTITY {
		entities := []tilemap.EntityType{.ENEMY, .NPC, .HOLDABLE, .PRESSURE_PLATE, .GATE, .DOOR}

		current_index := -1
		for entity, i in entities {
			if entity == editor_state.selected_entity {
				current_index = i
				break
			}
		}

		if current_index == -1 do return

		for slot_index in 0 ..< EDITOR_CAROUSEL_SLOT_COUNT {
			slot := editor_carousel_slot(
				current_index,
				slot_index,
				len(entities),
				carousel_x,
				spacing,
			)
			editor_draw_carousel_selection(slot, carousel_y, tile_preview_size)
			editor_draw_entity_preview(
				entities[slot.item_index],
				slot.x,
				carousel_y,
				tile_preview_size,
				slot.alpha,
			)
		}
		editor_draw_carousel_label(
			fmt.tprintf("%v", editor_state.selected_entity),
			carousel_x,
			carousel_width,
			label_y,
		)
		return
	}

	tiles := editor_get_tiles_for_layer(editor_state.selected_layer)
	if len(tiles) == 0 do return

	current_index := -1
	for tile, i in tiles {
		if tile == editor_state.selected_tile {
			current_index = i
			break
		}
	}

	if current_index == -1 do return

	for slot_index in 0 ..< EDITOR_CAROUSEL_SLOT_COUNT {
		slot := editor_carousel_slot(current_index, slot_index, len(tiles), carousel_x, spacing)
		editor_draw_carousel_selection(slot, carousel_y, tile_preview_size)
		editor_draw_tile_preview(
			tiles[slot.item_index],
			slot.x,
			carousel_y,
			tile_preview_size,
			slot.alpha,
		)
	}
	editor_draw_carousel_label(
		fmt.tprintf("%v", editor_state.selected_tile),
		carousel_x,
		carousel_width,
		label_y,
	)
}

editor_draw_carousel_label :: proc(text: string, carousel_x, carousel_width, y: f32) {
	text_width := f32(renderer.measure_text(text, 13))
	x := carousel_x + (carousel_width - text_width) / 2
	renderer.draw_text(text, int(x), int(y), 13, renderer.WHITE)
}

editor_carousel_slot :: proc(
	current_index, slot_index, item_count: int,
	carousel_x, spacing: f32,
) -> Editor_Carousel_Slot {
	distance := abs(slot_index - EDITOR_CAROUSEL_SELECTED_SLOT)
	return {
		item_index = (current_index + slot_index - EDITOR_CAROUSEL_SELECTED_SLOT + item_count) %
		item_count,
		x = carousel_x + f32(slot_index) * spacing,
		alpha = u8(max(255 - distance * 64, 0)),
		selected = slot_index == EDITOR_CAROUSEL_SELECTED_SLOT,
	}
}

editor_draw_carousel_selection :: proc(slot: Editor_Carousel_Slot, carousel_y, preview_size: f32) {
	if !slot.selected do return
	renderer.draw_rect_outline(
		slot.x - 2,
		carousel_y - 2,
		preview_size + 4,
		preview_size + 4,
		3,
		renderer.WHITE,
	)
}

editor_draw_minimal_hud :: proc() {
	design_height := f32(window.get_design_height())
	design_width := f32(window.get_design_width())

	layer_text := ""
	layer_color := renderer.Colour{255, 255, 255, 200}
	switch editor_state.selected_layer {
	case .BASE:
		layer_text = "Base"
		layer_color = {100, 255, 100, 200}
	case .DECORATION:
		layer_text = "Decoration"
		layer_color = {255, 255, 100, 200}
	case .COLLISION:
		layer_text = "Collision"
		layer_color = {255, 100, 100, 200}
	case .ENTITY:
		layer_text = "Entities"
		layer_color = {255, 100, 255, 200}
	}

	panel_height: f32 = editor_state.save_message == "" ? 98 : 118
	panel_bounds := ui_anchored_rect(.Top_Left, 208, panel_height)
	ui_begin_panel(layer_text, panel_bounds, layer_color)
	editor_draw_tile_carousel(panel_bounds.x + 8, panel_bounds.y + 32)
	ui_spacer(62)
	ui_status(editor_state.save_message, editor_state.save_succeeded)
	ui_end_panel()

	actions := editor_state.is_editing_entity ? EDITOR_EDIT_ACTIONS : EDITOR_ACTIONS
	controls_width := design_width - 20
	controls_height := ui_action_bar_height(actions, controls_width)
	controls_y := design_height - controls_height - 10
	ui_action_bar(actions, {10, controls_y, controls_width, controls_height})
}

editor_draw_entity_inspector :: proc(entity: ^tilemap.EntityData) {
	ui_begin_panel(
		fmt.tprintf("Entity: %v", entity.entity_type),
		ui_anchored_rect(.Top_Right, 330, 220),
	)
	defer ui_end_panel()

	ui_field("ID", editor_display_id(entity.instance_id))
	ui_field("Position", fmt.tprintf("%d, %d", entity.x, entity.y))

	switch entity.entity_type {
	case .PLAYER: ui_text("Player spawn marker")
	case .PRESSURE_PLATE:
		ui_field(
			"Trigger",
			fmt.tprintf("%d", entity.trigger_id),
			[]input.Action{.Editor_Value_Previous, .Editor_Value_Next},
		)
		ui_field(
			"Requires Both",
			entity.requires_both ? "Yes" : "No",
			[]input.Action{.Editor_Value_Toggle},
		)

	case .GATE:
		ui_field(
			"Gate",
			fmt.tprintf("%d", entity.gate_id),
			[]input.Action{.Editor_Value_Previous, .Editor_Value_Next},
		)
		ui_field("Inverted", entity.inverted ? "Yes" : "No", []input.Action{.Editor_Value_Toggle})

	case .DOOR:
		ui_field(
			"Target Room",
			editor_display_value(entity.target_room),
			[]input.Action{.Editor_Value_Previous, .Editor_Value_Next},
		)
		ui_field(
			"Target Door",
			editor_display_value(entity.target_door),
			[]input.Action{.Editor_Value_Toggle},
		)

	case .ENEMY:
		kind, _ := content.character_kind_to_wire(entity.character_kind)
		ui_field("Kind", kind, []input.Action{.Editor_Value_Previous, .Editor_Value_Next})

	case .NPC, .HOLDABLE:
	}

	ui_spacer()
	if editor_state.is_editing_entity {
		ui_text("Editing entity", {255, 255, 100, 255})
	} else {
		ui_action_hint(.Editor_Edit_Entity)
	}
}

editor_display_value :: proc(value: string) -> string {
	if value == "" do return "[empty]"
	if len(value) > 24 do return fmt.tprintf("%.21s...", value)
	return value
}

editor_display_id :: proc(id: string) -> string {
	if len(id) > 8 do return fmt.tprintf("%.8s...", id)
	return id
}
