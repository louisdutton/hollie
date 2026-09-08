package hollie

import "graphics"
import "tilemap"

when ODIN_DEBUG {
	editor_draw_entities :: proc() {
		for entity in tilemap.get_entities() {
			position := graphics.Vec3{f32(entity.x), 4, f32(entity.y)}
			color: graphics.Colour
			switch entity.entity_type {
			case .Player: color = graphics.BLUE
			case .Enemy: color = graphics.RED
			case .Npc: color = graphics.GOLD
			case .Holdable: color = graphics.ORANGE
			case .Pressure_Plate: color = graphics.GRAY
			case .Gate: color = graphics.BROWN
			case .Door: color = graphics.PURPLE
			}
			graphics.draw_cube(position, {8, 8, 8}, color)
			graphics.draw_cube_outline(position, {8, 8, 8}, graphics.WHITE)
		}
	}

	editor_draw_cursor :: proc() {
		if !editor_state.cursor_visible do return
		tile_size := f32(tilemap.get_tile_size())
		center := graphics.Vec3 {
			(f32(editor_state.cursor_x) + 0.5) * tile_size,
			1,
			(f32(editor_state.cursor_y) + 0.5) * tile_size,
		}
		color := editor_state.selected_layer == .Collision ? graphics.RED : graphics.WHITE
		graphics.draw_cube_outline(center, {tile_size, 2, tile_size}, color)
	}

	editor_draw :: proc() {
		graphics.clear_background(RENDERING_BACKGROUND_COLOR)
		camera_3d := rendering_camera()
		graphics.begin_mode_3d(camera_3d)
		rendering_draw_ground()
		rendering_draw_interior_walls()
		editor_draw_entities()
		debug_draw()
		editor_draw_cursor()
		graphics.end_mode_3d()
	}
}

when ODIN_DEBUG {
	debug_draw :: proc() {
		tile_size := f32(tilemap.get_tile_size())
		for y in 0 ..< tilemap.get_tilemap_height() {
			for x in 0 ..< tilemap.get_tilemap_width() {
				collision := tilemap.get_collision_tile(x, y)
				if collision == nil || collision^ != .Solid do continue
				center := graphics.Vec3 {
					(f32(x) + 0.5) * tile_size,
					0.5,
					(f32(y) + 0.5) * tile_size,
				}
				size := graphics.Vec3{tile_size, 1, tile_size}
				graphics.draw_cube(center, size, graphics.Colour{255, 48, 48, 96})
				graphics.draw_cube_outline(center, size, graphics.Colour{255, 96, 96, 220})
			}
		}

		for &entity in entities {
			aabb := collision_entity_aabb(&entity)
			color: graphics.Colour
			switch e in entity {
			case Player: color = graphics.GREEN
			case Enemy: color = graphics.RED
			case Npc: color = graphics.WHITE
			case Pressure_Plate: color = graphics.BLUE
			case Gate: color = graphics.SKYBLUE
			case Holdable: color = graphics.YELLOW
			case Door: color = graphics.PURPLE
			}
			size := aabb.max - aabb.min
			size.y = max(size.y, 0.25)
			center := (aabb.min + aabb.max) / 2
			center.y += 0.01
			graphics.draw_cube_outline(center, size, color)
		}
	}

	debug_draw_labels :: proc(camera_3d: graphics.Camera3D) {
		for &entity in entities {
			door, ok := &entity.(Door)
			if !ok do continue
			center := door.position + Vec2{door.collider.size.x, door.collider.size.z} / 2
			rendering_draw_label(
				door.target_room,
				geometry_position(center, 4),
				camera_3d,
				graphics.PURPLE,
			)
		}
	}
}
