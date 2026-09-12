package hollie

import "core:math"

ANIMATION_SAMPLE_FPS :: f32(60) // sampling rate of imported animation clips

Animation_Playback :: enum {
	Loop,
	Once_Hold,
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
	case .Loop: return math.mod(frame, loop_period)
	case .Once_Hold: return min(frame, terminal_frame)
	}
	return 0
}

AnimationState :: enum {
	Idle,
	Run,
	Jump,
	Death,
	Carry,
	Ride,
}

Animator :: struct {
	frame_counts:  []int,
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


	anim.visual_time = 0
	anim.current_anim = .Idle
	anim.previous_anim = .Idle
	anim.previous_time = 0
	anim.blend_elapsed = 1e9
}

animation_update :: proc(anim_data: ^Animator, dt: f32) {
	anim_data.visual_time += dt
	anim_data.previous_time += dt
	anim_data.blend_elapsed += dt

}

animation_set_state :: proc(anim_data: ^Animator, state: AnimationState) {
	// detect state change
	if anim_data.current_anim != state {
		anim_data.previous_anim = anim_data.current_anim
		anim_data.previous_time = anim_data.visual_time
		anim_data.blend_elapsed = 0


		anim_data.visual_time = 0
	}

	anim_data.current_anim = state
}

animation_fini :: proc(anim_data: ^Animator) {
	delete(anim_data.frame_counts)
}

animation_update_entities :: proc(dt: f32) {

	for &entity in world.entities {
		switch &e in entity {
		case Player:
			speed := math.sqrt(e.velocity.x * e.velocity.x + e.velocity.y * e.velocity.y)
			ratio := clamp(speed / PLAYER_MOVEMENT_PROFILE.max_speed, 0, 1)
			if e.grounded || e.swimming do e.stride_time += min(dt, 0.1) * ratio * 1.65
			target_lean := e.grounded && !e.is_busy ? math.to_radians(f32(8)) * ratio : f32(0)
			e.movement_lean += (target_lean - e.movement_lean) * (1 - math.exp(-20 * min(dt, 0.1)))
			if riding_animal_for_player(e.index) != nil {
				animation_set_state(
					&e.anim_data,
					e.mount_elapsed < e.mount_duration * 0.7 ? .Jump : .Ride,
				)
			} else if e.carrying != 0 {
				animation_set_state(&e.anim_data, .Carry)
			} else if !e.grounded && !e.swimming {
				animation_set_state(&e.anim_data, .Jump)
			} else if abs(e.velocity.x) > 0 || abs(e.velocity.y) > 0 {
				animation_set_state(&e.anim_data, .Run)
			} else {
				animation_set_state(&e.anim_data, .Idle)
			}
			animation_update(&e.anim_data, dt)

		case Enemy:
			rage_target := e.ram_ready ? f32(1) : f32(0)
			e.ram_visual += (rage_target - e.ram_visual) * (1 - math.exp(-10 * min(dt, 0.1)))
			if animal_model_for_kind(e.kind) != nil do animal_update_gait(&e, min(dt, 0.1))
			if e.is_dying {
				animation_set_state(&e.anim_data, .Death)
			} else if abs(e.velocity.x) > 0 || abs(e.velocity.y) > 0 {
				animation_set_state(&e.anim_data, .Run)
			} else {
				animation_set_state(&e.anim_data, .Idle)
			}
			animation_update(&e.anim_data, dt)

		case Npc:
			if e.is_dying {
				animation_set_state(&e.anim_data, .Death)
			} else if abs(e.velocity.x) > 0 || abs(e.velocity.y) > 0 {
				animation_set_state(&e.anim_data, .Run)
			} else {
				animation_set_state(&e.anim_data, .Idle)
			}
			animation_update(&e.anim_data, dt)

		case Pressure_Plate, Gate, Holdable, Door: continue
		}
	}
}
