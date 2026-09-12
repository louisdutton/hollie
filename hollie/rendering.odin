package hollie

import "core:math"
import "graphics"
import "tilemap"
import "window"

rendering_camera :: proc() -> graphics.Camera3D {
	screen_width := f32(graphics.get_screen_width())
	screen_height := f32(graphics.get_screen_height())
	visible_width := screen_width / camera.zoom
	visible_height := screen_height / camera.zoom
	center := Vec2{camera.target.x + visible_width / 2, camera.target.y + visible_height / 2}
	distance := visible_height

	// Equal offsets on all three axes give an isometric view.
	return {
		position = {center.x + distance, distance, center.y + distance},
		target = {center.x, 0, center.y},
		up = {0, 1, 0},
		fovy = visible_height,
		projection = .ORTHOGRAPHIC,
	}
}

rendering_draw_interior_walls :: proc() {
	tm := room_get_current()
	if tm == nil || !tm.interior do return

	tile_size := f32(tilemap.get_tile_size())
	wall_height: f32 = 12
	wall_thickness: f32 = 1.5
	wall_color := graphics.Colour{104, 112, 118, 255}

	for y in 0 ..< tilemap.get_tilemap_height() {
		for x in 0 ..< tilemap.get_tilemap_width() {
			if !tilemap.has_floor(x, y) do continue
			center_x := (f32(x) + 0.5) * tile_size
			center_z := (f32(y) + 0.5) * tile_size

			if !tilemap.has_floor(x, y - 1) &&
			   !collision_door_contains_point({center_x, 0, f32(y) * tile_size}) {
				graphics.draw_model(
					model_assets.wall,
					{center_x, 0, f32(y) * tile_size},
					{0, 1, 0},
					90,
					{wall_thickness / 0.2, wall_height, tile_size},
					wall_color,
				)
			}
			if !tilemap.has_floor(x, y + 1) &&
			   !collision_door_contains_point({center_x, 0, f32(y + 1) * tile_size}) {
				graphics.draw_model(
					model_assets.wall,
					{center_x, 0, f32(y + 1) * tile_size},
					{0, 1, 0},
					90,
					{wall_thickness / 0.2, wall_height, tile_size},
					wall_color,
				)
			}
			if !tilemap.has_floor(x - 1, y) &&
			   !collision_door_contains_point({f32(x) * tile_size, 0, center_z}) {
				graphics.draw_model(
					model_assets.wall,
					{f32(x) * tile_size, 0, center_z},
					{0, 1, 0},
					0,
					{wall_thickness / 0.2, wall_height, tile_size},
					wall_color,
				)
			}
			if !tilemap.has_floor(x + 1, y) &&
			   !collision_door_contains_point({f32(x + 1) * tile_size, 0, center_z}) {
				graphics.draw_model(
					model_assets.wall,
					{f32(x + 1) * tile_size, 0, center_z},
					{0, 1, 0},
					0,
					{wall_thickness / 0.2, wall_height, tile_size},
					wall_color,
				)
			}
		}
	}
}

rendering_draw_ground :: proc() {
	tm := room_get_current()
	if tm == nil do return

	tile_size := f32(tilemap.get_tile_size())
	for y in 0 ..< tilemap.get_tilemap_height() {
		for x in 0 ..< tilemap.get_tilemap_width() {
			tile := tilemap.get_base_tile(x, y)
			if tile == nil || tile^ == .Empty do continue

			graphics.draw_model(
				model_assets.floor,
				{(f32(x) + 0.5) * tile_size, 0, (f32(y) + 0.5) * tile_size},
				{0, 1, 0},
				0,
				{tile_size, 1, tile_size},
				graphics.WHITE,
			)
		}
	}

	for structure in tm.structures do rendering_draw_house(structure.position, structure.size)
}

rendering_draw_house :: proc(position, size: Vec2) {
	center := position + size / 2
	wall_height := HOUSE_WALL_HEIGHT
	wall_thickness := HOUSE_WALL_SCALE
	// The doorway wall spans 1.5 model units along its local Z axis.
	graphics.draw_model(
		model_assets.doorway_wall,
		{center.x, 0, position.y + size.y},
		{0, 1, 0},
		90,
		{wall_thickness, wall_height, size.x / 1.5},
		graphics.WHITE,
	)
	graphics.draw_model(
		model_assets.wall,
		{center.x, 0, position.y},
		{0, 1, 0},
		90,
		{wall_thickness, wall_height, size.x},
		graphics.WHITE,
	)
	graphics.draw_model(
		model_assets.wall,
		{position.x, 0, center.y},
		{0, 1, 0},
		0,
		{wall_thickness, wall_height, size.y},
		graphics.WHITE,
	)
	graphics.draw_model(
		model_assets.wall,
		{position.x + size.x, 0, center.y},
		{0, 1, 0},
		0,
		{wall_thickness, wall_height, size.y},
		graphics.WHITE,
	)
	graphics.draw_model(
		model_assets.cube,
		{center.x, wall_height, center.y},
		{0, 1, 0},
		0,
		{size.x + 2 * HOUSE_ROOF_OVERHANG, HOUSE_ROOF_HEIGHT, size.y + 2 * HOUSE_ROOF_OVERHANG},
		graphics.Colour{120, 150, 105, 255},
	)
}

geometry_facing_angle :: proc(direction: Vec2) -> f32 {
	return math.to_degrees(math.atan2(direction.x, direction.y))
}

model_animation_frame :: proc(
	visual_time: f32,
	clip: graphics.Model_Animation,
	playback: Animation_Playback,
) -> f32 {
	return animation_frame_at_time(visual_time, int(clip.keyframeCount), playback)
}

rendering_draw_character :: proc(
	anim: ^Animator,
	position, facing: Vec2,
	tint: graphics.Colour,
	flash_amount: f32,
	base_height: f32 = 0,
) {
	current_state := anim.current_anim
	playback_modes := MODEL_CHARACTER_PLAYBACK
	clip_index := model_assets.character_animation_indices[current_state]
	if clip_index >= 0 {
		clip := model_assets.character_animations[clip_index]
		clip_frame := model_animation_frame(anim.visual_time, clip, playback_modes[current_state])
		previous_state := anim.previous_anim
		previous_clip_index := -1
		previous_clip_index = model_assets.character_animation_indices[previous_state]
		blend := min(anim.blend_elapsed / RENDERING_CHARACTER_BLEND_DURATION, 1)
		if blend < 1 && previous_clip_index >= 0 {
			previous_clip := model_assets.character_animations[previous_clip_index]
			previous_frame := model_animation_frame(
				anim.previous_time,
				previous_clip,
				playback_modes[previous_state],
			)
			graphics.update_model_animation_blended(
				model_assets.character,
				previous_clip,
				previous_frame,
				clip,
				clip_frame,
				blend,
			)
		} else {
			graphics.update_model_animation(model_assets.character, clip, clip_frame)
		}
	}
	flash := min(max(flash_amount, 0), 1)
	graphics.set_shader_float(
		rendering_state.active_character_shader,
		rendering_state.character_flash_location,
		&flash,
	)
	graphics.draw_model(
		model_assets.character,
		geometry_grounded_position(
			position,
			model_assets.character_bounds,
			MODEL_CHARACTER_SCALE,
			base_height,
		),
		{0, 1, 0},
		geometry_facing_angle(facing),
		{MODEL_CHARACTER_SCALE, MODEL_CHARACTER_SCALE, MODEL_CHARACTER_SCALE},
		tint,
	)
	flash = 0
	graphics.set_shader_float(
		rendering_state.active_character_shader,
		rendering_state.character_flash_location,
		&flash,
	)
}

rendering_draw_entities :: proc() {
	for &entity in entities {
		switch &e in entity {
		case Player:
			tint :=
				e.index == .Player_1 ? graphics.Colour{92, 156, 214, 255} : graphics.Colour{102, 190, 132, 255}
			rendering_draw_character(
				&e.anim_data,
				e.position,
				e.facing_direction,
				tint,
				e.hit_flash_timer / 0.2,
				e.height,
			)
		case Enemy:
			tint := graphics.Colour{196, 92, 88, 255}
			rendering_draw_character(
				&e.anim_data,
				e.position,
				e.facing_direction,
				tint,
				e.hit_flash_timer / 0.2,
				e.height,
			)
		case Npc:
			tint := graphics.Colour{220, 190, 96, 255}
			rendering_draw_character(
				&e.anim_data,
				e.position,
				e.facing_direction,
				tint,
				e.hit_flash_timer / 0.2,
				e.height,
			)
		case Holdable:
			base_height := e.height
			if e.held_by != nil {
				base_height = e.held_by.height + RENDERING_CARRIED_ITEM_HEIGHT
			}
			graphics.draw_model(
				model_assets.crate,
				geometry_grounded_position(
					e.held_by != nil ? e.held_by.position : e.position,
					model_assets.crate_bounds,
					MODEL_CRATE_SCALE,
					base_height,
				),
				{0, 1, 0},
				0,
				{MODEL_CRATE_SCALE, MODEL_CRATE_SCALE, MODEL_CRATE_SCALE},
				graphics.WHITE,
			)
		case Pressure_Plate:
			state := e.active ? Pressure_Pad_State.On : Pressure_Pad_State.Off
			clip_index := model_assets.pressure_pad_animation_indices[state]
			if clip_index >= 0 {
				clip := model_assets.pressure_pad_animations[clip_index]
				clip_frame := model_animation_frame(e.animation_time, clip, .Once_Hold)
				graphics.update_model_animation(model_assets.pressure_pad, clip, clip_frame)
			}
			graphics.draw_model(
				model_assets.pressure_pad,
				geometry_grounded_position(
					e.position,
					model_assets.pressure_pad_bounds,
					MODEL_PRESSURE_PAD_SCALE,
				),
				{0, 1, 0},
				0,
				{MODEL_PRESSURE_PAD_SCALE, MODEL_PRESSURE_PAD_SCALE, MODEL_PRESSURE_PAD_SCALE},
				graphics.WHITE,
			)
		case Gate:
			if e.open do continue
			block_size: f32 = 16
			for y in 0 ..< int(e.collider.size.z / block_size) {
				for x in 0 ..< int(e.collider.size.x / block_size) {
					graphics.draw_model(
						model_assets.cube,
						{
							e.position.x + (f32(x) + 0.5) * block_size,
							0,
							e.position.y + (f32(y) + 0.5) * block_size,
						},
						{0, 1, 0},
						0,
						{block_size, RENDERING_GATE_HEIGHT, block_size},
						graphics.Colour{120, 130, 136, 255},
					)
				}
			}
		case Door:
			collider_position := Vec2 {
				e.position.x + e.collider.offset.x,
				e.position.y + e.collider.offset.z,
			}
			center := collider_position + Vec2{e.collider.size.x, e.collider.size.z} / 2
			graphics.draw_model(
				model_assets.door_indicator,
				geometry_position(center, 0.2),
				{0, 1, 0},
				0,
				{e.collider.size.x / 0.6, 1, e.collider.size.z / 0.6},
				graphics.Colour{142, 104, 190, 255},
			)
		}
	}
}

rendering_draw_particles :: proc() {
	for &particle in particle_system.particles {
		alpha_factor := particle.lifetime / particle.max_lifetime
		color := particle.color
		color.a = u8(f32(color.a) * alpha_factor)
		graphics.draw_sphere(geometry_position(particle.position, 3), particle.size * 0.35, color)
	}
}

rendering_scaled_text_size :: proc(design_size: int, screen_scale: f32) -> int {
	return max(int(f32(design_size) * screen_scale + 0.5), 1)
}

rendering_draw_label :: proc(
	text: string,
	world_position: graphics.Vec3,
	camera_3d: graphics.Camera3D,
	color: graphics.Colour,
) {
	position := graphics.get_world_to_screen(world_position, camera_3d)
	text_size := rendering_scaled_text_size(RENDERING_LABEL_TEXT_SIZE, window.get_ui_scale())
	text_width := int(graphics.measure_text(text, i32(text_size)))
	graphics.draw_text(
		text,
		int(position.x) - text_width / 2,
		int(position.y) - text_size / 2,
		text_size,
		color = color,
	)
}

rendering_draw_labels :: proc(camera_3d: graphics.Camera3D) {
	if game.player_count != 2 do return
	for &entity in entities {
		player, ok := &entity.(Player)
		if !ok do continue
		label := player.index == .Player_1 ? "P1" : "P2"
		color := player.index == .Player_1 ? graphics.BLUE : graphics.GREEN
		rendering_draw_label(
			label,
			geometry_position(player.position, player.height + 24),
			camera_3d,
			color,
		)
	}
}

rendering_draw :: proc(show_debug: bool = false) {
	graphics.clear_background(RENDERING_BACKGROUND_COLOR)
	camera_3d := rendering_camera()
	shadow_map_bind_for_rendering()
	graphics.begin_mode_3d(camera_3d)

	rendering_draw_ground()
	rendering_draw_interior_walls()
	rendering_draw_entities()
	rendering_draw_particles()

	when ODIN_DEBUG {
		if show_debug do debug_draw()
	}

	graphics.end_mode_3d()
	rendering_draw_labels(camera_3d)
	when ODIN_DEBUG {
		if show_debug do debug_draw_labels(camera_3d)
	}
}
