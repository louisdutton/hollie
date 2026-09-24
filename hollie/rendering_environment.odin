package hollie

import "graphics"

rendering_update_environment :: proc() {
	shaders := [4]graphics.Shader {
		rendering_state.lighting_shader,
		rendering_state.character_lighting_shader,
		rendering_state.grass_shader,
		rendering_state.water_shader,
	}
	for shader in shaders do rendering_configure_lighting(shader)
	rendering_set_shader_vec3(
		rendering_state.water_shader,
		"environment_light_floor",
		environment.water_light_floor,
	)
}
