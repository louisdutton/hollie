package hollie

import "asset"
import "core:os"
import "core:strings"
import "graphics"

// GLSL 330 has no native include directive. Expand our one shared lighting
// module before compilation rather than maintaining copies per material.
rendering_load_environment_shader :: proc(vertex_path, fragment_path: cstring) -> graphics.Shader {
	vertex, vertex_error := os.read_entire_file(string(vertex_path), context.allocator)
	assert(vertex_error == nil, "could not read environment vertex shader")
	defer delete(vertex)
	fragment, fragment_error := os.read_entire_file(string(fragment_path), context.allocator)
	assert(fragment_error == nil, "could not read environment fragment shader")
	defer delete(fragment)
	shared_path := asset.path("shaders/environment.glsl")
	defer delete(shared_path)
	shared, shared_error := os.read_entire_file(shared_path, context.allocator)
	assert(shared_error == nil, "could not read shared environment shader")
	defer delete(shared)
	source, allocated := strings.replace_all(
		string(fragment),
		"#include_environment",
		string(shared),
	)
	assert(allocated, "environment shader is missing its shared module marker")
	defer delete(source)
	vertex_source := strings.clone_to_cstring(string(vertex))
	defer delete(vertex_source)
	fragment_source := strings.clone_to_cstring(source)
	defer delete(fragment_source)
	return graphics.load_shader_from_memory(vertex_source, fragment_source)
}

rendering_update_environment :: proc() {
	shaders := [4]graphics.Shader {
		rendering_state.lighting_shader,
		rendering_state.character_lighting_shader,
		rendering_state.grass_shader,
		rendering_state.water_shader,
	}
	for shader in shaders {
		rendering_configure_lighting(shader)
		rendering_set_shader_vec3(
			shader,
			"cloud_offset_scale",
			{environment.cloud_offset.x, environment.cloud_offset.y, environment.cloud_scale},
		)
		rendering_set_shader_vec3(
			shader,
			"cloud_shape",
			{environment.cloud_coverage, environment.cloud_softness, environment.cloud_strength},
		)
	}
}
