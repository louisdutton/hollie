package hollie

import "renderer"
import "tilemap"

when ODIN_DEBUG {
	editor_draw_entities :: proc() {
		for entity in tilemap.get_entities() {
			position := renderer.Vec3{f32(entity.x), 4, f32(entity.y)}
			color: renderer.Colour
			switch entity.entity_type {
			case .Player: color = renderer.BLUE
			case .Enemy: color = renderer.RED
			case .Npc: color = renderer.GOLD
			case .Holdable: color = renderer.ORANGE
			case .Pressure_Plate: color = renderer.GRAY
			case .Gate: color = renderer.BROWN
			case .Door: color = renderer.PURPLE
			}
			renderer.draw_cube(position, {8, 8, 8}, color)
			renderer.draw_cube_outline(position, {8, 8, 8}, renderer.WHITE)
		}
	}

	editor_draw_cursor :: proc() {
		if !editor_state.cursor_visible do return
		tile_size := f32(tilemap.get_tile_size())
		center := renderer.Vec3 {
			(f32(editor_state.cursor_x) + 0.5) * tile_size,
			1,
			(f32(editor_state.cursor_y) + 0.5) * tile_size,
		}
		color := editor_state.selected_layer == .Collision ? renderer.RED : renderer.WHITE
		renderer.draw_cube_outline(center, {tile_size, 2, tile_size}, color)
	}

	editor_draw :: proc() {
		renderer.clear_background(RENDERING_BACKGROUND_COLOR)
		camera_3d := rendering_camera()
		renderer.begin_mode_3d(camera_3d)
		rendering_draw_ground()
		rendering_draw_interior_walls()
		editor_draw_entities()
		debug_draw()
		editor_draw_cursor()
		renderer.end_mode_3d()
	}
}

when ODIN_DEBUG {
	debug_draw :: proc() {
		tile_size := f32(tilemap.get_tile_size())
		for y in 0 ..< tilemap.get_tilemap_height() {
			for x in 0 ..< tilemap.get_tilemap_width() {
				collision := tilemap.get_collision_tile(x, y)
				if collision == nil || collision^ != .Solid do continue
				center := renderer.Vec3{(f32(x) + 0.5) * tile_size, 0.5, (f32(y) + 0.5) * tile_size}
				size := renderer.Vec3{tile_size, 1, tile_size}
				renderer.draw_cube(center, size, renderer.Colour{255, 48, 48, 96})
				renderer.draw_cube_outline(center, size, renderer.Colour{255, 96, 96, 220})
			}
		}

		for &entity in entities {
			collider_pos := collision_entity_world_position(&entity)
			collider_size := collision_entity_size(&entity)
			color: renderer.Colour
			switch e in entity {
			case Player: color = renderer.GREEN
			case Enemy: color = renderer.RED
			case Npc: color = renderer.WHITE
			case Pressure_Plate: color = renderer.BLUE
			case Gate: color = renderer.SKYBLUE
			case Holdable: color = renderer.YELLOW
			case Door: color = renderer.PURPLE
			}
			height := max(collision_entity_height(&entity), 0.25)
			center := renderer.Vec3 {
				collider_pos.x + collider_size.x / 2,
				collision_entity_vertical_offset(&entity) + height / 2 + 0.01,
				collider_pos.y + collider_size.y / 2,
			}
			renderer.draw_cube_outline(center, {collider_size.x, height, collider_size.y}, color)
		}
	}

	debug_draw_labels :: proc(camera_3d: renderer.Camera3D) {
		for &entity in entities {
			door, ok := &entity.(Door)
			if !ok do continue
			center := door.position + door.collider.size / 2
			rendering_draw_label(
				door.target_room,
				geometry_position(center, 4),
				camera_3d,
				renderer.PURPLE,
			)
		}
	}
}
