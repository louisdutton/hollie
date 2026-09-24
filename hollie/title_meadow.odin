package hollie

import "asset"
import "core:math"
import "graphics"

// Independent resources: the title never loads or mutates a gameplay room.
Title_Meadow :: struct {
	shader: graphics.Shader,
	models: [dynamic]graphics.Model,
	time:   f32,
}

title_meadow: Title_Meadow
TITLE_MEADOW_SKY :: Vec3{0.78, 0.85, 0.76}

title_meadow_init :: proc() {
	vertex_path := asset.path("shaders/grass.vs")
	defer delete(vertex_path)
	fragment_path := asset.path("shaders/grass.fs")
	defer delete(fragment_path)
	title_meadow.shader = graphics.load_shader(
		cstring(raw_data(vertex_path)),
		cstring(raw_data(fragment_path)),
	)
	shader := title_meadow.shader
	rendering_configure_lighting(shader, ENVIRONMENT_DAY)
	landscape := f32(1)
	graphics.set_shader_float(
		shader,
		graphics.get_shader_location(shader, "meadow_landscape"),
		&landscape,
	)
	rendering_set_shader_vec3(shader, "meadow_fog", {240, 850, 1})
	rendering_set_shader_vec3(shader, "meadow_fog_color", TITLE_MEADOW_SKY)

	builder: Grass_Mesh_Builder
	defer delete(builder.positions)
	defer delete(builder.roots)
	defer delete(builder.colors)
	defer delete(builder.indices)
	// Small meshes keep indices within u16; distant grass is deterministically thinned.
	for z := -32; z < 8; z += 4 {
		for x := -20; x < 20; x += 4 {
			clear(&builder.positions)
			clear(&builder.roots)
			clear(&builder.colors)
			clear(&builder.indices)
			for row in z ..< z + 4 {
				for column in x ..< x + 4 {
					density: f32 = row < -16 ? 0.28 : row < -6 ? 0.65 : 1
					grass_build_patch(&builder, column, row, 32, 40, density, true)
				}
			}
			model := graphics.load_indexed_model(
				builder.positions[:],
				builder.colors[:],
				builder.indices[:],
				builder.roots[:],
			)
			rendering_apply_shader(&model, shader)
			append(&title_meadow.models, model)
		}
	}
}

title_meadow_fini :: proc() {
	for model in title_meadow.models do graphics.unload_model(model)
	delete(title_meadow.models)
	if graphics.shader_is_loaded(title_meadow.shader) do graphics.unload_shader(title_meadow.shader)
	title_meadow = {}
}

title_meadow_camera :: proc() -> graphics.Camera_3D {
	return {
		position = {0, 29, 100},
		target = {5, 14, -220},
		up = {0, 1, 0},
		fovy = 48,
		projection = .PERSPECTIVE,
	}
}

title_meadow_draw :: proc() {
	// A quiet sky gradient gives the low-angle meadow a soft horizon.
	ui_begin()
	for band in 0 ..< 90 {
		t := clamp(f32(band) / 48, 0, 1)
		color := graphics.Colour {
			u8(math.lerp(f32(123), 199, t)),
			u8(math.lerp(f32(178), 217, t)),
			u8(math.lerp(f32(190), 194, t)),
			255,
		}
		graphics.draw_rect(0, f32(band * 5), f32(design_width), 5, color)
	}
	// Warm, understated sun above the right-hand ridge.
	graphics.draw_circle(f32(design_width) * 0.76, 112, 24, {247, 235, 189, 255})
	ui_end()
	view := title_meadow_camera()
	rendering_set_shader_vec3(title_meadow.shader, "view_position", view.position)
	graphics.set_shader_float(
		title_meadow.shader,
		graphics.get_shader_location(title_meadow.shader, "grass_time"),
		&title_meadow.time,
	)
	graphics.begin_mode_3d(view)
	for model in title_meadow.models do graphics.draw_model(model, {}, {0, 1, 0}, 0, {1, 1, 1}, graphics.WHITE)
	graphics.end_mode_3d()
}
