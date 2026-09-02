package hollie

import "asset"
import "core:c"
import "core:math"
import "renderer"
import "tilemap"
import rl "vendor:raylib"
import "window"

WORLD_3D_CHARACTER_SCALE :: f32(32)
WORLD_3D_CRATE_SCALE :: f32(24)
WORLD_3D_PRESSURE_PAD_SCALE :: f32(32)
WORLD_3D_GATE_HEIGHT :: f32(18)
WORLD_3D_CARRIED_ITEM_HEIGHT :: f32(20)
WORLD_3D_CHARACTER_BLEND_DURATION :: f32(0.12)
WORLD_3D_LABEL_TEXT_SIZE :: 12
WORLD_3D_PRESSURE_PAD_MODEL :: "button-floor-square-raylib.glb"
WORLD_3D_CHARACTER_CLIP_NAMES :: [7]string {
	"idle",
	"walk",
	"sprint",
	"die",
	"attack-melee-right",
	"sprint",
	"walk-holding-both",
}
WORLD_3D_CHARACTER_PLAYBACK :: [7]Animation_Playback {
	.LOOP,
	.LOOP,
	.ONCE_HOLD,
	.ONCE_HOLD,
	.ONCE_HOLD,
	.ONCE_HOLD,
	.LOOP,
}
WORLD_3D_PRESSURE_PAD_CLIP_NAMES :: [2]string{"toggle-off", "toggle-on"}
WORLD_3D_CHARACTER_MODEL :: "figurine-raylib.glb"

World_3D_Assets :: struct {
	lighting_shader:                rl.Shader,
	character_lighting_shader:      rl.Shader,
	active_character_shader:        rl.Shader,
	character_flash_location:       c.int,
	floor:                          rl.Model,
	character:                      rl.Model,
	crate:                          rl.Model,
	pressure_pad:                   rl.Model,
	cube:                           rl.Model,
	wall:                           rl.Model,
	doorway_wall:                   rl.Model,
	door_indicator:                 rl.Model,
	character_animations:           [^]rl.ModelAnimation,
	character_animation_count:      c.int,
	character_animation_indices:    [7]int,
	pressure_pad_animations:        [^]rl.ModelAnimation,
	pressure_pad_animation_count:   c.int,
	pressure_pad_animation_indices: [2]int,
	character_bounds:               rl.BoundingBox,
	crate_bounds:                   rl.BoundingBox,
	pressure_pad_bounds:            rl.BoundingBox,
}

world_3d_assets: World_3D_Assets

world_3d_load_model :: proc(relative_path: string) -> rl.Model {
	path := asset.path(relative_path)
	defer delete(path)
	return rl.LoadModel(cstring(raw_data(path)))
}

world_3d_apply_shader :: proc(model: ^rl.Model, shader: rl.Shader) {
	for material_index in 0 ..< int(model.materialCount) {
		model.materials[material_index].shader = shader
	}
}

world_3d_uses_gpu_skinning :: proc(model: ^rl.Model) -> bool {
	for mesh_index in 0 ..< int(model.meshCount) {
		mesh := &model.meshes[mesh_index]
		if mesh.boneWeights != nil && mesh.animVertices == nil do return true
	}
	return false
}

world_3d_set_shader_vec3 :: proc(shader: rl.Shader, name: cstring, value: rl.Vector3) {
	location := rl.GetShaderLocation(shader, name)
	uniform_value := value
	rl.SetShaderValue(shader, location, &uniform_value, .VEC3)
}

world_3d_configure_lighting :: proc(shader: rl.Shader) {
	world_3d_set_shader_vec3(shader, "ambientColor", {0.18, 0.2, 0.24})
	world_3d_set_shader_vec3(shader, "keyDirection", {-0.45, -0.82, -0.35})
	world_3d_set_shader_vec3(shader, "keyColor", {0.55, 0.49, 0.42})
	world_3d_set_shader_vec3(shader, "fillDirection", {0.65, -0.35, 0.55})
	world_3d_set_shader_vec3(shader, "fillColor", {0.08, 0.11, 0.16})
}

world_3d_init :: proc() {
	root :: "art/kenney/prototype-kit/"
	world_3d_assets.floor = world_3d_load_model(root + "floor-square.glb")
	world_3d_assets.character = world_3d_load_model(root + WORLD_3D_CHARACTER_MODEL)
	world_3d_assets.crate = world_3d_load_model(root + "crate-color.glb")
	world_3d_assets.pressure_pad = world_3d_load_model(root + WORLD_3D_PRESSURE_PAD_MODEL)
	world_3d_assets.cube = world_3d_load_model(root + "shape-cube.glb")
	world_3d_assets.wall = world_3d_load_model(root + "wall.glb")
	world_3d_assets.doorway_wall = world_3d_load_model(root + "wall-doorway-wide.glb")
	world_3d_assets.door_indicator = world_3d_load_model(root + "indicator-doorway.glb")
	world_3d_assets.character_bounds = rl.GetModelBoundingBox(world_3d_assets.character)
	world_3d_assets.crate_bounds = rl.GetModelBoundingBox(world_3d_assets.crate)
	world_3d_assets.pressure_pad_bounds = rl.GetModelBoundingBox(world_3d_assets.pressure_pad)
	vertex_shader_path := asset.path("shaders/world_lighting.vs")
	defer delete(vertex_shader_path)
	skinned_vertex_shader_path := asset.path("shaders/world_lighting_skinned.vs")
	defer delete(skinned_vertex_shader_path)
	fragment_shader_path := asset.path("shaders/world_lighting.fs")
	defer delete(fragment_shader_path)
	world_3d_assets.lighting_shader = rl.LoadShader(
		cstring(raw_data(vertex_shader_path)),
		cstring(raw_data(fragment_shader_path)),
	)
	world_3d_assets.character_lighting_shader = rl.LoadShader(
		cstring(raw_data(skinned_vertex_shader_path)),
		cstring(raw_data(fragment_shader_path)),
	)
	world_3d_assets.active_character_shader = world_3d_assets.lighting_shader
	if world_3d_uses_gpu_skinning(&world_3d_assets.character) {
		world_3d_assets.active_character_shader = world_3d_assets.character_lighting_shader
	}
	world_3d_assets.character_flash_location = rl.GetShaderLocation(
		world_3d_assets.active_character_shader,
		"flashAmount",
	)

	world_3d_apply_shader(&world_3d_assets.floor, world_3d_assets.lighting_shader)
	world_3d_apply_shader(&world_3d_assets.character, world_3d_assets.active_character_shader)
	world_3d_apply_shader(&world_3d_assets.crate, world_3d_assets.lighting_shader)
	world_3d_apply_shader(&world_3d_assets.pressure_pad, world_3d_assets.active_character_shader)
	world_3d_apply_shader(&world_3d_assets.cube, world_3d_assets.lighting_shader)
	world_3d_apply_shader(&world_3d_assets.wall, world_3d_assets.lighting_shader)
	world_3d_apply_shader(&world_3d_assets.doorway_wall, world_3d_assets.lighting_shader)
	world_3d_apply_shader(&world_3d_assets.door_indicator, world_3d_assets.lighting_shader)

	world_3d_configure_lighting(world_3d_assets.lighting_shader)
	world_3d_configure_lighting(world_3d_assets.character_lighting_shader)

	for &index in world_3d_assets.character_animation_indices do index = -1
	path := asset.path(root + WORLD_3D_CHARACTER_MODEL)
	defer delete(path)
	world_3d_assets.character_animations = rl.LoadModelAnimations(
		cstring(raw_data(path)),
		&world_3d_assets.character_animation_count,
	)
	clip_names := WORLD_3D_CHARACTER_CLIP_NAMES
	for &clip_index, state_index in world_3d_assets.character_animation_indices {
		clip_name := clip_names[state_index]
		for animation_index in 0 ..< int(world_3d_assets.character_animation_count) {
			animation := &world_3d_assets.character_animations[animation_index]
			if string(cstring(&animation.name[0])) == clip_name {
				clip_index = animation_index
				break
			}
		}
	}

	for &index in world_3d_assets.pressure_pad_animation_indices do index = -1
	pressure_pad_path := asset.path(root + WORLD_3D_PRESSURE_PAD_MODEL)
	defer delete(pressure_pad_path)
	world_3d_assets.pressure_pad_animations = rl.LoadModelAnimations(
		cstring(raw_data(pressure_pad_path)),
		&world_3d_assets.pressure_pad_animation_count,
	)
	pressure_pad_clip_names := WORLD_3D_PRESSURE_PAD_CLIP_NAMES
	for &clip_index, state_index in world_3d_assets.pressure_pad_animation_indices {
		clip_name := pressure_pad_clip_names[state_index]
		for animation_index in 0 ..< int(world_3d_assets.pressure_pad_animation_count) {
			animation := &world_3d_assets.pressure_pad_animations[animation_index]
			if string(cstring(&animation.name[0])) == clip_name {
				clip_index = animation_index
				break
			}
		}
	}
}

world_3d_fini :: proc() {
	if world_3d_assets.character_animation_count > 0 {
		rl.UnloadModelAnimations(
			world_3d_assets.character_animations,
			world_3d_assets.character_animation_count,
		)
	}
	if world_3d_assets.pressure_pad_animation_count > 0 {
		rl.UnloadModelAnimations(
			world_3d_assets.pressure_pad_animations,
			world_3d_assets.pressure_pad_animation_count,
		)
	}
	if world_3d_assets.floor.meshCount > 0 do rl.UnloadModel(world_3d_assets.floor)
	if world_3d_assets.character.meshCount > 0 do rl.UnloadModel(world_3d_assets.character)
	if world_3d_assets.crate.meshCount > 0 do rl.UnloadModel(world_3d_assets.crate)
	if world_3d_assets.pressure_pad.meshCount > 0 do rl.UnloadModel(world_3d_assets.pressure_pad)
	if world_3d_assets.cube.meshCount > 0 do rl.UnloadModel(world_3d_assets.cube)
	if world_3d_assets.wall.meshCount > 0 do rl.UnloadModel(world_3d_assets.wall)
	if world_3d_assets.doorway_wall.meshCount > 0 do rl.UnloadModel(world_3d_assets.doorway_wall)
	if world_3d_assets.door_indicator.meshCount > 0 do rl.UnloadModel(world_3d_assets.door_indicator)
	if rl.IsShaderValid(world_3d_assets.character_lighting_shader) {
		rl.UnloadShader(world_3d_assets.character_lighting_shader)
	}
	if rl.IsShaderValid(world_3d_assets.lighting_shader) do rl.UnloadShader(world_3d_assets.lighting_shader)
	world_3d_assets = {}
}

world_3d_position :: proc(position: Vec2, height: f32 = 0) -> rl.Vector3 {
	return {position.x, height, position.y}
}

world_3d_collider_from_bounds :: proc(
	bounds: rl.BoundingBox,
	scale: f32,
	rotation_invariant: bool,
	solid: bool,
) -> Collider {
	min_x := bounds.min.x * scale
	max_x := bounds.max.x * scale
	min_z := bounds.min.z * scale
	max_z := bounds.max.z * scale
	if rotation_invariant {
		radius := max(max(abs(min_x), abs(max_x)), max(abs(min_z), abs(max_z)))
		min_x, max_x = -radius, radius
		min_z, max_z = -radius, radius
	}
	return {
		size = {max_x - min_x, max_z - min_z},
		offset = {min_x, min_z},
		height = (bounds.max.y - bounds.min.y) * scale,
		vertical_offset = bounds.min.y * scale,
		solid = solid,
	}
}

world_3d_character_collider :: proc(solid: bool) -> Collider {
	return world_3d_collider_from_bounds(
		world_3d_assets.character_bounds,
		WORLD_3D_CHARACTER_SCALE,
		true,
		solid,
	)
}

world_3d_crate_collider :: proc(solid: bool) -> Collider {
	return world_3d_collider_from_bounds(
		world_3d_assets.crate_bounds,
		WORLD_3D_CRATE_SCALE,
		false,
		solid,
	)
}

world_3d_pressure_pad_collider :: proc(solid: bool) -> Collider {
	return world_3d_collider_from_bounds(
		world_3d_assets.pressure_pad_bounds,
		WORLD_3D_PRESSURE_PAD_SCALE,
		false,
		solid,
	)
}

world_3d_grounded_position :: proc(
	position: Vec2,
	bounds: rl.BoundingBox,
	scale: f32,
	base_height: f32 = 0,
) -> rl.Vector3 {
	return world_3d_position(position, base_height - bounds.min.y * scale)
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

			if !world_3d_has_floor(x, y - 1) &&
			   !world_3d_edge_is_door({center_x, f32(y) * tile_size}) {
				rl.DrawModelEx(
					world_3d_assets.wall,
					{center_x, 0, f32(y) * tile_size},
					{0, 1, 0},
					90,
					{wall_thickness / 0.2, wall_height, tile_size},
					wall_color,
				)
			}
			if !world_3d_has_floor(x, y + 1) &&
			   !world_3d_edge_is_door({center_x, f32(y + 1) * tile_size}) {
				rl.DrawModelEx(
					world_3d_assets.wall,
					{center_x, 0, f32(y + 1) * tile_size},
					{0, 1, 0},
					90,
					{wall_thickness / 0.2, wall_height, tile_size},
					wall_color,
				)
			}
			if !world_3d_has_floor(x - 1, y) &&
			   !world_3d_edge_is_door({f32(x) * tile_size, center_z}) {
				rl.DrawModelEx(
					world_3d_assets.wall,
					{f32(x) * tile_size, 0, center_z},
					{0, 1, 0},
					0,
					{wall_thickness / 0.2, wall_height, tile_size},
					wall_color,
				)
			}
			if !world_3d_has_floor(x + 1, y) &&
			   !world_3d_edge_is_door({f32(x + 1) * tile_size, center_z}) {
				rl.DrawModelEx(
					world_3d_assets.wall,
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

world_3d_draw_ground :: proc() {
	tm := room_get_current()
	if tm == nil do return

	tile_size := f32(tilemap.get_tile_size())
	for y in 0 ..< tilemap.get_tilemap_height() {
		for x in 0 ..< tilemap.get_tilemap_width() {
			tile := tilemap.get_base_tile(x, y)
			if tile == nil || tile^ == .EMPTY do continue

			rl.DrawModelEx(
				world_3d_assets.floor,
				{(f32(x) + 0.5) * tile_size, 0, (f32(y) + 0.5) * tile_size},
				{0, 1, 0},
				0,
				{tile_size, 1, tile_size},
				rl.WHITE,
			)
		}
	}

	for structure in tm.structures do world_3d_draw_house(structure.position, structure.size)
}

world_3d_draw_house :: proc(position, size: Vec2) {
	center := position + size / 2
	wall_height: f32 = 44
	wall_thickness: f32 = 8
	// Kenney's wide doorway wall spans 1.5 model units along its local Z axis.
	rl.DrawModelEx(
		world_3d_assets.doorway_wall,
		{center.x, 0, position.y + size.y},
		{0, 1, 0},
		90,
		{wall_thickness, wall_height, size.x / 1.5},
		rl.WHITE,
	)
	rl.DrawModelEx(
		world_3d_assets.wall,
		{center.x, 0, position.y},
		{0, 1, 0},
		90,
		{wall_thickness, wall_height, size.x},
		rl.WHITE,
	)
	rl.DrawModelEx(
		world_3d_assets.wall,
		{position.x, 0, center.y},
		{0, 1, 0},
		0,
		{wall_thickness, wall_height, size.y},
		rl.WHITE,
	)
	rl.DrawModelEx(
		world_3d_assets.wall,
		{position.x + size.x, 0, center.y},
		{0, 1, 0},
		0,
		{wall_thickness, wall_height, size.y},
		rl.WHITE,
	)
	rl.DrawModelEx(
		world_3d_assets.cube,
		{center.x, wall_height, center.y},
		{0, 1, 0},
		0,
		{size.x + 8, 7, size.y + 8},
		rl.Color{120, 150, 105, 255},
	)
}

world_3d_facing_angle :: proc(direction: Vec2) -> f32 {
	return math.to_degrees(math.atan2(direction.x, direction.y))
}

world_3d_clip_frame :: proc(
	visual_time: f32,
	clip: rl.ModelAnimation,
	playback: Animation_Playback,
) -> f32 {
	return animation_frame_at_time(visual_time, int(clip.keyframeCount), playback)
}

world_3d_draw_character :: proc(
	anim: ^Animator,
	position, facing: Vec2,
	tint: rl.Color,
	flash_amount: f32,
) {
	state_index := int(anim.current_anim)
	clip_index := -1
	if state_index >= 0 && state_index < len(world_3d_assets.character_animation_indices) {
		clip_index = world_3d_assets.character_animation_indices[state_index]
	}
	if clip_index >= 0 && state_index < len(anim.frame_counts) {
		playback_modes := WORLD_3D_CHARACTER_PLAYBACK
		clip := world_3d_assets.character_animations[clip_index]
		clip_frame := world_3d_clip_frame(anim.visual_time, clip, playback_modes[state_index])
		previous_state_index := int(anim.previous_anim)
		previous_clip_index := -1
		if previous_state_index >= 0 &&
		   previous_state_index < len(world_3d_assets.character_animation_indices) {
			previous_clip_index = world_3d_assets.character_animation_indices[previous_state_index]
		}
		blend := min(anim.blend_elapsed / WORLD_3D_CHARACTER_BLEND_DURATION, 1)
		if blend < 1 && previous_clip_index >= 0 {
			previous_clip := world_3d_assets.character_animations[previous_clip_index]
			previous_frame := world_3d_clip_frame(
				anim.previous_time,
				previous_clip,
				playback_modes[previous_state_index],
			)
			rl.UpdateModelAnimationEx(
				world_3d_assets.character,
				previous_clip,
				previous_frame,
				clip,
				clip_frame,
				blend,
			)
		} else {
			rl.UpdateModelAnimation(world_3d_assets.character, clip, clip_frame)
		}
	}
	flash := min(max(flash_amount, 0), 1)
	rl.SetShaderValue(
		world_3d_assets.active_character_shader,
		world_3d_assets.character_flash_location,
		&flash,
		.FLOAT,
	)
	rl.DrawModelEx(
		world_3d_assets.character,
		world_3d_grounded_position(
			position,
			world_3d_assets.character_bounds,
			WORLD_3D_CHARACTER_SCALE,
		),
		{0, 1, 0},
		world_3d_facing_angle(facing),
		{WORLD_3D_CHARACTER_SCALE, WORLD_3D_CHARACTER_SCALE, WORLD_3D_CHARACTER_SCALE},
		tint,
	)
	flash = 0
	rl.SetShaderValue(
		world_3d_assets.active_character_shader,
		world_3d_assets.character_flash_location,
		&flash,
		.FLOAT,
	)
}

world_3d_draw_entities :: proc() {
	for &entity in entities {
		switch &e in entity {
		case Player:
			tint :=
				e.index == .PLAYER_1 ? rl.Color{92, 156, 214, 255} : rl.Color{102, 190, 132, 255}
			world_3d_draw_character(
				&e.anim_data,
				e.position,
				e.facing_direction,
				tint,
				e.hit_flash_timer / 0.2,
			)
		case Enemy:
			tint := rl.Color{196, 92, 88, 255}
			world_3d_draw_character(
				&e.anim_data,
				e.position,
				e.facing_direction,
				tint,
				e.hit_flash_timer / 0.2,
			)
		case NPC:
			tint := rl.Color{220, 190, 96, 255}
			world_3d_draw_character(
				&e.anim_data,
				e.position,
				e.facing_direction,
				tint,
				e.hit_flash_timer / 0.2,
			)
		case Holdable:
			base_height: f32 = 0
			if e.held_by != nil {
				base_height = WORLD_3D_CARRIED_ITEM_HEIGHT
			}
			rl.DrawModelEx(
				world_3d_assets.crate,
				world_3d_grounded_position(
					e.held_by != nil ? e.held_by.position : e.position,
					world_3d_assets.crate_bounds,
					WORLD_3D_CRATE_SCALE,
					base_height,
				),
				{0, 1, 0},
				0,
				{WORLD_3D_CRATE_SCALE, WORLD_3D_CRATE_SCALE, WORLD_3D_CRATE_SCALE},
				rl.WHITE,
			)
		case Pressure_Plate:
			state_index := e.active ? 1 : 0
			clip_index := world_3d_assets.pressure_pad_animation_indices[state_index]
			if clip_index >= 0 {
				clip := world_3d_assets.pressure_pad_animations[clip_index]
				clip_frame := world_3d_clip_frame(e.animation_time, clip, .ONCE_HOLD)
				rl.UpdateModelAnimation(world_3d_assets.pressure_pad, clip, clip_frame)
			}
			rl.DrawModelEx(
				world_3d_assets.pressure_pad,
				world_3d_grounded_position(
					e.position,
					world_3d_assets.pressure_pad_bounds,
					WORLD_3D_PRESSURE_PAD_SCALE,
				),
				{0, 1, 0},
				0,
				{
					WORLD_3D_PRESSURE_PAD_SCALE,
					WORLD_3D_PRESSURE_PAD_SCALE,
					WORLD_3D_PRESSURE_PAD_SCALE,
				},
				rl.WHITE,
			)
		case Gate:
			if e.open do continue
			block_size: f32 = 16
			for y in 0 ..< int(e.collider.size.y / block_size) {
				for x in 0 ..< int(e.collider.size.x / block_size) {
					rl.DrawModelEx(
						world_3d_assets.cube,
						{
							e.position.x + (f32(x) + 0.5) * block_size,
							0,
							e.position.y + (f32(y) + 0.5) * block_size,
						},
						{0, 1, 0},
						0,
						{block_size, WORLD_3D_GATE_HEIGHT, block_size},
						rl.Color{120, 130, 136, 255},
					)
				}
			}
		case Door:
			collider_position := e.position + e.collider.offset
			center := collider_position + e.collider.size / 2
			rl.DrawModelEx(
				world_3d_assets.door_indicator,
				world_3d_position(center, 0.2),
				{0, 1, 0},
				0,
				{e.collider.size.x / 0.6, 1, e.collider.size.y / 0.6},
				rl.Color{142, 104, 190, 255},
			)
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

world_3d_scaled_text_size :: proc(design_size: int, screen_scale: f32) -> int {
	return max(int(f32(design_size) * screen_scale + 0.5), 1)
}

world_3d_draw_label :: proc(
	text: string,
	world_position: rl.Vector3,
	camera_3d: rl.Camera3D,
	color: renderer.Colour,
) {
	position := rl.GetWorldToScreen(world_position, camera_3d)
	text_size := world_3d_scaled_text_size(WORLD_3D_LABEL_TEXT_SIZE, window.get_ui_scale())
	text_width := int(renderer.measure_text(text, i32(text_size)))
	renderer.draw_text(
		text,
		int(position.x) - text_width / 2,
		int(position.y) - text_size / 2,
		text_size,
		color = color,
	)
}

world_3d_draw_labels :: proc(camera_3d: rl.Camera3D) {
	if game.player_count != 2 do return
	players := entity_get_players()
	defer delete(players)
	for player in players {
		label := player.index == .PLAYER_1 ? "P1" : "P2"
		color := player.index == .PLAYER_1 ? renderer.BLUE : renderer.GREEN
		world_3d_draw_label(label, world_3d_position(player.position, 24), camera_3d, color)
	}
}

when ODIN_DEBUG {
	world_3d_draw_editor_entities :: proc() {
		for entity in tilemap.get_entities() {
			position := rl.Vector3{f32(entity.x), 4, f32(entity.y)}
			color: rl.Color
			switch entity.entity_type {
			case .PLAYER: color = rl.BLUE
			case .ENEMY: color = rl.RED
			case .NPC: color = rl.GOLD
			case .HOLDABLE: color = rl.ORANGE
			case .PRESSURE_PLATE: color = rl.GRAY
			case .GATE: color = rl.BROWN
			case .DOOR: color = rl.PURPLE
			}
			rl.DrawCubeV(position, {8, 8, 8}, color)
			rl.DrawCubeWiresV(position, {8, 8, 8}, rl.WHITE)
		}
	}

	world_3d_draw_editor_cursor :: proc() {
		if !editor_state.cursor_visible do return
		tile_size := f32(tilemap.get_tile_size())
		center := rl.Vector3 {
			(f32(editor_state.cursor_x) + 0.5) * tile_size,
			1,
			(f32(editor_state.cursor_y) + 0.5) * tile_size,
		}
		color := editor_state.selected_layer == .COLLISION ? rl.RED : rl.WHITE
		rl.DrawCubeWiresV(center, {tile_size, 2, tile_size}, color)
	}

	world_3d_draw_editor :: proc() {
		rl.ClearBackground({12, 14, 18, 255})
		camera_3d := world_3d_camera()
		rl.BeginMode3D(camera_3d)
		world_3d_draw_ground()
		world_3d_draw_interior_walls()
		world_3d_draw_editor_entities()
		world_3d_draw_debug()
		world_3d_draw_editor_cursor()
		rl.EndMode3D()
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
			height := max(entity_get_collider_height(&entity), 0.25)
			center := rl.Vector3 {
				collider_pos.x + collider_size.x / 2,
				entity_get_collider_vertical_offset(&entity) + height / 2 + 0.01,
				collider_pos.y + collider_size.y / 2,
			}
			rl.DrawCubeWiresV(center, {collider_size.x, height, collider_size.y}, color)
		}
	}

	world_3d_draw_debug_labels :: proc(camera_3d: rl.Camera3D) {
		doors := entity_get_doors()
		defer delete(doors)
		for door in doors {
			center := door.position + door.collider.size / 2
			world_3d_draw_label(
				door.target_room,
				world_3d_position(center, 4),
				camera_3d,
				renderer.PURPLE,
			)
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
