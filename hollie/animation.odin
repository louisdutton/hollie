package hollie

import "core:math"

TARGET_FPS :: 60
FPS :: 24
INTERVAL :: TARGET_FPS / FPS
ANIMATION_SAMPLE_FPS :: f32(TARGET_FPS)

Animation_Playback :: enum {
	LOOP,
	ONCE_HOLD,
}

Animation :: struct {
	frame_count: int,
}

animation_frame_at_time :: proc(
	elapsed_time: f32,
	frame_count: int,
	playback: Animation_Playback,
) -> f32 {
	if frame_count <= 1 do return 0
	// raylib's GLTF loader appends the first pose as a wrap sample. Loops use
	// that sample as their period boundary; one-shots must stop one frame prior.
	loop_period := f32(frame_count - 1)
	terminal_frame := f32(max(frame_count - 2, 0))
	frame := max(elapsed_time, 0) * ANIMATION_SAMPLE_FPS
	switch playback {
	case .LOOP: return math.mod(frame, loop_period)
	case .ONCE_HOLD: return min(frame, terminal_frame)
	}
	return 0
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
	visual_time:   f32,
	current_anim:  AnimationState,
	previous_anim: AnimationState,
	previous_time: f32,
	blend_elapsed: f32,
}

animation_init :: proc(anim: ^Animator, animations: []Animation) {
	anim.frame_counts = make([]int, len(animations))

	for animation, i in animations {
		anim.frame_counts[i] = animation.frame_count
	}

	anim.frame_counter = 0
	anim.frame = 0
	anim.visual_time = 0
	anim.current_anim = .IDLE
	anim.previous_anim = .IDLE
	anim.previous_time = 0
	anim.blend_elapsed = 1e9
}

animation_update :: proc(anim_data: ^Animator, delta_time: f32 = 1.0 / TARGET_FPS) {
	anim_data.frame_counter += 1
	anim_data.visual_time += delta_time
	anim_data.previous_time += delta_time
	anim_data.blend_elapsed += delta_time

	if anim_data.frame_counter > INTERVAL {
		anim_data.frame_counter = 0
		anim_data.frame += 1
		if int(anim_data.frame) >= anim_data.frame_counts[anim_data.current_anim] {
			anim_data.frame = 0
		}
	}
}

animation_set_state :: proc(anim_data: ^Animator, state: AnimationState) {
	// detect state change
	if anim_data.current_anim != state {
		anim_data.previous_anim = anim_data.current_anim
		anim_data.previous_time = anim_data.visual_time
		anim_data.blend_elapsed = 0
		anim_data.frame = 0
		anim_data.frame_counter = 0
		anim_data.visual_time = 0
	}

	anim_data.current_anim = state
}

animation_fini :: proc(anim_data: ^Animator) {
	delete(anim_data.frame_counts)
}
