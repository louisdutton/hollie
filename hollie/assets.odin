package hollie

import "asset"
import "core:c"
import "graphics"


MODEL_CHARACTER_SCALE :: f32(32)
MODEL_CRATE_SCALE :: f32(24)
MODEL_PRESSURE_PAD_SCALE :: f32(32)
MODEL_PRESSURE_PAD_FILE :: "button-floor-square-raylib.glb"
MODEL_CHARACTER_CLIP_NAMES :: [AnimationState]string {
	.Idle   = "idle",
	.Run    = "walk",
	.Jump   = "sprint",
	.Death  = "die",
	.Attack = "attack-melee-right",
	.Carry  = "walk-holding-both",
}
MODEL_CHARACTER_PLAYBACK :: [AnimationState]Animation_Playback {
	.Idle   = .Loop,
	.Run    = .Loop,
	.Jump   = .Once_Hold,
	.Death  = .Once_Hold,
	.Attack = .Once_Hold,
	.Carry  = .Loop,
}
Pressure_Pad_State :: enum {
	Off,
	On,
}
MODEL_PRESSURE_PAD_CLIP_NAMES :: [Pressure_Pad_State]string {
	.Off = "toggle-off",
	.On  = "toggle-on",
}
MODEL_CHARACTER_FILE :: "figurine-raylib.glb"

Model_Assets :: struct {
	floor:                          graphics.Model,
	character:                      graphics.Model,
	crate:                          graphics.Model,
	pressure_pad:                   graphics.Model,
	cube:                           graphics.Model,
	wall:                           graphics.Model,
	doorway_wall:                   graphics.Model,
	door_indicator:                 graphics.Model,
	character_animations:           [^]graphics.Model_Animation,
	character_animation_count:      c.int,
	character_animation_indices:    [AnimationState]int,
	pressure_pad_animations:        [^]graphics.Model_Animation,
	pressure_pad_animation_count:   c.int,
	pressure_pad_animation_indices: [Pressure_Pad_State]int,
	character_bounds:               graphics.Bounding_Box,
	crate_bounds:                   graphics.Bounding_Box,
	pressure_pad_bounds:            graphics.Bounding_Box,
}

@(private)
model_assets: Model_Assets

model_assets_load_model :: proc(relative_path: string) -> graphics.Model {
	path := asset.path(relative_path)
	defer delete(path)
	return graphics.load_model(path)
}

model_assets_init :: proc() {
	root :: "world/props/"
	model_assets.floor = model_assets_load_model(root + "floor-square.glb")
	model_assets.character = model_assets_load_model(root + MODEL_CHARACTER_FILE)
	model_assets.crate = model_assets_load_model(root + "crate-color.glb")
	model_assets.pressure_pad = model_assets_load_model(root + MODEL_PRESSURE_PAD_FILE)
	model_assets.cube = model_assets_load_model(root + "shape-cube.glb")
	model_assets.wall = model_assets_load_model(root + "wall.glb")
	model_assets.doorway_wall = model_assets_load_model(root + "wall-doorway-wide.glb")
	model_assets.door_indicator = model_assets_load_model(root + "indicator-doorway.glb")
	model_assets.character_bounds = graphics.get_model_bounding_box(model_assets.character)
	model_assets.crate_bounds = graphics.get_model_bounding_box(model_assets.crate)
	model_assets.pressure_pad_bounds = graphics.get_model_bounding_box(model_assets.pressure_pad)
	for &index in model_assets.character_animation_indices do index = -1
	path := asset.path(root + MODEL_CHARACTER_FILE)
	defer delete(path)
	model_assets.character_animations = graphics.load_model_animations(
		path,
		&model_assets.character_animation_count,
	)
	clip_names := MODEL_CHARACTER_CLIP_NAMES
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
	pressure_pad_path := asset.path(root + MODEL_PRESSURE_PAD_FILE)
	defer delete(pressure_pad_path)
	model_assets.pressure_pad_animations = graphics.load_model_animations(
		pressure_pad_path,
		&model_assets.pressure_pad_animation_count,
	)
	pressure_pad_clip_names := MODEL_PRESSURE_PAD_CLIP_NAMES
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
		graphics.unload_model_animations(
			model_assets.character_animations,
			model_assets.character_animation_count,
		)
	}
	if model_assets.pressure_pad_animation_count > 0 {
		graphics.unload_model_animations(
			model_assets.pressure_pad_animations,
			model_assets.pressure_pad_animation_count,
		)
	}
	if graphics.model_is_loaded(model_assets.floor) do graphics.unload_model(model_assets.floor)
	if graphics.model_is_loaded(model_assets.character) do graphics.unload_model(model_assets.character)
	if graphics.model_is_loaded(model_assets.crate) do graphics.unload_model(model_assets.crate)
	if graphics.model_is_loaded(model_assets.pressure_pad) do graphics.unload_model(model_assets.pressure_pad)
	if graphics.model_is_loaded(model_assets.cube) do graphics.unload_model(model_assets.cube)
	if graphics.model_is_loaded(model_assets.wall) do graphics.unload_model(model_assets.wall)
	if graphics.model_is_loaded(model_assets.doorway_wall) do graphics.unload_model(model_assets.doorway_wall)
	if graphics.model_is_loaded(model_assets.door_indicator) do graphics.unload_model(model_assets.door_indicator)
	model_assets = {}
}
