package hollie

import "asset"
import "audio"
import "core:math/linalg"
import "core:math/rand"
import "input"
import "renderer"
import rl "vendor:raylib"


// Character tags combining type, race, and behaviors
Character_Tags :: bit_set[Character_Tag]
Character_Tag :: enum {
	// Type tags
	PLAYER, // entity is player (exclusive)
	NPC, // non-playable character
	ENEMY, // hostile entity

	// Race tags
	GOBLIN,
	SKELETON,
	HUMAN,

	// Behavior tags
	CAN_MOVE,
	CAN_ATTACK,
	CAN_ROLL,
	CAN_INTERACT,
	HAS_AI,
	IS_INTERACTABLE,
}

goblin_animations := [?]Animation {
	{asset.path("art/characters/goblin/png/spr_idle_strip9.png"), 9},
	{asset.path("art/characters/goblin/png/spr_run_strip8.png"), 8},
	{asset.path("art/characters/goblin/png/spr_jump_strip9.png"), 9},
	{asset.path("art/characters/goblin/png/spr_death_strip13.png"), 13},
}

skeleton_animations := [?]Animation {
	{asset.path("art/characters/skeleton/png/skeleton_idle_strip6.png"), 6},
	{asset.path("art/characters/skeleton/png/skeleton_walk_strip8.png"), 8},
	{asset.path("art/characters/skeleton/png/skeleton_jump_strip10.png"), 10},
	{asset.path("art/characters/skeleton/png/skeleton_death_strip10.png"), 10},
}

human_animations := [?]Animation {
	{asset.path("art/characters/human/idle/base_idle_strip9.png"), 9},
	{asset.path("art/characters/human/run/base_run_strip8.png"), 8},
	{asset.path("art/characters/human/jump/base_jump_strip9.png"), 9},
	{asset.path("art/characters/human/death/base_death_strip13.png"), 13},
	{asset.path("art/characters/human/attack/base_attack_strip10.png"), 10},
	{asset.path("art/characters/human/roll/base_roll_strip10.png"), 10},
}

ENEMY_ANIM_COUNT :: 4

// Character states for behavior management
Character_State :: struct {
	is_attacking:     bool,
	attack_timer:     u32,
	attack_hit:       bool, // has this attack already hit a target
	attack_direction: Vec2, // direction locked when attack started
	is_rolling:       bool,
	roll_timer:       u32,
	is_busy:          bool, // locked in dialog or other activity
	is_flipped:       bool, // sprite flip state
	is_dying:         bool, // playing death animation
	death_timer:      u32, // timer for death animation duration

	// Hit effects
	hit_flash_timer:  f32,
	knockback_timer:  f32,
}

// AI state for NPCs and enemies
Character_AI_State :: struct {
	wait_timer:     f32,
	move_timer:     f32,
	move_direction: Vec2,
}

// Core character structure
Character :: struct {
	// Basic properties
	position:      Vec2,
	width:         u32,
	height:        u32,
	velocity:      Vec2,
	color:         renderer.Colour,

	// Character tags (type, race, and behaviors combined)
	tags:          Character_Tags,

	// Animation
	anim_data:     Animator,

	// State management
	state:         Character_State,
	ai_state:      Character_AI_State,

	// Movement constants (can be different per character)
	move_speed:    f32,
	roll_speed:    f32,

	// Combat properties
	health:        i32,
	max_health:    i32,
	attack_damage: i32,
	attack_range:  f32,
	attack_width:  f32,
	attack_height: f32,
}

// Character collection
characters: [dynamic]Character

// Constants
DEFAULT_MOVE_SPEED :: 0.5
DEFAULT_ROLL_SPEED :: 3.0
DEFAULT_ENEMY_MOVE_SPEED :: 0.5
DEFAULT_PLAYER_MOVE_SPEED :: 1.5
DEFAULT_ATTACK_RANGE :: 20.0
DEFAULT_ATTACK_WIDTH :: 20.0
DEFAULT_ATTACK_HEIGHT :: 20.0

// Health constants
DEFAULT_PLAYER_HEALTH :: 100
DEFAULT_ENEMY_HEALTH :: 30
DEFAULT_NPC_HEALTH :: 50
DEFAULT_ATTACK_DAMAGE :: 10

// Hit effect constants
HIT_FLASH_DURATION :: 0.2
KNOCKBACK_FORCE :: 5.0 // the magnitude of knockback
KNOCKBACK_DURATION :: 0.3 // the duration of knockback in seconds
KNOCKBACK_FRICTION: f32 = 0.85 // the decay of velocity during knockback

// Death animation constants
DEATH_ANIMATION_DURATION :: 13 * INTERVAL // 13 frames for goblin/human death

// Initialize character system
character_system_init :: proc() {
	characters = make([dynamic]Character)
}

// Clean up character system
character_system_fini :: proc() {
	for &character in characters {
		character_destroy(&character)
	}
	delete(characters)
}

// Create a new character
character_create :: proc(pos: Vec2, tags: Character_Tags, animations: []Animation) -> ^Character {
	character := Character {
		position      = pos,
		width         = 16,
		height        = 16,
		velocity      = {0, 0},
		color         = renderer.WHITE,
		tags          = tags,
		move_speed    = DEFAULT_MOVE_SPEED,
		roll_speed    = DEFAULT_ROLL_SPEED,
		attack_damage = DEFAULT_ATTACK_DAMAGE,
		attack_range  = DEFAULT_ATTACK_RANGE,
		attack_width  = DEFAULT_ATTACK_WIDTH,
		attack_height = DEFAULT_ATTACK_HEIGHT,
	}

	// Adjust defaults based on type
	if .ENEMY in tags {
		character.move_speed = DEFAULT_ENEMY_MOVE_SPEED
		character.health = DEFAULT_ENEMY_HEALTH
		character.max_health = DEFAULT_ENEMY_HEALTH
		character.ai_state.wait_timer = rand.float32_range(0, 2.0)
	} else if .PLAYER in tags {
		character.move_speed = DEFAULT_PLAYER_MOVE_SPEED
		character.health = DEFAULT_PLAYER_HEALTH
		character.max_health = DEFAULT_PLAYER_HEALTH
	} else if .NPC in tags {
		character.move_speed = DEFAULT_MOVE_SPEED
		character.health = DEFAULT_NPC_HEALTH
		character.max_health = DEFAULT_NPC_HEALTH
	}

	// Initialize animation
	animation_init(&character.anim_data, animations)

	append(&characters, character)

	return &characters[len(characters) - 1]
}


// Destroy a character
character_destroy :: proc(character: ^Character) {
	animation_fini(&character.anim_data)
}

// Remove a character from the system
character_remove :: proc(character: ^Character) {
	for i in 0 ..< len(characters) {
		if &characters[i] == character {
			character_destroy(&characters[i])
			unordered_remove(&characters, i)
			break
		}
	}
}


// Unified character creation function
character_spawn :: proc(pos: Vec2, tags: Character_Tags, variant: string = "") -> ^Character {
	if .GOBLIN in tags {
		return character_create(pos, tags, goblin_animations[:])
	} else if .SKELETON in tags {
		return character_create(pos, tags, skeleton_animations[:])
	} else if .HUMAN in tags {
		// For now, just use base human animations (no hair variants)
		return character_create(pos, tags, human_animations[:])
	}

	// Fallback (should never reach here)
	return character_create(pos, tags, goblin_animations[:])
}

// Get character rectangle for collision
character_get_rect :: proc(character: ^Character) -> renderer.Rect {
	w := f32(character.width)
	h := f32(character.height)
	return renderer.Rect{character.position.x - w / 2, character.position.y - h / 2, w, h}
}

// Get attack rectangle
character_get_attack_rect :: proc(character: ^Character) -> renderer.Rect {
	attack_offset := character.state.attack_direction * character.attack_range
	attack_x := character.position.x + attack_offset.x - character.attack_width / 2
	attack_y := character.position.y + attack_offset.y - character.attack_height / 2

	return renderer.Rect{attack_x, attack_y, character.attack_width, character.attack_height}
}

// Check collision between two rectangles
character_rects_intersect :: proc(a, b: renderer.Rect) -> bool {
	return(
		a.x < b.x + b.width &&
		a.x + a.width > b.x &&
		a.y < b.y + b.height &&
		a.y + a.height > b.y \
	)
}

// Calculate velocity based on character type and behavior
character_calc_velocity :: proc(character: ^Character) {
	if character.state.is_rolling do return

	if character.state.knockback_timer > 0 {
		character.velocity *= KNOCKBACK_FRICTION
		return
	}

	// handle states where movement is disabled
	if character.state.is_dying ||
	   .CAN_MOVE not_in character.tags ||
	   character.state.is_busy ||
	   (dialog_is_active() && .PLAYER in character.tags) ||
	   character.state.is_rolling {
		character.velocity = {0, 0}
		return
	}

	if .PLAYER in character.tags {
		character_calc_player_velocity(character)
	} else if (Character_Tags{.ENEMY, .HAS_AI} <= character.tags) ||
	   (Character_Tags{.NPC, .HAS_AI} <= character.tags) {
		character_calc_ai_velocity(character)
	}
}

// Calculate player velocity from input
character_calc_player_velocity :: proc(character: ^Character) {
	input := input.get_movement()
	character.velocity = input * character.move_speed

	// Update sprite flip state when moving horizontally
	if abs(input.x) > 0 {
		character.state.is_flipped = input.x < 0
	}
}

// Calculate AI velocity (for enemies and NPCs)
character_calc_ai_velocity :: proc(character: ^Character) {
	dt := rl.GetFrameTime()

	character.ai_state.wait_timer -= dt
	character.ai_state.move_timer -= dt

	if character.ai_state.wait_timer <= 0 && character.ai_state.move_timer <= 0 {
		if rand.float32() < 0.3 {
			character.ai_state.wait_timer = rand.float32_range(0.5, 2.0)
			character.velocity = {0, 0}
		} else {
			character.ai_state.move_timer = rand.float32_range(1.0, 3.0)
			angle := rand.float32_range(0, 2 * 3.14159)
			character.ai_state.move_direction = {linalg.cos(angle), linalg.sin(angle)}
			character.velocity = character.ai_state.move_direction * character.move_speed
		}
	} else if character.ai_state.move_timer > 0 {
		character.velocity = character.ai_state.move_direction * character.move_speed
	} else {
		character.velocity = {0, 0}
	}
}

// Calculate animation state based on character behavior
character_calc_state :: proc(character: ^Character) {
	if character.state.is_dying {
		animation_set_state(&character.anim_data, .DEATH, character.state.is_flipped)
	} else if character.state.is_rolling {
		animation_set_state(&character.anim_data, .ROLL, character.state.is_flipped)
	} else if character.state.is_attacking {
		// Use attack direction to determine sprite flip for attack animation
		attack_flip := character.state.attack_direction.x < 0
		animation_set_state(&character.anim_data, .ATTACK, attack_flip)
	} else if character.velocity.x != 0 || character.velocity.y != 0 {
		animation_set_state(&character.anim_data, .RUN, character.velocity.x < 0)
	} else {
		animation_set_state(&character.anim_data, .IDLE, false)
	}
}

// Move character and handle collision
character_move_and_collide :: proc(character: ^Character) {
	next := character.position + character.velocity

	// Apply bounds checking using the same bounds as camera
	half_width := f32(character.width) / 2
	half_height := f32(character.height) / 2

	character.position.x = clamp(
		next.x,
		camera_bounds.x + half_width,
		camera_bounds.x + camera_bounds.width - half_width,
	)
	character.position.y = clamp(
		next.y,
		camera_bounds.y + half_height,
		camera_bounds.y + camera_bounds.height - half_height,
	)
}

// Dialog messages for different character types
goblin_messages := []Dialog_Message {
	{text = "Grr! What do you want, human?", speaker = "Goblin"},
	{text = "I'm just passing through.", speaker = "Hollie"},
	{text = "Well then, be on your way!", speaker = "Goblin"},
}

skeleton_messages := []Dialog_Message {
	{text = "*rattling bones* Who disturbs my rest?", speaker = "Skeleton"},
	{text = "Sorry, I didn't mean to bother you.", speaker = "Hollie"},
	{text = "*creaking* Very well... move along...", speaker = "Skeleton"},
}

npc_human_messages := []Dialog_Message {
	{text = "Oh, hello there! Nice day, isn't it?", speaker = "Villager"},
	{text = "Yes, it's quite lovely.", speaker = "Hollie"},
	{text = "Safe travels, friend!", speaker = "Villager"},
}

// Handle player input
character_handle_player_input :: proc(character: ^Character) {
	if .PLAYER not_in character.tags || dialog_is_active() do return

	if input.is_pressed(.Accept) {
		// Try to interact with nearby character
		INTERACTION_RANGE :: 40.0
		target, found := character_find_nearest_interactable(character.position, INTERACTION_RANGE)

		if found {
			target.state.is_busy = true
			// Start dialog based on character race
			if .GOBLIN in target.tags {
				dialog_start(goblin_messages)
			} else if .SKELETON in target.tags {
				dialog_start(skeleton_messages)
			} else if .HUMAN in target.tags {
				dialog_start(npc_human_messages)
			}
		}
	}

	if .CAN_ATTACK in character.tags &&
	   input.is_pressed(.Attack) &&
	   !character.state.is_attacking &&
	   !character.state.is_rolling {
		character.state.is_attacking = true
		character.state.attack_timer = 0
		character.state.attack_hit = false // Reset hit flag for new attack

		// Lock attack direction based on current movement or facing
		input := input.get_movement()
		if linalg.length(input) > 0 {
			// Use current movement direction
			character.state.attack_direction = linalg.normalize(input)
		} else {
			// Use current facing direction if not moving
			character.state.attack_direction = Vec2{character.state.is_flipped ? -1 : 1, 0}
		}

		// Play attack grunt sound
		audio.sound_play(game.sounds["grunt_attack"])
	}

	if .CAN_ROLL in character.tags &&
	   input.is_pressed(.Roll) &&
	   !character.state.is_rolling &&
	   !character.state.is_attacking {
		// Lock current velocity for roll (only roll if moving)
		if linalg.length(character.velocity) > 0 {
			character.velocity = linalg.normalize(character.velocity) * character.roll_speed
			character.state.is_rolling = true
			character.state.roll_timer = 0
			// Play roll grunt sound
			audio.sound_play(game.sounds["grunt_roll"])
		}
	}
}

// Update timers for character actions
character_update_timers :: proc(character: ^Character) {
	dt := rl.GetFrameTime()

	// Hit flash timer (always process)
	if character.state.hit_flash_timer > 0 {
		character.state.hit_flash_timer -= dt
		if character.state.hit_flash_timer < 0 {
			character.state.hit_flash_timer = 0
		}
	}

	// Knockback timer (always process, even when dying)
	if character.state.knockback_timer > 0 {
		character.state.knockback_timer = max(character.state.knockback_timer - dt, 0)
	}

	// Death timer
	if character.state.is_dying {
		character.state.death_timer += 1
		// Death animation completed - character will be removed after this function
		if character.state.death_timer >= DEATH_ANIMATION_DURATION {
			// Keep dying state - actual removal happens in character_system_update
		}
		return // Skip other timers while dying
	}

	// Attack timer
	if character.state.is_attacking {
		character.state.attack_timer += 1
		// Attack animation duration: 10 frames * INTERVAL
		if character.state.attack_timer >= 10 * INTERVAL {
			character.state.is_attacking = false
			character.state.attack_timer = 0
			character.state.attack_hit = false // Reset hit flag when attack ends
		}
	}

	// Roll timer
	if character.state.is_rolling {
		character.state.roll_timer += 1
		// Roll animation duration: 10 frames * INTERVAL
		if character.state.roll_timer >= 10 * INTERVAL {
			character.state.is_rolling = false
			character.state.roll_timer = 0
		}
	}
}

// Check if character's attack hits other characters
character_check_attack_hits :: proc(attacker: ^Character) {
	if !attacker.state.is_attacking do return
	if !(.CAN_ATTACK in attacker.tags) do return
	if attacker.state.attack_hit do return // Already hit this attack cycle
	if attacker.state.is_dying do return // Can't attack while dying

	attack_rect := character_get_attack_rect(attacker)

	for i := len(characters) - 1; i >= 0; i -= 1 {
		target := &characters[i]
		if target == attacker do continue

		// Only attack enemies if player, or attack player if enemy
		// Players can only attack enemies, enemies can only attack players
		// NPCs are friendly and cannot be attacked or attack
		// Can't attack dying characters
		if (.PLAYER in attacker.tags && .ENEMY not_in target.tags) ||
		   (.ENEMY in attacker.tags && .PLAYER not_in target.tags) ||
		   (.NPC in attacker.tags) ||
		   (.NPC in target.tags) ||
		   (target.state.is_dying) {
			continue
		}

		target_rect := character_get_rect(target)

		if character_rects_intersect(attack_rect, target_rect) {
			// Damage the target instead of instantly killing
			target.health -= attacker.attack_damage
			attacker.state.attack_hit = true // Mark that this attack has hit

			// Play attack hit sound
			audio.sound_play(game.sounds["attack_hit"])

			// Play enemy hit sound if target is an enemy
			if .ENEMY in target.tags {
				audio.sound_play(game.sounds["enemy_hit"])
			}

			// Apply hit effects
			target.state.hit_flash_timer = HIT_FLASH_DURATION

			// Calculate knockback direction (from attacker to target)
			knockback_dir := linalg.normalize(target.position - attacker.position)

			target.velocity = knockback_dir * KNOCKBACK_FORCE
			target.state.knockback_timer = KNOCKBACK_DURATION

			// Start death sequence if health drops to zero or below
			if target.health <= 0 {
				// Play death sound for enemies
				if .ENEMY in target.tags {
					audio.sound_play(game.sounds["enemy_death"])
				}
				// Start dying sequence
				target.state.is_dying = true
				target.state.death_timer = 0
				// Stop all other actions but keep knockback
				target.state.is_attacking = false
				target.state.is_rolling = false
			}
		}
	}
}

// Find nearest interactable character
character_find_nearest_interactable :: proc(
	position: Vec2,
	max_distance: f32,
) -> (
	^Character,
	bool,
) {
	nearest_character: ^Character = nil
	nearest_distance := max_distance

	for &character in characters {
		// Can only interact with NPCs that are interactable and not dying
		if !(Character_Tags{.NPC, .IS_INTERACTABLE} <= character.tags) do continue
		if character.state.is_dying do continue

		distance := linalg.distance(position, character.position)
		if distance < nearest_distance {
			nearest_character = &character
			nearest_distance = distance
		}
	}

	return nearest_character, nearest_character != nil
}

// Find nearest character of a specific type
character_find_nearest_with_tag :: proc(
	position: Vec2,
	tag: Character_Tag,
	max_distance: f32,
) -> (
	^Character,
	bool,
) {
	nearest_character: ^Character = nil
	nearest_distance := max_distance

	for &character in characters {
		if !(tag in character.tags) do continue

		distance := linalg.distance(position, character.position)
		if distance < nearest_distance {
			nearest_character = &character
			nearest_distance = distance
		}
	}

	return nearest_character, nearest_character != nil
}

// Update single character
character_update :: proc(character: ^Character) {
	if .PLAYER in character.tags do character_handle_player_input(character)

	character_calc_velocity(character)
	character_calc_state(character)
	character_move_and_collide(character)
	character_update_timers(character)

	if .CAN_ATTACK in character.tags do character_check_attack_hits(character)

	animation_update(&character.anim_data)
}

// Update all characters
character_system_update :: proc() {
	for &character, idx in characters {
		character_update(&character)

		if character.state.is_dying && character.state.death_timer >= DEATH_ANIMATION_DURATION {
			particle_create_explosion(character.position)
			character_destroy(&character)
			unordered_remove(&characters, idx)
		}
	}
}

// Draw single character
character_draw :: proc(character: ^Character) {
	// Draw elliptical shadow underneath character (20% opacity)
	shadow_color := renderer.Colour{0, 0, 0, 48} // 20% opacity black (255 * 0.2 = 51)
	shadow_offset_y: f32 = f32(character.height) / 2 // Position at bottom of character + 2 pixels
	shadow_radius_h := f32(character.width) * 0.4 // Horizontal radius - slightly smaller than character
	shadow_radius_v := f32(character.height) * 0.2 // Vertical radius - much smaller for elliptical shape

	renderer.draw_ellipse(
		character.position.x,
		character.position.y + shadow_offset_y,
		shadow_radius_h,
		shadow_radius_v,
		shadow_color,
	)

	if character.state.hit_flash_timer > 0 {
		flash_intensity := character.state.hit_flash_timer / HIT_FLASH_DURATION
		animation_draw_with_flash(
			&character.anim_data,
			character.position,
			character.color,
			&flash_intensity,
		)
	} else {
		animation_draw(&character.anim_data, character.position, character.color)
	}

	// Debug info
	when ODIN_DEBUG {
		char_rect := character_get_rect(character)
		renderer.draw_rect_outline(
			char_rect.x,
			char_rect.y,
			char_rect.width,
			char_rect.height,
			1,
			renderer.WHITE,
		)

		// Attack rect when attacking
		if character.state.is_attacking && .CAN_ATTACK in character.tags {
			attack_rect := character_get_attack_rect(character)
			renderer.draw_rect_outline(
				attack_rect.x,
				attack_rect.y,
				attack_rect.width,
				attack_rect.height,
				2,
				rl.RED,
			)
		}

		// Debug text
		debug_text := fmt.tprintf(
			"%v HP:%d/%d",
			character.anim_data.current_anim,
			character.health,
			character.max_health,
		)
		renderer.draw_text(
			debug_text,
			int(character.position.x) - 10,
			int(character.position.y) - 20,
			size = 8,
		)
	}
}

// Draw all characters
character_system_draw :: proc() {
	for &character in characters do character_draw(&character)
}

// Get player character (convenience function)
character_get_player :: proc() -> ^Character {
	for &character in characters {
		if .PLAYER in character.tags {
			return &character
		}
	}
	return nil
}
