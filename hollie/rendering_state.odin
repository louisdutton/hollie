package hollie

import "asset"
import "core:c"
import rl "vendor:raylib"

Rendering_State :: struct {
	lighting_shader:           rl.Shader,
	character_lighting_shader: rl.Shader,
	active_character_shader:   rl.Shader,
	shadow_shader:             rl.Shader,
	shadow_skinned_shader:     rl.Shader,
	character_flash_location:  c.int,
	shadow_map:                rl.RenderTexture2D,
	light_view_projection:     rl.Matrix,
}

rendering_state: Rendering_State

rendering_apply_shader :: proc(model: ^rl.Model, shader: rl.Shader) {
	for material_index in 0 ..< int(model.materialCount) {
		model.materials[material_index].shader = shader
	}
}

rendering_set_shader_vec3 :: proc(shader: rl.Shader, name: cstring, value: rl.Vector3) {
	location := rl.GetShaderLocation(shader, name)
	uniform_value := value
	rl.SetShaderValue(shader, location, &uniform_value, .VEC3)
}

rendering_configure_lighting :: proc(shader: rl.Shader) {
	rendering_set_shader_vec3(shader, "ambientColor", {0.22, 0.23, 0.32})
	rendering_set_shader_vec3(shader, "keyDirection", RENDERING_LIGHT_DIRECTION)
	rendering_set_shader_vec3(shader, "keyColor", {0.6, 0.56, 0.52})
	rendering_set_shader_vec3(shader, "fillDirection", {0.65, -0.35, 0.55})
	rendering_set_shader_vec3(shader, "fillColor", {0.07, 0.09, 0.13})
}

rendering_init :: proc() {
	vertex_shader_path := asset.path("shaders/world_lighting.vs")
	defer delete(vertex_shader_path)
	skinned_vertex_shader_path := asset.path("shaders/world_lighting_skinned.vs")
	defer delete(skinned_vertex_shader_path)
	fragment_shader_path := asset.path("shaders/world_lighting.fs")
	defer delete(fragment_shader_path)
	rendering_state.lighting_shader = rl.LoadShader(
		cstring(raw_data(vertex_shader_path)),
		cstring(raw_data(fragment_shader_path)),
	)
	rendering_state.character_lighting_shader = rl.LoadShader(
		cstring(raw_data(skinned_vertex_shader_path)),
		cstring(raw_data(fragment_shader_path)),
	)
	shadow_vertex_shader_path := asset.path("shaders/world_shadow.vs")
	defer delete(shadow_vertex_shader_path)
	shadow_skinned_vertex_shader_path := asset.path("shaders/world_shadow_skinned.vs")
	defer delete(shadow_skinned_vertex_shader_path)
	shadow_fragment_shader_path := asset.path("shaders/world_shadow.fs")
	defer delete(shadow_fragment_shader_path)
	rendering_state.shadow_shader = rl.LoadShader(
		cstring(raw_data(shadow_vertex_shader_path)),
		cstring(raw_data(shadow_fragment_shader_path)),
	)
	rendering_state.shadow_skinned_shader = rl.LoadShader(
		cstring(raw_data(shadow_skinned_vertex_shader_path)),
		cstring(raw_data(shadow_fragment_shader_path)),
	)
	rendering_state.active_character_shader = rendering_state.lighting_shader
	if model_uses_gpu_skinning(&model_assets.character) {
		rendering_state.active_character_shader = rendering_state.character_lighting_shader
	}
	rendering_state.character_flash_location = rl.GetShaderLocation(
		rendering_state.active_character_shader,
		"flashAmount",
	)
	shadow_map_apply_lighting_shaders()
	rendering_configure_lighting(rendering_state.lighting_shader)
	rendering_configure_lighting(rendering_state.character_lighting_shader)
	shadow_map_init()
}

rendering_prepare :: proc() {
	shadow_map_render(rendering_camera())
}

rendering_fini :: proc() {
	shadow_map_fini()
	if rl.IsShaderValid(rendering_state.character_lighting_shader) {
		rl.UnloadShader(rendering_state.character_lighting_shader)
	}
	if rl.IsShaderValid(rendering_state.shadow_skinned_shader) {
		rl.UnloadShader(rendering_state.shadow_skinned_shader)
	}
	if rl.IsShaderValid(rendering_state.shadow_shader) do rl.UnloadShader(rendering_state.shadow_shader)
	if rl.IsShaderValid(rendering_state.lighting_shader) do rl.UnloadShader(rendering_state.lighting_shader)
	rendering_state = {}
}
