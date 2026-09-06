package hollie

import "renderer"
import "tilemap"
import rl "vendor:raylib"

when ODIN_DEBUG {
	editor_draw_entities :: proc() {
		for entity in tilemap.get_entities() {
			position := rl.Vector3{f32(entity.x), 4, f32(entity.y)}
			color: rl.Color
			switch entity.entity_type {
			case .Player: color = rl.BLUE
			case .Enemy: color = rl.RED
			case .Npc: color = rl.GOLD
			case .Holdable: color = rl.ORANGE
			case .Pressure_Plate: color = rl.GRAY
			case .Gate: color = rl.BROWN
			case .Door: color = rl.PURPLE
			}
			rl.DrawCubeV(position, {8, 8, 8}, color)
			rl.DrawCubeWiresV(position, {8, 8, 8}, rl.WHITE)
		}
	}

	editor_draw_cursor :: proc() {
		if !editor_state.cursor_visible do return
		tile_size := f32(tilemap.get_tile_size())
		center := rl.Vector3 {
			(f32(editor_state.cursor_x) + 0.5) * tile_size,
			1,
			(f32(editor_state.cursor_y) + 0.5) * tile_size,
		}
		color := editor_state.selected_layer == .Collision ? rl.RED : rl.WHITE
		rl.DrawCubeWiresV(center, {tile_size, 2, tile_size}, color)
	}

	editor_draw :: proc() {
		rl.ClearBackground(RENDERING_BACKGROUND_COLOR)
		camera_3d := rendering_camera()
		rl.BeginMode3D(camera_3d)
		rendering_draw_ground()
		rendering_draw_interior_walls()
		editor_draw_entities()
		debug_draw()
		editor_draw_cursor()
		rl.EndMode3D()
	}
}

when ODIN_DEBUG {
	debug_draw :: proc() {
		tile_size := f32(tilemap.get_tile_size())
		for y in 0 ..< tilemap.get_tilemap_height() {
			for x in 0 ..< tilemap.get_tilemap_width() {
				collision := tilemap.get_collision_tile(x, y)
				if collision == nil || collision^ != .Solid do continue
				center := rl.Vector3{(f32(x) + 0.5) * tile_size, 0.5, (f32(y) + 0.5) * tile_size}
				size := rl.Vector3{tile_size, 1, tile_size}
				rl.DrawCubeV(center, size, rl.Color{255, 48, 48, 96})
				rl.DrawCubeWiresV(center, size, rl.Color{255, 96, 96, 220})
			}
		}

		for &entity in entities {
			collider_pos := collision_entity_world_position(&entity)
			collider_size := collision_entity_size(&entity)
			color: rl.Color
			switch e in entity {
			case Player: color = rl.GREEN
			case Enemy: color = rl.RED
			case Npc: color = rl.WHITE
			case Pressure_Plate: color = rl.BLUE
			case Gate: color = rl.SKYBLUE
			case Holdable: color = rl.YELLOW
			case Door: color = rl.PURPLE
			}
			height := max(collision_entity_height(&entity), 0.25)
			center := rl.Vector3 {
				collider_pos.x + collider_size.x / 2,
				collision_entity_vertical_offset(&entity) + height / 2 + 0.01,
				collider_pos.y + collider_size.y / 2,
			}
			rl.DrawCubeWiresV(center, {collider_size.x, height, collider_size.y}, color)
		}
	}

	debug_draw_labels :: proc(camera_3d: rl.Camera3D) {
		doors := entity_get_doors()
		defer delete(doors)
		for door in doors {
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
