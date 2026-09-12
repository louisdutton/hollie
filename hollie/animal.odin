package hollie

import "asset"
import "content"
import "core:c"
import "graphics"

ANIMAL_MODEL_SCALE :: f32(32)
ANIMAL_MODEL_FILES :: [content.Character_Kind]string {
	.Goblin   = "",
	.Skeleton = "",
	.Human    = "",
	.Dog      = "world/props/animal-dog-raylib.glb",
	.Horse    = "world/props/animal-horse-raylib.glb",
	.Bison    = "world/props/animal-bison-raylib.glb",
}

Animal_Model :: struct {
	model:           graphics.Model,
	bounds:          graphics.Bounding_Box,
	animations:      [^]graphics.Model_Animation,
	animation_count: c.int,
	walk_clip:       int,
	run_clip:        int,
	seat:            Vec3,
}

animal_models: [content.Character_Kind]Animal_Model

animal_model_for_kind :: proc(kind: content.Character_Kind) -> ^Animal_Model {
	files := ANIMAL_MODEL_FILES
	if files[kind] == "" do return nil
	return &animal_models[kind]
}

animal_models_init :: proc() {
	for file, kind in ANIMAL_MODEL_FILES {
		if file == "" do continue
		animal := &animal_models[kind]
		path := asset.path(file)
		animal.model = graphics.load_model(path)
		animal.bounds = graphics.get_model_bounding_box(animal.model)
		animal.animations = graphics.load_model_animations(path, &animal.animation_count)
		delete(path)
		animal.walk_clip = -1
		animal.run_clip = -1
		for index in 0 ..< int(animal.animation_count) {
			if string(cstring(&animal.animations[index].name[0])) == "walk" do animal.walk_clip = index
			if string(cstring(&animal.animations[index].name[0])) == "run" do animal.run_clip = index
		}
		assert(animal.walk_clip >= 0, "animal model must include its walk animation")
		assert(animal.run_clip >= 0, "animal model must include its run animation")
		graphics.update_model_animation(animal.model, animal.animations[animal.walk_clip], 0)
		torso_index := graphics.get_model_bone_index(animal.model, "torso")
		assert(torso_index >= 0, "animal model must have a torso")
		torso := graphics.get_animated_model_bounding_box(animal.model, torso_index)
		animal.seat = {
			(torso.min.x + torso.max.x) * 0.5 * ANIMAL_MODEL_SCALE,
			(torso.max.y - animal.bounds.min.y) * ANIMAL_MODEL_SCALE,
			(torso.min.z + torso.max.z) * 0.5 * ANIMAL_MODEL_SCALE,
		}
	}
}

animal_models_fini :: proc() {
	for &animal in animal_models {
		if animal.animation_count > 0 do graphics.unload_model_animations(animal.animations, animal.animation_count)
		if graphics.model_is_loaded(animal.model) do graphics.unload_model(animal.model)
	}
	animal_models = {}
}

animal_models_apply_shader :: proc(shadow: bool) {
	for &animal in animal_models {
		if !graphics.model_is_loaded(animal.model) do continue
		shader := shadow ? rendering_state.shadow_shader : rendering_state.lighting_shader
		if graphics.model_uses_gpu_skinning(&animal.model) {
			shader =
				shadow ? rendering_state.shadow_skinned_shader : rendering_state.character_lighting_shader
		}
		rendering_apply_shader(&animal.model, shader)
	}
}

rendering_draw_animal :: proc(enemy: ^Enemy, animal: ^Animal_Model) {
	clip := animal.animations[enemy.mounted ? animal.run_clip : animal.walk_clip]
	frame: f32
	if enemy.current_anim == .Run do frame = model_animation_frame(enemy.visual_time, clip, .Loop)
	graphics.update_model_animation(animal.model, clip, frame)
	graphics.draw_model(
		animal.model,
		geometry_grounded_position(
			enemy.position,
			animal.bounds,
			ANIMAL_MODEL_SCALE,
			enemy.height,
		),
		{0, 1, 0},
		geometry_facing_angle(enemy.facing_direction) + 90, // Kenney animals face local -X.
		{ANIMAL_MODEL_SCALE, ANIMAL_MODEL_SCALE, ANIMAL_MODEL_SCALE},
		graphics.WHITE,
	)
}
