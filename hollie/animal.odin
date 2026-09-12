package hollie

import "asset"
import "content"
import "core:c"
import "core:math"
import "graphics"

ANIMAL_MODEL_SCALE :: f32(32)
ANIMAL_WALK_SPEED :: f32(50)
ANIMAL_RUN_SPEED :: f32(160)
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
	jump_clip:       int,
	idle_clip:       int,
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
		animal.jump_clip = -1
		animal.idle_clip = -1
		for index in 0 ..< int(animal.animation_count) {
			if string(cstring(&animal.animations[index].name[0])) == "walk" do animal.walk_clip = index
			if string(cstring(&animal.animations[index].name[0])) == "run" do animal.run_clip = index
			if string(cstring(&animal.animations[index].name[0])) == "jump" do animal.jump_clip = index
			if string(cstring(&animal.animations[index].name[0])) == "down" do animal.idle_clip = index
		}
		assert(animal.walk_clip >= 0, "animal model must include its walk animation")
		assert(animal.run_clip >= 0, "animal model must include its run animation")
		assert(animal.jump_clip >= 0, "animal model must include its jump animation")
		assert(animal.idle_clip >= 0, "animal model must include its standing pose")
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

// A continuous blend tree: standing -> walking -> running, in world units/sec.
animal_gait_blend :: proc(speed: f32) -> (walking: bool, blend: f32) {
	if speed <= ANIMAL_WALK_SPEED do return true, clamp(speed / ANIMAL_WALK_SPEED, 0, 1)
	return false, clamp((speed - ANIMAL_WALK_SPEED) / (ANIMAL_RUN_SPEED - ANIMAL_WALK_SPEED), 0, 1)
}

animal_update_gait :: proc(enemy: ^Enemy, dt: f32) {
	if !enemy.grounded do return
	speed := math.sqrt(enemy.velocity.x * enemy.velocity.x + enemy.velocity.y * enemy.velocity.y)
	walking, blend := animal_gait_blend(speed)
	// Keep the clips in the same stride phase while scaling cadence with travel.
	stride_length := walking ? f32(25) : 25 + 15 * blend
	enemy.gait_phase = math.mod(enemy.gait_phase + speed / stride_length * max(dt, 0), 1)
}

animal_apply_pose :: proc(enemy: ^Enemy, animal: ^Animal_Model) {
	if !enemy.grounded {
		graphics.update_model_animation(animal.model, animal.animations[animal.jump_clip], 0)
	} else {
		speed := math.sqrt(
			enemy.velocity.x * enemy.velocity.x + enemy.velocity.y * enemy.velocity.y,
		)
		walking, blend := animal_gait_blend(speed)
		first := animal.animations[walking ? animal.idle_clip : animal.walk_clip]
		second := animal.animations[walking ? animal.walk_clip : animal.run_clip]
		// The first frame of 'down' is the authored standing pose, held still.
		first_frame :=
			walking ? f32(0) : enemy.gait_phase * f32(max(int(first.keyframeCount) - 1, 0))
		second_frame := enemy.gait_phase * f32(max(int(second.keyframeCount) - 1, 0))
		graphics.update_model_animation_blended(
			animal.model,
			first,
			first_frame,
			second,
			second_frame,
			blend,
		)
	}
}

animal_animated_seat :: proc(enemy: ^Enemy, animal: ^Animal_Model) -> Vec3 {
	animal_apply_pose(enemy, animal)
	torso_index := graphics.get_model_bone_index(animal.model, "torso")
	torso := graphics.get_animated_model_bounding_box(animal.model, torso_index)
	return {
		(torso.min.x + torso.max.x) * 0.5 * ANIMAL_MODEL_SCALE,
		(torso.max.y - animal.bounds.min.y) * ANIMAL_MODEL_SCALE,
		(torso.min.z + torso.max.z) * 0.5 * ANIMAL_MODEL_SCALE,
	}
}

rendering_draw_animal :: proc(enemy: ^Enemy, animal: ^Animal_Model) {
	animal_apply_pose(enemy, animal)
	if enemy.mounted && enemy.head_turn != 0 {
		head := graphics.get_model_bone_index(animal.model, "head")
		neck := graphics.get_model_bone_index(animal.model, "neck")
		pivot_bone := neck >= 0 ? neck : head
		if pivot_bone >= 0 {
			pivot := animal.model.currentPose[pivot_bone].translation
			graphics.rotate_model_bone_y(animal.model, head, pivot, enemy.head_turn)
			graphics.rotate_model_bone_y(animal.model, neck, pivot, enemy.head_turn)
		}
	}
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
		enemy.turn_lean,
		{enemy.facing_direction.x, 0, enemy.facing_direction.y},
		geometry_position(enemy.position, enemy.height),
	)
}
