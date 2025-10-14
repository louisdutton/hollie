package hollie

import "asset"
import "renderer"
import rl "vendor:raylib"

Shader :: rl.Shader

// Global shaders
white_flash_shader: Shader

shader_init :: proc() {
	white_flash_shader = shader_load("shaders/white_flash.frag")
}

shader_fini :: proc() {
	shader_unload(white_flash_shader)
}

// Draw texture with white flash effect
shader_draw_with_white_flash :: proc(
	texture: renderer.Texture2D,
	source: renderer.Rect,
	position: Vec2,
	intensity: f32,
) {
	if intensity > 0 {
		shader_set_value(white_flash_shader, "flashAmount", intensity, .FLOAT)

		shader_begin(white_flash_shader)
		renderer.draw_texture_rec(texture, source, position)
		shader_end()
	} else {
		renderer.draw_texture_rec(texture, source, position)
	}
}

// -----------------------------------------------------------------------------------------------

@(private = "file")
shader_load :: proc(path: string) -> Shader {
	return rl.LoadShader(nil, cstring(raw_data(asset.path(path))))
}

@(private = "file")
shader_unload :: proc(shader: Shader) {
	rl.UnloadShader(white_flash_shader)
}

@(private = "file")
shader_set_value :: proc(shader: Shader, key: string, value: $T, type: rl.ShaderUniformDataType) {
	location := rl.GetShaderLocation(white_flash_shader, "flashAmount")
	scoped_value := value // we can't reference arguments directly
	rl.SetShaderValue(shader, location, &scoped_value, type)
}

@(private = "file")
shader_begin :: proc(shader: Shader) {
	rl.BeginShaderMode(shader)
}

@(private = "file")
shader_end :: proc() {
	rl.EndShaderMode()
}
