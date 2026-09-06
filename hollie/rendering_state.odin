package hollie

import "asset"
import "core:c"
import "renderer"

RENDERING_GATE_HEIGHT :: f32(18)
RENDERING_CARRIED_ITEM_HEIGHT :: f32(20)
RENDERING_CHARACTER_BLEND_DURATION :: f32(0.12) // seconds used to blend between character animations
RENDERING_LABEL_TEXT_SIZE :: 12
RENDERING_BACKGROUND_COLOR :: renderer.Colour{54, 54, 60, 255}
RENDERING_LIGHT_DIRECTION :: renderer.Vec3{-0.5, -0.7, 0.5}

Rendering_State :: struct {
	lighting_shader:           renderer.Shader,
	character_lighting_shader: renderer.Shader,
	active_character_shader:   renderer.Shader,
	shadow_shader:             renderer.Shader,
	shadow_skinned_shader:     renderer.Shader,
	character_flash_location:  c.int,
	shadow_map:                renderer.Render_Texture2D,
	light_view_projection:     renderer.Matrix,
}

@(private)
rendering_state: Rendering_State

rendering_apply_shader :: proc(model: ^renderer.Model, shader: renderer.Shader) {
	for material_index in 0 ..< int(model.materialCount) {
		model.materials[material_index].shader = shader
	}
}

rendering_set_shader_vec3 :: proc(shader: renderer.Shader, name: cstring, value: renderer.Vec3) {
	location := renderer.get_shader_location(shader, name)
	uniform_value := value
	renderer.set_shader_vec3(shader, location, &uniform_value)
}

rendering_configure_lighting :: proc(shader: renderer.Shader) {
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
	rendering_state.lighting_shader = renderer.load_shader(
		cstring(raw_data(vertex_shader_path)),
		cstring(raw_data(fragment_shader_path)),
	)
	rendering_state.character_lighting_shader = renderer.load_shader(
		cstring(raw_data(skinned_vertex_shader_path)),
		cstring(raw_data(fragment_shader_path)),
	)
	shadow_vertex_shader_path := asset.path("shaders/world_shadow.vs")
	defer delete(shadow_vertex_shader_path)
	shadow_skinned_vertex_shader_path := asset.path("shaders/world_shadow_skinned.vs")
	defer delete(shadow_skinned_vertex_shader_path)
	shadow_fragment_shader_path := asset.path("shaders/world_shadow.fs")
	defer delete(shadow_fragment_shader_path)
	rendering_state.shadow_shader = renderer.load_shader(
		cstring(raw_data(shadow_vertex_shader_path)),
		cstring(raw_data(shadow_fragment_shader_path)),
	)
	rendering_state.shadow_skinned_shader = renderer.load_shader(
		cstring(raw_data(shadow_skinned_vertex_shader_path)),
		cstring(raw_data(shadow_fragment_shader_path)),
	)
	rendering_state.active_character_shader = rendering_state.lighting_shader
	if renderer.model_uses_gpu_skinning(&model_assets.character) {
		rendering_state.active_character_shader = rendering_state.character_lighting_shader
	}
	rendering_state.character_flash_location = renderer.get_shader_location(
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
	if renderer.shader_is_loaded(rendering_state.character_lighting_shader) {
		renderer.unload_shader(rendering_state.character_lighting_shader)
	}
	if renderer.shader_is_loaded(rendering_state.shadow_skinned_shader) {
		renderer.unload_shader(rendering_state.shadow_skinned_shader)
	}
	if renderer.shader_is_loaded(rendering_state.shadow_shader) do renderer.unload_shader(rendering_state.shadow_shader)
	if renderer.shader_is_loaded(rendering_state.lighting_shader) do renderer.unload_shader(rendering_state.lighting_shader)
	rendering_state = {}
}
