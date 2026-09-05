package hollie

import "asset"
import "core:c"
import rl "vendor:raylib"


RENDERING_CHARACTER_SCALE :: f32(32)
RENDERING_CRATE_SCALE :: f32(24)
RENDERING_PRESSURE_PAD_SCALE :: f32(32)
RENDERING_GATE_HEIGHT :: f32(18)
RENDERING_CARRIED_ITEM_HEIGHT :: f32(20)
RENDERING_CHARACTER_BLEND_DURATION :: f32(0.12)
RENDERING_LABEL_TEXT_SIZE :: 12
RENDERING_BACKGROUND_COLOR :: rl.Color{54, 54, 60, 255}
RENDERING_LIGHT_DIRECTION :: rl.Vector3{-0.5, -0.7, 0.5}
RENDERING_PRESSURE_PAD_MODEL :: "button-floor-square-raylib.glb"
RENDERING_CHARACTER_CLIP_NAMES :: [AnimationState]string {
	.Idle = "idle",
	.Run = "walk",
	.Jump = "sprint",
	.Death = "die",
	.Attack = "attack-melee-right",
	.Roll = "sprint",
	.Carry = "walk-holding-both",
}
RENDERING_CHARACTER_PLAYBACK :: [AnimationState]Animation_Playback {
	.Idle = .Loop,
	.Run = .Loop,
	.Jump = .Once_Hold,
	.Death = .Once_Hold,
	.Attack = .Once_Hold,
	.Roll = .Once_Hold,
	.Carry = .Loop,
}
Pressure_Pad_State :: enum {
	Off,
	On,
}
RENDERING_PRESSURE_PAD_CLIP_NAMES :: [Pressure_Pad_State]string {
	.Off = "toggle-off",
	.On = "toggle-on",
}
RENDERING_CHARACTER_MODEL :: "figurine-raylib.glb"

Model_Assets :: struct {	floor:                          rl.Model,
	character:                      rl.Model,
	crate:                          rl.Model,
	pressure_pad:                   rl.Model,
	cube:                           rl.Model,
	wall:                           rl.Model,
	doorway_wall:                   rl.Model,
	door_indicator:                 rl.Model,
	character_animations:           [^]rl.ModelAnimation,
	character_animation_count:      c.int,
	character_animation_indices:    [AnimationState]int,
	pressure_pad_animations:        [^]rl.ModelAnimation,
	pressure_pad_animation_count:   c.int,
	pressure_pad_animation_indices: [Pressure_Pad_State]int,
	character_bounds:               rl.BoundingBox,
	crate_bounds:                   rl.BoundingBox,
	pressure_pad_bounds:            rl.BoundingBox,
}

model_assets: Model_Assets

model_assets_load_model :: proc(relative_path: string) -> rl.Model {
	path := asset.path(relative_path)
	defer delete(path)
	return rl.LoadModel(cstring(raw_data(path)))
}

model_uses_gpu_skinning :: proc(model: ^rl.Model) -> bool {
	for mesh_index in 0 ..< int(model.meshCount) {
		mesh := &model.meshes[mesh_index]
		if mesh.boneWeights != nil && mesh.animVertices == nil do return true
	}
	return false
}

model_assets_init :: proc() {
	root :: "world/props/"
	model_assets.floor = model_assets_load_model(root + "floor-square.glb")
	model_assets.character = model_assets_load_model(root + RENDERING_CHARACTER_MODEL)
	model_assets.crate = model_assets_load_model(root + "crate-color.glb")
	model_assets.pressure_pad = model_assets_load_model(root + RENDERING_PRESSURE_PAD_MODEL)
	model_assets.cube = model_assets_load_model(root + "shape-cube.glb")
	model_assets.wall = model_assets_load_model(root + "wall.glb")
	model_assets.doorway_wall = model_assets_load_model(root + "wall-doorway-wide.glb")
	model_assets.door_indicator = model_assets_load_model(root + "indicator-doorway.glb")
	model_assets.character_bounds = rl.GetModelBoundingBox(model_assets.character)
	model_assets.crate_bounds = rl.GetModelBoundingBox(model_assets.crate)
	model_assets.pressure_pad_bounds = rl.GetModelBoundingBox(model_assets.pressure_pad)
	for &index in model_assets.character_animation_indices do index = -1
	path := asset.path(root + RENDERING_CHARACTER_MODEL)
	defer delete(path)
	model_assets.character_animations = rl.LoadModelAnimations(
		cstring(raw_data(path)),
		&model_assets.character_animation_count,
	)
	clip_names := RENDERING_CHARACTER_CLIP_NAMES
	for state_index := 0; state_index < len(clip_names); state_index += 1 {
		animation_state := AnimationState(state_index)
		clip_name := clip_names[animation_state]
		clip_index: int = -1
		for animation_index in 0 ..< int(model_assets.character_animation_count) {
			animation := &model_assets.character_animations[animation_index]
			if string(cstring(&animation.name[0])) == clip_name {
				clip_index = animation_index
				break
			}
		}
		model_assets.character_animation_indices[animation_state] = clip_index
	}

	for &index in model_assets.pressure_pad_animation_indices do index = -1
	pressure_pad_path := asset.path(root + RENDERING_PRESSURE_PAD_MODEL)
	defer delete(pressure_pad_path)
	model_assets.pressure_pad_animations = rl.LoadModelAnimations(
		cstring(raw_data(pressure_pad_path)),
		&model_assets.pressure_pad_animation_count,
	)
	pressure_pad_clip_names := RENDERING_PRESSURE_PAD_CLIP_NAMES
	for state_index := 0; state_index < len(pressure_pad_clip_names); state_index += 1 {
		pressure_pad_state := Pressure_Pad_State(state_index)
		clip_name := pressure_pad_clip_names[pressure_pad_state]
		clip_index: int = -1
		for animation_index in 0 ..< int(model_assets.pressure_pad_animation_count) {
			animation := &model_assets.pressure_pad_animations[animation_index]
			if string(cstring(&animation.name[0])) == clip_name {
				clip_index = animation_index
				break
			}
		}
		model_assets.pressure_pad_animation_indices[pressure_pad_state] = clip_index
	}
}

model_assets_fini :: proc() {
	if model_assets.character_animation_count > 0 {
		rl.UnloadModelAnimations(
			model_assets.character_animations,
			model_assets.character_animation_count,
		)
	}
	if model_assets.pressure_pad_animation_count > 0 {
		rl.UnloadModelAnimations(
			model_assets.pressure_pad_animations,
			model_assets.pressure_pad_animation_count,
		)
	}
	if model_assets.floor.meshCount > 0 do rl.UnloadModel(model_assets.floor)
	if model_assets.character.meshCount > 0 do rl.UnloadModel(model_assets.character)
	if model_assets.crate.meshCount > 0 do rl.UnloadModel(model_assets.crate)
	if model_assets.pressure_pad.meshCount > 0 do rl.UnloadModel(model_assets.pressure_pad)
	if model_assets.cube.meshCount > 0 do rl.UnloadModel(model_assets.cube)
	if model_assets.wall.meshCount > 0 do rl.UnloadModel(model_assets.wall)
	if model_assets.doorway_wall.meshCount > 0 do rl.UnloadModel(model_assets.doorway_wall)
	if model_assets.door_indicator.meshCount > 0 do rl.UnloadModel(model_assets.door_indicator)
	model_assets = {}
}
