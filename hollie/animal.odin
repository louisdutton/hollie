package hollie

import "asset"
import "content"
import "core:c"
import "core:math"
import "graphics"

ANIMAL_MODEL_SCALE :: f32(32)
ANIMAL_WALK_SPEED :: f32(50)
ANIMAL_RUN_SPEED :: f32(160)

animal_riding_profile :: proc(kind: content.Character_Kind) -> Movement_Profile {
	profile := RIDING_MOVEMENT_PROFILE
	if kind == .Horse do profile.max_speed = 200
	if kind == .Turtle do profile.max_speed = 120
	if kind == .Bison {
		profile.max_speed = 140
		profile.acceleration = 110
	}
	return profile
}
ANIMAL_WANDER_PROFILE :: Movement_Profile {
	20,
	ANIMAL_WALK_SPEED,
	RIDING_MOVEMENT_PROFILE.acceleration,
	RIDING_MOVEMENT_PROFILE.deceleration,
}

animal_update_movement :: proc(
	animal: ^Enemy,
	direction: Vec2,
	profile: Movement_Profile,
	dt: f32,
) {
	charging := animal.kind == .Bison && animal.mounted && animal.ram_ready
	movement_profile := profile
	if charging {
		movement_profile.max_speed = BISON_CHARGE_SPEED
		movement_profile.acceleration = 75
	}
	previous := animal.velocity
	speed := math.sqrt(previous.x * previous.x + previous.y * previous.y)
	magnitude := min(math.sqrt(direction.x * direction.x + direction.y * direction.y), 1)
	// Controllers do not always reach a perfect unit circle at full tilt.
	if animal.kind == .Bison && animal.mounted && magnitude >= 0.9 do magnitude = 1
	if magnitude > 0 {
		angle := math.atan2(animal.facing_direction.x, animal.facing_direction.y)
		target := math.atan2(direction.x, direction.y)
		delta := math.atan2(math.sin(target - angle), math.cos(target - angle))
		// Cap angular speed even when travelling slowly; reversals become arcs.
		turn_rate := animal.mounted ? f32(2.8) : f32(1.5)
		if charging do turn_rate = BISON_CHARGE_TURN_RATE
		angle += clamp(delta, -turn_rate * dt, turn_rate * dt)
		animal.facing_direction = {math.sin(angle), math.cos(angle)}
		magnitude *= max(f32(0.25), math.cos(delta))
	}
	speed_input := magnitude > 0 ? Vec2{magnitude, 0} : Vec2{}
	next_speed := movement_accelerate({speed, 0}, speed_input, movement_profile, dt).x
	animal.velocity = animal.facing_direction * next_speed
	animal.turn_lean = riding_turn_lean(animal.turn_lean, previous, animal.velocity, dt)
	animal.head_turn = riding_head_turn(animal.head_turn, animal.facing_direction, direction, dt)
}
ANIMAL_MODEL_FILES :: [content.Character_Kind]string {
	.Goblin   = "",
	.Skeleton = "",
	.Human    = "",
	.Dog      = "world/props/animal-dog-raylib.glb",
	.Horse    = "world/props/animal-horse-raylib.glb",
	.Bison    = "world/props/animal-bison-raylib.glb",
	.Turtle   = "world/props/animal-turtle-raylib.glb",
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

animal_collider_from_bounds :: proc(bounds: graphics.Bounding_Box, facing: Vec2) -> Collider {
	angle := math.to_radians(geometry_facing_angle(facing) + 90)
	sine, cosine := math.sin(angle), math.cos(angle)
	center := (bounds.min + bounds.max) * (0.5 * ANIMAL_MODEL_SCALE)
	half := (bounds.max - bounds.min) * (0.5 * ANIMAL_MODEL_SCALE)
	rotated_center := Vec2 {
		cosine * center.x + sine * center.z,
		-sine * center.x + cosine * center.z,
	}
	extent := Vec2 {
		abs(cosine) * half.x + abs(sine) * half.z,
		abs(sine) * half.x + abs(cosine) * half.z,
	}
	return {
		offset = {rotated_center.x - extent.x, 0, rotated_center.y - extent.y},
		size = {extent.x * 2, half.y * 2, extent.y * 2},
		solid = true,
	}
}

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
	if enemy.kind == .Bison do stride_length *= 1.7
	enemy.gait_phase = math.mod(enemy.gait_phase + speed / stride_length * max(dt, 0), 1)
}

animal_gait_weight :: proc(animal: ^Enemy) -> f32 {
	if animal.kind != .Bison || !animal.grounded do return 0
	speed := math.sqrt(
		animal.velocity.x * animal.velocity.x + animal.velocity.y * animal.velocity.y,
	)
	return clamp(speed / animal_riding_profile(.Bison).max_speed, 0, 1)
}

animal_gait_bob :: proc(animal: ^Enemy) -> f32 {
	stride := math.sin(animal.gait_phase * 2 * math.PI)
	return stride * stride * 2.3 * animal_gait_weight(animal)
}

animal_visual_bank :: proc(animal: ^Enemy) -> f32 {
	return(
		animal.turn_lean +
		math.sin(animal.gait_phase * 2 * math.PI) *
			math.to_radians(f32(3)) *
			animal_gait_weight(animal) \
	)
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
	if enemy.ram_visual > 0.001 {
		head := graphics.get_model_bone_index(animal.model, "head")
		if head >= 0 do graphics.rotate_model_bone_z(animal.model, head, animal.model.currentPose[head].translation, math.to_radians(f32(25)) * enemy.ram_visual)
	}
	if enemy.head_turn != 0 {
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
			enemy.height + animal_gait_bob(enemy),
		),
		{0, 1, 0},
		geometry_facing_angle(enemy.facing_direction) + 90, // Kenney animals face local -X.
		{ANIMAL_MODEL_SCALE, ANIMAL_MODEL_SCALE, ANIMAL_MODEL_SCALE},
		graphics.Colour {
			255,
			u8(255 - 180 * enemy.ram_visual),
			u8(255 - 195 * enemy.ram_visual),
			255,
		},
		animal_visual_bank(enemy),
		{enemy.facing_direction.x, 0, enemy.facing_direction.y},
		geometry_position(enemy.position, enemy.height),
	)
}
