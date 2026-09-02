package hollie

TARGET_FPS :: 60
FPS :: 24
INTERVAL :: TARGET_FPS / FPS
Animation :: struct {
	frame_count: int,
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
	frame_counts:  []int,
	frame_counter: u32,
	frame:         u32,
	current_anim:  AnimationState,
}

animation_init :: proc(anim: ^Animator, animations: []Animation) {
	anim.frame_counts = make([]int, len(animations))

	for animation, i in animations {
		anim.frame_counts[i] = animation.frame_count
	}

	anim.frame_counter = 0
	anim.frame = 0
	anim.current_anim = .IDLE
}

animation_update :: proc(anim_data: ^Animator) {
	anim_data.frame_counter += 1

	if anim_data.frame_counter > INTERVAL {
		anim_data.frame_counter = 0
		anim_data.frame += 1
		if int(anim_data.frame) >= anim_data.frame_counts[anim_data.current_anim] {
			anim_data.frame = 0
		}
	}
}

// The legacy gameplay frame remains discrete, but rendering can interpolate the
// time accumulated toward the next frame instead of visibly stepping at 20 Hz.
animation_frame_phase :: proc(anim_data: ^Animator) -> f32 {
	return f32(anim_data.frame) + f32(anim_data.frame_counter) / f32(INTERVAL + 1)
}

animation_set_state :: proc(anim_data: ^Animator, state: AnimationState) {
	// detect state change
	if anim_data.current_anim != state {
		anim_data.frame = 0
		anim_data.frame_counter = 0
	}

	anim_data.current_anim = state
}

animation_fini :: proc(anim_data: ^Animator) {
	delete(anim_data.frame_counts)
}
