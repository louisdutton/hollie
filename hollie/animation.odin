package hollie

import "asset"
import rl "vendor:raylib"

TARGET_FPS :: 60
FPS :: 24
INTERVAL :: TARGET_FPS / FPS
Animation :: struct {
	path:        string,
	frame_count: int,
}

Animation_Profile :: struct {
	source_frame_size: Vec2,
	world_size:        Vec2,
	anchor:            Vec2,
	smooth:            bool,
}

LEGACY_ANIMATION_PROFILE :: Animation_Profile {
	source_frame_size = {96, 64},
	world_size        = {96, 64},
	anchor            = {0.5, 0.5},
}

AnimationState :: enum {
	IDLE,
	RUN,
	JUMP,
	DEATH,
	ATTACK,
	ROLL,
	CARRY,
}

Animator :: struct {
	animations:    []rl.Texture2D,
	frame_counts:  []int,
	frame_counter: u32,
	frame:         u32,
	current_anim:  AnimationState,
	is_flipped:    bool,
	rect:          rl.Rectangle,
	profile:       Animation_Profile,
}

animation_init :: proc(anim: ^Animator, animations: []Animation, profile: Animation_Profile) {
	anim.animations = make([]rl.Texture2D, len(animations))
	anim.frame_counts = make([]int, len(animations))

	for file, i in animations {
		path := asset.path(file.path)
		anim.animations[i] = rl.LoadTexture(cstring(raw_data(path)))
		rl.SetTextureFilter(anim.animations[i], profile.smooth ? .BILINEAR : .POINT)
		anim.frame_counts[i] = file.frame_count
	}

	anim.profile = profile
	anim.rect = {0, 0, profile.source_frame_size.x, profile.source_frame_size.y}
	anim.frame_counter = 0
	anim.frame = 0
	anim.current_anim = .IDLE
	anim.is_flipped = false
}

animation_update :: proc(anim_data: ^Animator) {
	anim_data.frame_counter += 1

	if anim_data.frame_counter > INTERVAL {
		anim_data.frame_counter = 0
		anim_data.frame += 1
		if int(anim_data.frame) >= anim_data.frame_counts[anim_data.current_anim] {
			anim_data.frame = 0
		}
		anim_data.rect.x = f32(anim_data.frame) * anim_data.profile.source_frame_size.x
	}
}

animation_set_state :: proc(anim_data: ^Animator, state: AnimationState) {
	// detect state change
	if anim_data.current_anim != state {
		anim_data.frame = 0
		anim_data.frame_counter = 0
	}

	anim_data.current_anim = state
}

animation_source_rect :: proc(anim_data: ^Animator) -> rl.Rectangle {
	source := anim_data.rect
	if anim_data.is_flipped do source.width *= -1
	return source
}

animation_destination_rect :: proc(anim_data: ^Animator, position: Vec2) -> rl.Rectangle {
	return {
		position.x - anim_data.profile.world_size.x * anim_data.profile.anchor.x,
		position.y - anim_data.profile.world_size.y * anim_data.profile.anchor.y,
		anim_data.profile.world_size.x,
		anim_data.profile.world_size.y,
	}
}

animation_draw :: proc(anim_data: ^Animator, position: Vec2) {
	tex_rect := animation_source_rect(anim_data)
	dest_rect := animation_destination_rect(anim_data, position)
	rl.DrawTexturePro(
		anim_data.animations[anim_data.current_anim],
		tex_rect,
		dest_rect,
		{},
		0,
		rl.WHITE,
	)
}

// Special draw function for hit flash effect using shader
animation_draw_with_flash :: proc(anim_data: ^Animator, position: Vec2, flash_intensity: f32) {
	tex_rect := animation_source_rect(anim_data)
	dest_rect := animation_destination_rect(anim_data, position)
	shader_draw_with_white_flash_pro(
		anim_data.animations[anim_data.current_anim],
		tex_rect,
		dest_rect,
		flash_intensity,
	)
}

animation_fini :: proc(anim_data: ^Animator) {
	for i in 0 ..< len(anim_data.animations) {
		rl.UnloadTexture(anim_data.animations[i])
	}
	delete(anim_data.animations)
	delete(anim_data.frame_counts)
}
