package hollie

import rl "vendor:raylib"

// Global shaders
white_flash_shader: rl.Shader

shader_init :: proc() {
	white_flash_shader = rl.LoadShader(nil, "res/shaders/white_flash.frag")
}

shader_fini :: proc() {
	rl.UnloadShader(white_flash_shader)
}

// Draw texture with white flash effect
shader_draw_with_white_flash :: proc(
	texture: rl.Texture2D,
	source: rl.Rectangle,
	position: Vec2,
	color: rl.Color,
	flash_intensity: ^f32,
) {
	if flash_intensity^ > 0 {
		// Use shader for white flash effect
		flash_amount_location := rl.GetShaderLocation(white_flash_shader, "flashAmount")
		rl.SetShaderValue(
			white_flash_shader,
			flash_amount_location,
			flash_intensity,
			rl.ShaderUniformDataType.FLOAT,
		)

		rl.BeginShaderMode(white_flash_shader)
		rl.DrawTextureRec(texture, source, position, color)
		rl.EndShaderMode()
	} else {
		// Normal drawing
		rl.DrawTextureRec(texture, source, position, color)
	}
}
