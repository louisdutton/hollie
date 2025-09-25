package hollie

import rl "vendor:raylib"

TARGET_FPS :: 60
FPS :: 24
INTERVAL :: TARGET_FPS / FPS
FRAME_WIDTH :: 96
FRAME_HEIGHT :: 64

AnimationState :: enum {
	IDLE,
	RUN,
	JUMP,
	ATTACK,
	ROLL,
}

Animator :: struct {
	animations:    []rl.Texture2D,
	frame_counts:  []int,
	frame_counter: u32,
	frame:         u32,
	current_anim:  AnimationState,
	is_flipped:    bool,
	rect:          rl.Rectangle,
}

animation_init :: proc(anim: ^Animator, anim_files: []string, frame_counts: []int) {
	anim.animations = make([]rl.Texture2D, len(anim_files))
	anim.frame_counts = make([]int, len(frame_counts))
	copy(anim.frame_counts, frame_counts)

	for file, i in anim_files {
		anim.animations[i] = rl.LoadTexture(cstring(raw_data(file)))
	}

	anim.rect = {0, 0, FRAME_WIDTH, FRAME_HEIGHT}
	anim.frame_counter = 0
	anim.frame = 0
	anim.current_anim = .IDLE
	anim.is_flipped = false
}

// Initialize animation with pre-loaded textures
animation_init_with_textures :: proc(
	anim: ^Animator,
	textures: []rl.Texture2D,
	frame_counts: []int,
) {
	anim.animations = make([]rl.Texture2D, len(textures))
	anim.frame_counts = make([]int, len(frame_counts))
	copy(anim.frame_counts, frame_counts)
	copy(anim.animations, textures)

	anim.rect = {0, 0, FRAME_WIDTH, FRAME_HEIGHT}
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
		anim_data.rect.x = f32(anim_data.frame) * f32(FRAME_WIDTH)
	}
}

animation_set_state :: proc(anim_data: ^Animator, state: AnimationState, flipped: bool) {
	// detect state change
	if anim_data.current_anim != state {
		anim_data.frame = 0
		anim_data.frame_counter = 0
	}

	anim_data.current_anim = state
	anim_data.is_flipped = flipped
}

animation_draw :: proc(anim_data: ^Animator, position: Vec2, color: rl.Color) {
	tex_pos := position
	tex_pos.x -= f32(FRAME_WIDTH) / 2
	tex_pos.y -= f32(FRAME_HEIGHT) / 2
	tex_rect := anim_data.rect
	if anim_data.is_flipped {
		tex_rect.width *= -1
	}
	rl.DrawTextureRec(anim_data.animations[anim_data.current_anim], tex_rect, tex_pos, color)
}

// Special draw function for hit flash effect using shader
animation_draw_with_flash :: proc(
	anim_data: ^Animator,
	position: Vec2,
	color: rl.Color,
	flash_intensity: ^f32,
) {
	tex_pos := position
	tex_pos.x -= f32(FRAME_WIDTH) / 2
	tex_pos.y -= f32(FRAME_HEIGHT) / 2
	tex_rect := anim_data.rect
	if anim_data.is_flipped {
		tex_rect.width *= -1
	}

	shader_draw_with_white_flash(
		anim_data.animations[anim_data.current_anim],
		tex_rect,
		tex_pos,
		color,
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
