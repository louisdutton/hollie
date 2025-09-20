package hollie

import "core:math/linalg"
import "core:math/rand"
import rl "vendor:raylib"

ENEMY_MOVE_SPEED :: 1
ENEMY_ANIM_COUNT :: 3
ENEMY_SIZE :: 16

Enemy :: struct {
	position:       Vec2,
	width:          u32,
	height:         u32,
	velocity:       Vec2,
	busy:           bool, // whether or not the character is currently locked in a dialog
	color:          rl.Color,
	anim_data:      Animator,
	wait_timer:     f32,
	move_timer:     f32,
	move_direction: Vec2,
}

// enemy state
enemies: [dynamic]Enemy

enemy_frame_counts := [ENEMY_ANIM_COUNT]int{9, 8, 9}
enemy_anim_files := [ENEMY_ANIM_COUNT]string {
	"res/art/characters/goblin/png/spr_idle_strip9.png",
	"res/art/characters/goblin/png/spr_run_strip8.png",
	"res/art/characters/goblin/png/spr_jump_strip9.png",
}

// TODO: this can probably be simplified to a single timer
enemy_calc_velocity :: proc(enemy: ^Enemy) {
	// Don't move if dialog is active
	if enemy.busy {
		enemy.velocity = {0, 0}
		return
	}

	dt := rl.GetFrameTime()

	enemy.wait_timer -= dt
	enemy.move_timer -= dt

	if enemy.wait_timer <= 0 && enemy.move_timer <= 0 {
		if rand.float32() < 0.3 {
			enemy.wait_timer = rand.float32_range(0.5, 2.0)
			enemy.velocity = {0, 0}
		} else {
			enemy.move_timer = rand.float32_range(1.0, 3.0)
			angle := rand.float32_range(0, 2 * 3.14159)
			enemy.move_direction = {linalg.cos(angle), linalg.sin(angle)}
			enemy.velocity = enemy.move_direction * ENEMY_MOVE_SPEED
		}
	} else if enemy.move_timer > 0 {
		enemy.velocity = enemy.move_direction * ENEMY_MOVE_SPEED
	} else {
		enemy.velocity = {0, 0}
	}
}

enemy_calc_state :: proc(enemy: ^Enemy) {
	if enemy.velocity.x != 0 || enemy.velocity.y != 0 {
		animation_set_state(&enemy.anim_data, .RUN, enemy.velocity.x < 0)
	} else {
		animation_set_state(&enemy.anim_data, .IDLE, false)
	}
}

enemy_move_and_collide :: proc(enemy: ^Enemy) {
	enemy.position.x += enemy.velocity.x
	enemy.position.y += enemy.velocity.y
}

enemy_update :: proc() {
	for &enemy in enemies {
		enemy_calc_velocity(&enemy)
		enemy_calc_state(&enemy)
		enemy_move_and_collide(&enemy)
		animation_update(&enemy.anim_data)
	}
}

enemy_draw :: proc() {
	for &enemy in enemies {
		animation_draw(&enemy.anim_data, enemy.position, enemy.color)
	}
}

enemy_init :: proc() {
	enemies = make([dynamic]Enemy)
}

enemy_spawn_at :: proc(position: Vec2) {
	enemy := Enemy {
		position       = position,
		width          = ENEMY_SIZE,
		height         = ENEMY_SIZE,
		velocity       = {0, 0},
		color          = rl.WHITE,
		wait_timer     = rand.float32_range(0, 2.0),
		move_timer     = 0,
		move_direction = {0, 0},
	}
	animation_init(&enemy.anim_data, enemy_anim_files[:], enemy_frame_counts[:])
	append(&enemies, enemy)
}

enemy_fini :: proc() {
	for &enemy in enemies {
		animation_fini(&enemy.anim_data)
	}
	delete(enemies)
}

// Find the nearest enemy within interaction range
enemy_find_nearest :: proc(position: Vec2, max_distance: f32) -> (^Enemy, bool) {
	nearest_enemy: ^Enemy = nil
	nearest_distance := max_distance

	for &enemy in enemies {
		distance := linalg.distance(position, enemy.position)
		if distance < nearest_distance {
			nearest_enemy = &enemy
			nearest_distance = distance
		}
	}

	return nearest_enemy, nearest_enemy != nil
}
