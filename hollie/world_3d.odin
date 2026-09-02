package hollie

import "asset"
import "renderer"
import "tilemap"
import rl "vendor:raylib"

WORLD_3D_CHARACTER_SCALE :: f32(8)
WORLD_3D_OBJECT_SIZE :: f32(12)

World_3D_Assets :: struct {
	tile:      rl.Model,
	character: rl.Model,
	object:    rl.Model,
	house:     rl.Model,
}

world_3d_assets: World_3D_Assets

world_3d_load_model :: proc(relative_path: string) -> rl.Model {
	path := asset.path(relative_path)
	defer delete(path)
	return rl.LoadModel(cstring(raw_data(path)))
}

world_3d_init :: proc() {
	world_3d_assets.tile = world_3d_load_model("art/prototype/3d/tile.obj")
	world_3d_assets.character = world_3d_load_model("art/prototype/3d/pawn.obj")
	world_3d_assets.object = world_3d_load_model("art/prototype/3d/object.obj")
	world_3d_assets.house = world_3d_load_model("art/prototype/3d/house.obj")
}

world_3d_fini :: proc() {
	if world_3d_assets.tile.meshCount > 0 do rl.UnloadModel(world_3d_assets.tile)
	if world_3d_assets.character.meshCount > 0 do rl.UnloadModel(world_3d_assets.character)
	if world_3d_assets.object.meshCount > 0 do rl.UnloadModel(world_3d_assets.object)
	if world_3d_assets.house.meshCount > 0 do rl.UnloadModel(world_3d_assets.house)
	world_3d_assets = {}
}

world_3d_position :: proc(position: Vec2, height: f32 = 0) -> rl.Vector3 {
	return {position.x, height, position.y}
}

world_3d_camera :: proc() -> rl.Camera3D {
	screen_width := f32(rl.GetScreenWidth())
	screen_height := f32(rl.GetScreenHeight())
	visible_width := screen_width / camera.zoom
	visible_height := screen_height / camera.zoom
	center := Vec2{camera.target.x + visible_width / 2, camera.target.y + visible_height / 2}
	distance := visible_height

	return {
		position = {center.x, distance * 0.85, center.y + distance * 0.72},
		target = {center.x, 0, center.y},
		up = {0, 1, 0},
		fovy = visible_height,
		projection = .ORTHOGRAPHIC,
	}
}

world_3d_has_floor :: proc(x, y: int) -> bool {
	if x < 0 || y < 0 || x >= tilemap.get_tilemap_width() || y >= tilemap.get_tilemap_height() {
		return false
	}
	tile := tilemap.get_base_tile(x, y)
	return tile != nil && tile^ != .EMPTY
}

world_3d_edge_is_door :: proc(position: Vec2) -> bool {
	for &entity in entities {
		if door, ok := &entity.(Door); ok {
			collider_pos := door.position + door.collider.offset
			if position.x >= collider_pos.x &&
			   position.x <= collider_pos.x + door.collider.size.x &&
			   position.y >= collider_pos.y &&
			   position.y <= collider_pos.y + door.collider.size.y {
				return true
			}
		}
	}
	return false
}

world_3d_draw_interior_walls :: proc() {
	tm := room_get_current()
	if tm == nil || tm.room_id != "small_room" do return

	tile_size := f32(tilemap.get_tile_size())
	wall_height: f32 = 12
	wall_thickness: f32 = 1.5
	wall_color := rl.Color{104, 112, 118, 255}

	for y in 0 ..< tilemap.get_tilemap_height() {
		for x in 0 ..< tilemap.get_tilemap_width() {
			if !world_3d_has_floor(x, y) do continue
			center_x := (f32(x) + 0.5) * tile_size
			center_z := (f32(y) + 0.5) * tile_size

			if !world_3d_has_floor(x, y - 1) && !world_3d_edge_is_door({center_x, f32(y) * tile_size}) {
				rl.DrawModelEx(world_3d_assets.object, {center_x, 0, f32(y) * tile_size}, {0, 1, 0}, 0, {tile_size, wall_height, wall_thickness}, wall_color)
			}
			if !world_3d_has_floor(x, y + 1) && !world_3d_edge_is_door({center_x, f32(y + 1) * tile_size}) {
				rl.DrawModelEx(world_3d_assets.object, {center_x, 0, f32(y + 1) * tile_size}, {0, 1, 0}, 0, {tile_size, wall_height, wall_thickness}, wall_color)
			}
			if !world_3d_has_floor(x - 1, y) && !world_3d_edge_is_door({f32(x) * tile_size, center_z}) {
				rl.DrawModelEx(world_3d_assets.object, {f32(x) * tile_size, 0, center_z}, {0, 1, 0}, 0, {wall_thickness, wall_height, tile_size}, wall_color)
			}
			if !world_3d_has_floor(x + 1, y) && !world_3d_edge_is_door({f32(x + 1) * tile_size, center_z}) {
				rl.DrawModelEx(world_3d_assets.object, {f32(x + 1) * tile_size, 0, center_z}, {0, 1, 0}, 0, {wall_thickness, wall_height, tile_size}, wall_color)
			}
		}
	}
}

world_3d_draw_ground :: proc() {
	tm := room_get_current()
	if tm == nil do return

	tile_size := f32(tilemap.get_tile_size())
	for y in 0 ..< tilemap.get_tilemap_height() {
		for x in 0 ..< tilemap.get_tilemap_width() {
			tile := tilemap.get_base_tile(x, y)
			if tile == nil || tile^ == .EMPTY do continue

			rl.DrawModelEx(
				world_3d_assets.tile,
				{(f32(x) + 0.5) * tile_size, 0, (f32(y) + 0.5) * tile_size},
				{0, 1, 0},
				0,
				{tile_size, 1, tile_size},
				rl.WHITE,
			)
		}
	}

	for scenery in tm.scenery {
		center := scenery.position + scenery.size / 2
		rl.DrawModelEx(
			world_3d_assets.house,
			world_3d_position(center),
			{0, 1, 0},
			0,
			{scenery.size.x, min(scenery.size.x, scenery.size.y) * 0.75, scenery.size.y},
			rl.WHITE,
		)
	}
}

World_3D_Character_Pose :: struct {
	height: f32,
	angle:  f32,
	axis:   rl.Vector3,
	scale:  rl.Vector3,
}

world_3d_character_pose :: proc(anim: ^Animator) -> World_3D_Character_Pose {
	pose := World_3D_Character_Pose {
		axis  = {0, 1, 0},
		scale = {1, 1, 1},
	}
	frame := int(anim.frame)
	state_index := int(anim.current_anim)
	frame_count := 1
	if state_index >= 0 && state_index < len(anim.frame_counts) {
		frame_count = max(anim.frame_counts[state_index], 1)
	}
	progress := f32(frame) / f32(frame_count)

	switch anim.current_anim {
	case .IDLE:
		idle_curve := [4]i32{0, 1, 2, 1}
		pose.height = f32(idle_curve[frame % 4]) * 0.25
	case .RUN:
		run_curve := [4]i32{0, 2, 0, 1}
		pose.height = f32(run_curve[frame % 4]) * 0.75
		pose.angle = frame % 2 == 0 ? -4 : 4
		pose.axis = {0, 0, 1}
	case .JUMP:
		jump_curve := [10]f32{0, 2, 6, 10, 13, 10, 7, 3, 1, 0}
		pose.height = jump_curve[min(frame, len(jump_curve) - 1)]
	case .DEATH:
		pose.angle = progress * 90
		pose.axis = {0, 0, 1}
	case .ATTACK:
		attack_curve := [10]i32{0, -4, -9, -14, -8, 0, 7, 3, 0, 0}
		pose.angle = f32(attack_curve[frame % 10])
		pose.axis = {0, 0, 1}
		pose.scale.x = frame >= 2 && frame <= 6 ? 1.18 : 1
	case .ROLL:
		pose.angle = progress * 360
		pose.axis = {0, 0, 1}
		pose.height = 2
	case .CARRY:
		carry_curve := [4]i32{0, 1, 2, 1}
		pose.height = f32(carry_curve[frame % 4]) * 0.5
	}

	return pose
}

world_3d_draw_character :: proc(anim: ^Animator, position: Vec2, tint: rl.Color) {
	pose := world_3d_character_pose(anim)
	scale := pose.scale * WORLD_3D_CHARACTER_SCALE
	rl.DrawModelEx(
		world_3d_assets.character,
		world_3d_position(position, pose.height),
		pose.axis,
		pose.angle,
		scale,
		tint,
	)
}

world_3d_draw_entities :: proc() {
	for &entity in entities {
		switch &e in entity {
		case Player:
			tint :=
				e.index == .PLAYER_1 ? rl.Color{92, 156, 214, 255} : rl.Color{102, 190, 132, 255}
			if e.hit_flash_timer > 0 do tint = rl.WHITE
			world_3d_draw_character(&e.anim_data, e.position, tint)
		case Enemy:
			tint := rl.Color{196, 92, 88, 255}
			if e.hit_flash_timer > 0 do tint = rl.WHITE
			world_3d_draw_character(&e.anim_data, e.position, tint)
		case NPC:
			tint := rl.Color{220, 190, 96, 255}
			if e.hit_flash_timer > 0 do tint = rl.WHITE
			world_3d_draw_character(&e.anim_data, e.position, tint)
		case Holdable:
			position := world_3d_position(e.position)
			if e.held_by != nil {
				position = world_3d_position(e.held_by.position, 20)
			}
			rl.DrawModelEx(
				world_3d_assets.object,
				position,
				{0, 1, 0},
				0,
				{WORLD_3D_OBJECT_SIZE, WORLD_3D_OBJECT_SIZE, WORLD_3D_OBJECT_SIZE},
				rl.WHITE,
			)
		case Pressure_Plate:
			tint := e.active ? rl.GREEN : rl.Color{150, 150, 150, 255}
			rl.DrawModelEx(
				world_3d_assets.object,
				world_3d_position(e.position),
				{0, 1, 0},
				0,
				{e.collider.size.x, 1.5, e.collider.size.y},
				tint,
			)
		case Gate:
			if e.open do continue
			block_size: f32 = 16
			for y in 0 ..< int(e.collider.size.y / block_size) {
				for x in 0 ..< int(e.collider.size.x / block_size) {
					rl.DrawModelEx(
						world_3d_assets.object,
						{
							e.position.x + (f32(x) + 0.5) * block_size,
							0,
							e.position.y + (f32(y) + 0.5) * block_size,
						},
						{0, 1, 0},
						0,
						{block_size, 18, block_size},
						rl.Color{120, 130, 136, 255},
					)
				}
			}
		case Door: continue
		}
	}
}

world_3d_draw_particles :: proc() {
	for &particle in particle_system.particles {
		alpha_factor := particle.lifetime / particle.max_lifetime
		color := particle.color
		color.a = u8(f32(color.a) * alpha_factor)
		rl.DrawSphere(world_3d_position(particle.position, 3), particle.size * 0.35, color)
	}
}

world_3d_draw_labels :: proc(camera_3d: rl.Camera3D) {
	if game.player_count != 2 do return
	players := entity_get_players()
	defer delete(players)
	for player in players {
		position := rl.GetWorldToScreen(world_3d_position(player.position, 24), camera_3d)
		label := player.index == .PLAYER_1 ? "P1" : "P2"
		color := player.index == .PLAYER_1 ? renderer.BLUE : renderer.GREEN
		renderer.draw_text(label, int(position.x) - 8, int(position.y) - 6, 12, color = color)
	}
}

when ODIN_DEBUG {
	world_3d_draw_debug :: proc() {
		tile_size := f32(tilemap.get_tile_size())
		for y in 0 ..< tilemap.get_tilemap_height() {
			for x in 0 ..< tilemap.get_tilemap_width() {
				collision := tilemap.get_collision_tile(x, y)
				if collision == nil || collision^ != .SOLID do continue
				center := rl.Vector3{(f32(x) + 0.5) * tile_size, 0.5, (f32(y) + 0.5) * tile_size}
				size := rl.Vector3{tile_size, 1, tile_size}
				rl.DrawCubeV(center, size, rl.Color{255, 48, 48, 96})
				rl.DrawCubeWiresV(center, size, rl.Color{255, 96, 96, 220})
			}
		}

		for &entity in entities {
			collider_pos := entity_get_world_collider_pos(&entity)
			collider_size := entity_get_collider_size(&entity)
			color: rl.Color
			switch e in entity {
			case Player: color = rl.GREEN
			case Enemy: color = rl.RED
			case NPC: color = rl.WHITE
			case Pressure_Plate: color = rl.BLUE
			case Gate: color = rl.SKYBLUE
			case Holdable: color = rl.YELLOW
			case Door: color = rl.PURPLE
			}
			center := rl.Vector3 {
				collider_pos.x + collider_size.x / 2,
				1,
				collider_pos.y + collider_size.y / 2,
			}
			rl.DrawCubeWiresV(center, {collider_size.x, 2, collider_size.y}, color)
		}
	}

	world_3d_draw_debug_labels :: proc(camera_3d: rl.Camera3D) {
		doors := entity_get_doors()
		defer delete(doors)
		for door in doors {
			center := door.position + door.collider.size / 2
			position := rl.GetWorldToScreen(world_3d_position(center, 4), camera_3d)
			renderer.draw_text(door.target_room, int(position.x), int(position.y), 12, color = renderer.PURPLE)
		}
	}
}

world_3d_draw :: proc(show_debug: bool = false) {
	rl.ClearBackground({12, 14, 18, 255})
	camera_3d := world_3d_camera()
	rl.BeginMode3D(camera_3d)

	world_3d_draw_ground()
	world_3d_draw_interior_walls()
	world_3d_draw_entities()
	world_3d_draw_particles()

	when ODIN_DEBUG {
		if show_debug do world_3d_draw_debug()
	}

	rl.EndMode3D()
	world_3d_draw_labels(camera_3d)
	when ODIN_DEBUG {
		if show_debug do world_3d_draw_debug_labels(camera_3d)
	}
}
