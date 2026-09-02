package hollie

import "core:c"
import "core:math"
import rl "vendor:raylib"

WORLD_3D_SHADOW_MAP_RESOLUTION :: 1024
WORLD_3D_SHADOW_MARGIN :: f32(64)

world_3d_apply_lighting_shaders :: proc() {
	world_3d_apply_shader(&world_3d_assets.floor, world_3d_assets.lighting_shader)
	world_3d_apply_shader(&world_3d_assets.character, world_3d_assets.active_character_shader)
	world_3d_apply_shader(&world_3d_assets.crate, world_3d_assets.lighting_shader)
	world_3d_apply_shader(&world_3d_assets.pressure_pad, world_3d_assets.active_character_shader)
	world_3d_apply_shader(&world_3d_assets.cube, world_3d_assets.lighting_shader)
	world_3d_apply_shader(&world_3d_assets.wall, world_3d_assets.lighting_shader)
	world_3d_apply_shader(&world_3d_assets.doorway_wall, world_3d_assets.lighting_shader)
	world_3d_apply_shader(&world_3d_assets.door_indicator, world_3d_assets.lighting_shader)
}

world_3d_apply_shadow_shaders :: proc() {
	world_3d_apply_shader(&world_3d_assets.floor, world_3d_assets.shadow_shader)
	character_shader := world_3d_assets.shadow_shader
	if world_3d_uses_gpu_skinning(&world_3d_assets.character) {
		character_shader = world_3d_assets.shadow_skinned_shader
	}
	world_3d_apply_shader(&world_3d_assets.character, character_shader)
	world_3d_apply_shader(&world_3d_assets.crate, world_3d_assets.shadow_shader)
	pressure_pad_shader := world_3d_assets.shadow_shader
	if world_3d_uses_gpu_skinning(&world_3d_assets.pressure_pad) {
		pressure_pad_shader = world_3d_assets.shadow_skinned_shader
	}
	world_3d_apply_shader(&world_3d_assets.pressure_pad, pressure_pad_shader)
	world_3d_apply_shader(&world_3d_assets.cube, world_3d_assets.shadow_shader)
	world_3d_apply_shader(&world_3d_assets.wall, world_3d_assets.shadow_shader)
	world_3d_apply_shader(&world_3d_assets.doorway_wall, world_3d_assets.shadow_shader)
	world_3d_apply_shader(&world_3d_assets.door_indicator, world_3d_assets.shadow_shader)
}

world_3d_load_shadow_map :: proc() -> rl.RenderTexture2D {
	target: rl.RenderTexture2D
	target.id = LoadFramebuffer()
	target.texture.width = WORLD_3D_SHADOW_MAP_RESOLUTION
	target.texture.height = WORLD_3D_SHADOW_MAP_RESOLUTION
	target.depth.width = WORLD_3D_SHADOW_MAP_RESOLUTION
	target.depth.height = WORLD_3D_SHADOW_MAP_RESOLUTION
	target.depth.mipmaps = 1
	target.depth.format = rl.PixelFormat(19)
	assert(target.id > 0, "could not create shadow framebuffer")

	EnableFramebuffer(target.id)
	target.depth.id = LoadTextureDepth(
		WORLD_3D_SHADOW_MAP_RESOLUTION,
		WORLD_3D_SHADOW_MAP_RESOLUTION,
		false,
	)
	FramebufferAttach(target.id, target.depth.id, RL_ATTACHMENT_DEPTH, RL_ATTACHMENT_TEXTURE2D, 0)
	assert(FramebufferComplete(target.id), "shadow framebuffer is incomplete")
	DisableFramebuffer()
	return target
}

world_3d_init_shadows :: proc() {
	world_3d_assets.shadow_map = world_3d_load_shadow_map()
	resolution := c.int(WORLD_3D_SHADOW_MAP_RESOLUTION)
	shaders := [2]rl.Shader {
		world_3d_assets.lighting_shader,
		world_3d_assets.character_lighting_shader,
	}
	for shader in shaders {
		location := rl.GetShaderLocation(shader, "shadowMapResolution")
		rl.SetShaderValue(shader, location, &resolution, .INT)
	}
}

world_3d_fini_shadows :: proc() {
	if world_3d_assets.shadow_map.id > 0 {
		UnloadFramebuffer(world_3d_assets.shadow_map.id)
		world_3d_assets.shadow_map = {}
	}
}

world_3d_light_camera :: proc(camera_3d: rl.Camera3D) -> rl.Camera3D {
	direction := WORLD_3D_LIGHT_DIRECTION
	length := math.sqrt(
		direction.x * direction.x + direction.y * direction.y + direction.z * direction.z,
	)
	direction.x /= length
	direction.y /= length
	direction.z /= length
	aspect := f32(rl.GetScreenWidth()) / max(f32(rl.GetScreenHeight()), 1)
	coverage := max(camera_3d.fovy, camera_3d.fovy * aspect) + WORLD_3D_SHADOW_MARGIN
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

world_3d_bind_shadow_map :: proc(shader: rl.Shader) {
	// Match raylib's shadow-map example: reserve a texture unit outside material maps.
	texture_slot := c.int(10)
	location := rl.GetShaderLocation(shader, "shadowMap")
	EnableShader(shader.id)
	ActiveTextureSlot(texture_slot)
	EnableTexture(world_3d_assets.shadow_map.depth.id)
	SetUniform(location, &texture_slot, c.int(rl.ShaderUniformDataType.INT), 1)
}

world_3d_bind_shadow_map_for_world :: proc() {
	shaders := [2]rl.Shader {
		world_3d_assets.lighting_shader,
		world_3d_assets.character_lighting_shader,
	}
	for shader in shaders {
		location := rl.GetShaderLocation(shader, "lightVP")
		rl.SetShaderValueMatrix(shader, location, world_3d_assets.light_view_projection)
		world_3d_bind_shadow_map(shader)
	}
	ActiveTextureSlot(0)
}

world_3d_render_shadow_map :: proc(camera_3d: rl.Camera3D) {
	world_3d_apply_shadow_shaders()
	light_camera := world_3d_light_camera(camera_3d)
	light_view := rl.GetCameraViewMatrix(&light_camera)
	light_projection := rl.GetCameraProjectionMatrix(&light_camera, 1)

	rl.BeginTextureMode(world_3d_assets.shadow_map)
	rl.ClearBackground(rl.WHITE)
	rl.BeginMode3D(light_camera)
	world_3d_draw_ground()
	world_3d_draw_interior_walls()
	world_3d_draw_entities()
	rl.EndMode3D()
	rl.EndTextureMode()

	world_3d_apply_lighting_shaders()
	// Odin's matrix operators use GLSL column-vector order, so projection comes first.
	world_3d_assets.light_view_projection = light_projection * light_view
}
