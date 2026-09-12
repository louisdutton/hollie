package hollie

import "core:c"
import "core:math"
import "graphics"

RENDERING_SHADOW_MAP_RESOLUTION :: 1024 // width and height of the shadow-map texture
RENDERING_SHADOW_MARGIN :: f32(64) // extra world-space coverage around the camera view

shadow_map_apply_lighting_shaders :: proc() {
	animal_models_apply_shader(false)
	rendering_apply_shader(&model_assets.floor, rendering_state.lighting_shader)
	rendering_apply_shader(&model_assets.character, rendering_state.active_character_shader)
	rendering_apply_shader(&model_assets.crate, rendering_state.lighting_shader)
	rendering_apply_shader(&model_assets.pressure_pad, rendering_state.active_character_shader)
	rendering_apply_shader(&model_assets.cube, rendering_state.lighting_shader)
	rendering_apply_shader(&model_assets.wall, rendering_state.lighting_shader)
	rendering_apply_shader(&model_assets.doorway_wall, rendering_state.lighting_shader)
}

shadow_map_apply_shaders :: proc() {
	animal_models_apply_shader(true)
	rendering_apply_shader(&model_assets.floor, rendering_state.shadow_shader)
	character_shader := rendering_state.shadow_shader
	if graphics.model_uses_gpu_skinning(&model_assets.character) {
		character_shader = rendering_state.shadow_skinned_shader
	}
	rendering_apply_shader(&model_assets.character, character_shader)
	rendering_apply_shader(&model_assets.crate, rendering_state.shadow_shader)
	pressure_pad_shader := rendering_state.shadow_shader
	if graphics.model_uses_gpu_skinning(&model_assets.pressure_pad) {
		pressure_pad_shader = rendering_state.shadow_skinned_shader
	}
	rendering_apply_shader(&model_assets.pressure_pad, pressure_pad_shader)
	rendering_apply_shader(&model_assets.cube, rendering_state.shadow_shader)
	rendering_apply_shader(&model_assets.wall, rendering_state.shadow_shader)
	rendering_apply_shader(&model_assets.doorway_wall, rendering_state.shadow_shader)
}

shadow_map_load :: proc() -> graphics.Render_Texture2D {
	target: graphics.Render_Texture2D
	target.id = graphics.load_framebuffer()
	target.texture.width = RENDERING_SHADOW_MAP_RESOLUTION
	target.texture.height = RENDERING_SHADOW_MAP_RESOLUTION
	target.depth.width = RENDERING_SHADOW_MAP_RESOLUTION
	target.depth.height = RENDERING_SHADOW_MAP_RESOLUTION
	target.depth.mipmaps = 1
	target.depth.format = graphics.Pixel_Format(19)
	assert(target.id > 0, "could not create shadow framebuffer")

	graphics.enable_framebuffer(target.id)
	target.depth.id = graphics.load_texture_depth(
		RENDERING_SHADOW_MAP_RESOLUTION,
		RENDERING_SHADOW_MAP_RESOLUTION,
		false,
	)
	graphics.framebuffer_attach(
		target.id,
		target.depth.id,
		graphics.RL_ATTACHMENT_DEPTH,
		graphics.RL_ATTACHMENT_TEXTURE2D,
		0,
	)
	assert(graphics.framebuffer_complete(target.id), "shadow framebuffer is incomplete")
	graphics.disable_framebuffer()
	return target
}

shadow_map_init :: proc() {
	rendering_state.shadow_map = shadow_map_load()
	resolution := c.int(RENDERING_SHADOW_MAP_RESOLUTION)
	shaders := [2]graphics.Shader {
		rendering_state.lighting_shader,
		rendering_state.character_lighting_shader,
	}
	for shader in shaders {
		location := graphics.get_shader_location(shader, "shadowMapResolution")
		graphics.set_shader_int(shader, location, &resolution)
	}
}

shadow_map_fini :: proc() {
	if rendering_state.shadow_map.id > 0 {
		graphics.unload_framebuffer(rendering_state.shadow_map.id)
		rendering_state.shadow_map = {}
	}
}

shadow_map_camera :: proc(camera_3d: graphics.Camera3D) -> graphics.Camera3D {
	direction := RENDERING_LIGHT_DIRECTION
	length := math.sqrt(
		direction.x * direction.x + direction.y * direction.y + direction.z * direction.z,
	)
	direction.x /= length
	direction.y /= length
	direction.z /= length
	aspect := f32(graphics.get_screen_width()) / max(f32(graphics.get_screen_height()), 1)
	coverage := max(camera_3d.fovy, camera_3d.fovy * aspect) + RENDERING_SHADOW_MARGIN
	return {
		position = {
			camera_3d.target.x - direction.x * coverage,
			camera_3d.target.y - direction.y * coverage,
			camera_3d.target.z - direction.z * coverage,
		},
		target = camera_3d.target,
		up = {0, 1, 0},
		fovy = coverage,
		projection = .ORTHOGRAPHIC,
	}
}

shadow_map_bind :: proc(shader: graphics.Shader) {
	// Match raylib's shadow-map example: reserve a texture unit outside material maps.
	texture_slot := c.int(10)
	location := graphics.get_shader_location(shader, "shadowMap")
	graphics.enable_shader(shader.id)
	graphics.active_texture_slot(texture_slot)
	graphics.enable_texture(rendering_state.shadow_map.depth.id)
	graphics.set_uniform(location, &texture_slot, graphics.SHADER_UNIFORM_INT, 1)
}

shadow_map_bind_for_rendering :: proc() {
	shaders := [2]graphics.Shader {
		rendering_state.lighting_shader,
		rendering_state.character_lighting_shader,
	}
	for shader in shaders {
		location := graphics.get_shader_location(shader, "lightVP")
		graphics.set_shader_matrix(shader, location, rendering_state.light_view_projection)
		shadow_map_bind(shader)
	}
	graphics.active_texture_slot(0)
}

shadow_map_render :: proc(camera_3d: graphics.Camera3D) {
	shadow_map_apply_shaders()
	light_camera := shadow_map_camera(camera_3d)
	light_view := graphics.get_camera_view_matrix(&light_camera)
	light_projection := graphics.get_camera_projection_matrix(&light_camera, 1)

	graphics.begin_render_texture(rendering_state.shadow_map)
	graphics.clear_background(graphics.WHITE)
	graphics.begin_mode_3d(light_camera)
	rendering_draw_ground()
	rendering_draw_interior_walls()
	rendering_draw_entities()
	graphics.end_mode_3d()
	graphics.end_render_texture()

	shadow_map_apply_lighting_shaders()
	// Odin's matrix operators use GLSL column-vector order, so projection comes first.
	rendering_state.light_view_projection = light_projection * light_view
}
