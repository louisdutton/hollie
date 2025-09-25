package hollie

import "core:fmt"
import "core:math/linalg"
import "core:math/rand"
import "renderer"
import rl "vendor:raylib"

// Character types
Character_Type :: enum {
	PLAYER,
	NPC, // Friendly, can talk to
	ENEMY, // Hostile, can attack
}

// Behavior flags for different character capabilities
Character_Behavior_Flags :: bit_set[Character_Behavior_Flag]
Character_Behavior_Flag :: enum {
	CAN_MOVE,
	CAN_ATTACK,
	CAN_ROLL,
	CAN_INTERACT,
	HAS_AI,
	IS_INTERACTABLE,
}

// Character states for behavior management
Character_State :: struct {
	is_attacking:       bool,
	attack_timer:       u32,
	attack_hit:         bool, // has this attack already hit a target
	is_rolling:         bool,
	roll_timer:         u32,
	is_busy:            bool, // locked in dialog or other activity
	is_flipped:         bool, // sprite flip state

	// Hit effects
	hit_flash_timer:    f32,
	knockback_velocity: Vec2,
	knockback_timer:    f32,
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
	color:         rl.Color,

	// Type and behavior
	type:          Character_Type,
	race:          Character_Race, // What kind of character (goblin, skeleton, human)
	behaviors:     Character_Behavior_Flags,

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

// Character collections
characters: [dynamic]Character

// Constants
DEFAULT_MOVE_SPEED :: 1.5
DEFAULT_ROLL_SPEED :: 3.0
DEFAULT_ENEMY_MOVE_SPEED :: 1.0
DEFAULT_ATTACK_RANGE :: 32.0
DEFAULT_ATTACK_WIDTH :: 24.0
DEFAULT_ATTACK_HEIGHT :: 16.0

// Health constants
DEFAULT_PLAYER_HEALTH :: 100
DEFAULT_ENEMY_HEALTH :: 30
DEFAULT_NPC_HEALTH :: 50
DEFAULT_ATTACK_DAMAGE :: 20

// Hit effect constants
HIT_FLASH_DURATION :: 0.2
KNOCKBACK_FORCE :: 5.0
KNOCKBACK_DURATION :: 0.3

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
character_create :: proc(
	pos: Vec2,
	char_type: Character_Type,
	char_race: Character_Race,
	behaviors: Character_Behavior_Flags,
	anim_files: []string,
	frame_counts: []int,
) -> ^Character {
	character := Character {
		position      = pos,
		width         = 16,
		height        = 16,
		velocity      = {0, 0},
		color         = rl.WHITE,
		type          = char_type,
		race          = char_race,
		behaviors     = behaviors,
		move_speed    = DEFAULT_MOVE_SPEED,
		roll_speed    = DEFAULT_ROLL_SPEED,
		attack_damage = DEFAULT_ATTACK_DAMAGE,
		attack_range  = DEFAULT_ATTACK_RANGE,
		attack_width  = DEFAULT_ATTACK_WIDTH,
		attack_height = DEFAULT_ATTACK_HEIGHT,
	}

	// Adjust defaults based on type
	switch char_type {
	case .ENEMY:
		character.move_speed = DEFAULT_ENEMY_MOVE_SPEED
		character.health = DEFAULT_ENEMY_HEALTH
		character.max_health = DEFAULT_ENEMY_HEALTH
		character.ai_state.wait_timer = rand.float32_range(0, 2.0)
	case .PLAYER:
		character.move_speed = DEFAULT_MOVE_SPEED
		character.health = DEFAULT_PLAYER_HEALTH
		character.max_health = DEFAULT_PLAYER_HEALTH
	case .NPC:
		character.move_speed = DEFAULT_MOVE_SPEED * 0.8
		character.health = DEFAULT_NPC_HEALTH
		character.max_health = DEFAULT_NPC_HEALTH
	}

	// Initialize animation
	animation_init(&character.anim_data, anim_files, frame_counts)

	append(&characters, character)

	return &characters[len(characters) - 1]
}

// Create a character with pre-loaded textures (for composite humans)
character_create_with_textures :: proc(
	pos: Vec2,
	char_type: Character_Type,
	char_race: Character_Race,
	behaviors: Character_Behavior_Flags,
	textures: []rl.Texture2D,
	frame_counts: []int,
) -> ^Character {
	character := Character {
		position      = pos,
		width         = 16,
		height        = 16,
		velocity      = {0, 0},
		color         = rl.WHITE,
		type          = char_type,
		race          = char_race,
		behaviors     = behaviors,
		move_speed    = DEFAULT_MOVE_SPEED,
		roll_speed    = DEFAULT_ROLL_SPEED,
		attack_damage = DEFAULT_ATTACK_DAMAGE,
		attack_range  = DEFAULT_ATTACK_RANGE,
		attack_width  = DEFAULT_ATTACK_WIDTH,
		attack_height = DEFAULT_ATTACK_HEIGHT,
	}

	// Adjust defaults based on type
	switch char_type {
	case .ENEMY:
		character.move_speed = DEFAULT_ENEMY_MOVE_SPEED
		character.health = DEFAULT_ENEMY_HEALTH
		character.max_health = DEFAULT_ENEMY_HEALTH
		character.ai_state.wait_timer = rand.float32_range(0, 2.0)
	case .PLAYER:
		character.move_speed = DEFAULT_MOVE_SPEED
		character.health = DEFAULT_PLAYER_HEALTH
		character.max_health = DEFAULT_PLAYER_HEALTH
	case .NPC:
		character.move_speed = DEFAULT_MOVE_SPEED * 0.8
		character.health = DEFAULT_NPC_HEALTH
		character.max_health = DEFAULT_NPC_HEALTH
	}

	// Initialize animation with pre-loaded textures
	animation_init_with_textures(&character.anim_data, textures, frame_counts)

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

// Get character rectangle for collision
character_get_rect :: proc(character: ^Character) -> rl.Rectangle {
	return rl.Rectangle {
		character.position.x - f32(character.width) / 2,
		character.position.y - f32(character.height) / 2,
		f32(character.width),
		f32(character.height),
	}
}

// Get attack rectangle
character_get_attack_rect :: proc(character: ^Character) -> rl.Rectangle {
	attack_offset_x: f32 =
		character.state.is_flipped ? -character.attack_range : character.attack_range
	attack_x := character.position.x + attack_offset_x - character.attack_width / 2
	attack_y := character.position.y - character.attack_height / 2

	return rl.Rectangle{attack_x, attack_y, character.attack_width, character.attack_height}
}

// Check collision between two rectangles
character_rects_intersect :: proc(rect1, rect2: rl.Rectangle) -> bool {
	return rl.CheckCollisionRecs(rect1, rect2)
}

// Calculate velocity based on character type and behavior
character_calc_velocity :: proc(character: ^Character) {
	// Handle knockback first - it overrides normal movement
	if character.state.knockback_timer > 0 {
		character.velocity = character.state.knockback_velocity
		return
	}

	if !(.CAN_MOVE in character.behaviors) {
		character.velocity = {0, 0}
		return
	}

	if dialog_is_active() && character.type == .PLAYER {
		character.velocity = {0, 0}
		return
	}

	if character.state.is_busy {
		character.velocity = {0, 0}
		return
	}

	if character.state.is_rolling {
		return // Keep current velocity during roll
	}

	switch character.type {
	case .PLAYER:
		character_calc_player_velocity(character)
	case .ENEMY, .NPC:
		if .HAS_AI in character.behaviors {
			character_calc_ai_velocity(character)
		}
	}
}

// Calculate player velocity from input
character_calc_player_velocity :: proc(character: ^Character) {
	input := input_get_movement()
	character.velocity.x = input.x * character.move_speed
	character.velocity.y = input.y * character.move_speed

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
	if character.state.is_rolling {
		animation_set_state(&character.anim_data, .ROLL, character.state.is_flipped)
	} else if character.state.is_attacking {
		animation_set_state(&character.anim_data, .ATTACK, character.state.is_flipped)
	} else if character.velocity.x != 0 || character.velocity.y != 0 {
		animation_set_state(&character.anim_data, .RUN, character.velocity.x < 0)
	} else {
		animation_set_state(&character.anim_data, .IDLE, false)
	}
}

// Move character and handle collision
character_move_and_collide :: proc(character: ^Character) {
	new_x := character.position.x + character.velocity.x
	new_y := character.position.y + character.velocity.y

	// Apply bounds checking using the same bounds as camera
	half_width := f32(character.width) / 2
	half_height := f32(character.height) / 2

	character.position.x = clamp(
		new_x,
		camera_bounds.x + half_width,
		camera_bounds.x + camera_bounds.width - half_width,
	)
	character.position.y = clamp(
		new_y,
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
	if character.type != .PLAYER do return
	if dialog_is_active() do return

	if input_pressed(.Accept) {
		// Try to interact with nearby character
		INTERACTION_RANGE :: 40.0
		target, found := character_find_nearest_interactable(character.position, INTERACTION_RANGE)

		if found {
			target.state.is_busy = true
			// Start dialog based on character race
			switch target.race {
			case Character_Race.GOBLIN:
				dialog_start(goblin_messages)
			case Character_Race.SKELETON:
				dialog_start(skeleton_messages)
			case Character_Race.HUMAN:
				dialog_start(npc_human_messages)
			}
		}
	}

	if .CAN_ATTACK in character.behaviors &&
	   input_pressed(.Attack) &&
	   !character.state.is_attacking &&
	   !character.state.is_rolling {
		character.state.is_attacking = true
		character.state.attack_timer = 0
		character.state.attack_hit = false // Reset hit flag for new attack
		// Play attack grunt sound
		sound_collection_play_random(game_state.grunt_attack)
	}

	if .CAN_ROLL in character.behaviors &&
	   input_pressed(.Roll) &&
	   !character.state.is_rolling &&
	   !character.state.is_attacking {
		// Lock current velocity for roll (only roll if moving)
		if linalg.length(character.velocity) > 0 {
			character.velocity = linalg.normalize(character.velocity) * character.roll_speed
			character.state.is_rolling = true
			character.state.roll_timer = 0
			// Play roll grunt sound
			sound_collection_play_random(game_state.grunt_roll)
		}
	}
}

// Update timers for character actions
character_update_timers :: proc(character: ^Character) {
	dt := rl.GetFrameTime()

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

	// Hit flash timer
	if character.state.hit_flash_timer > 0 {
		character.state.hit_flash_timer -= dt
		if character.state.hit_flash_timer < 0 {
			character.state.hit_flash_timer = 0
		}
	}

	// Knockback timer
	if character.state.knockback_timer > 0 {
		character.state.knockback_timer -= dt
		if character.state.knockback_timer <= 0 {
			character.state.knockback_timer = 0
			character.state.knockback_velocity = {0, 0}
		} else {
			// Apply friction to knockback
			friction: f32 = 0.85
			character.state.knockback_velocity.x *= friction
			character.state.knockback_velocity.y *= friction
		}
	}
}

// Check if character's attack hits other characters
character_check_attack_hits :: proc(attacker: ^Character) {
	if !attacker.state.is_attacking do return
	if !(.CAN_ATTACK in attacker.behaviors) do return
	if attacker.state.attack_hit do return // Already hit this attack cycle

	attack_rect := character_get_attack_rect(attacker)

	for i := len(characters) - 1; i >= 0; i -= 1 {
		target := &characters[i]
		if target == attacker do continue

		// Only attack enemies if player, or attack player if enemy
		// Players can only attack enemies, enemies can only attack players
		// NPCs are friendly and cannot be attacked or attack
		if (attacker.type == .PLAYER && target.type != .ENEMY) ||
		   (attacker.type == .ENEMY && target.type != .PLAYER) ||
		   (attacker.type == .NPC) ||
		   (target.type == .NPC) { 	// NPCs don't attack// NPCs can't be attacked
			continue
		}

		target_rect := character_get_rect(target)

		if character_rects_intersect(attack_rect, target_rect) {
			// Damage the target instead of instantly killing
			target.health -= attacker.attack_damage
			attacker.state.attack_hit = true // Mark that this attack has hit

			// Play attack hit sound
			sound_collection_play_random(game_state.attack_hit)

			// Play enemy hit sound if target is an enemy
			if target.type == .ENEMY {
				sound_collection_play_random(game_state.enemy_hit)
			}

			// Apply hit effects
			target.state.hit_flash_timer = HIT_FLASH_DURATION

			// Calculate knockback direction (from attacker to target)
			knockback_dir := linalg.normalize(target.position - attacker.position)
			target.state.knockback_velocity = knockback_dir * KNOCKBACK_FORCE
			target.state.knockback_timer = KNOCKBACK_DURATION

			// Remove character if health drops to zero or below
			if target.health <= 0 {
				// Play death sound for enemies
				if target.type == .ENEMY {
					sound_play(game_state.enemy_death)
				}
				character_destroy(target)
				unordered_remove(&characters, i)
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
		if !(.IS_INTERACTABLE in character.behaviors) do continue

		// Can only interact with NPCs (friendly), not enemies
		if character.type != .NPC do continue

		distance := linalg.distance(position, character.position)
		if distance < nearest_distance {
			nearest_character = &character
			nearest_distance = distance
		}
	}

	return nearest_character, nearest_character != nil
}

// Find nearest character of a specific type
character_find_nearest_of_type :: proc(
	position: Vec2,
	char_type: Character_Type,
	max_distance: f32,
) -> (
	^Character,
	bool,
) {
	nearest_character: ^Character = nil
	nearest_distance := max_distance

	for &character in characters {
		if character.type != char_type do continue

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
	if character.type == .PLAYER {
		character_handle_player_input(character)
	}

	character_calc_velocity(character)
	character_calc_state(character)
	character_move_and_collide(character)
	character_update_timers(character)

	if .CAN_ATTACK in character.behaviors {
		character_check_attack_hits(character)
	}

	animation_update(&character.anim_data)
}

// Update all characters
character_system_update :: proc() {
	for &character in characters {
		character_update(&character)
	}
}

// Draw single character
character_draw :: proc(character: ^Character) {
	if character.state.hit_flash_timer > 0 {
		// Use shader-based white flash
		flash_intensity := character.state.hit_flash_timer / HIT_FLASH_DURATION
		animation_draw_with_flash(
			&character.anim_data,
			character.position,
			character.color,
			&flash_intensity,
		)
	} else {
		// Normal drawing
		animation_draw(&character.anim_data, character.position, character.color)
	}

	// Debug info
	when ODIN_DEBUG {
		// Character bounds
		char_rect := character_get_rect(character)
		debug_color := rl.GREEN
		switch character.type {
		case .PLAYER: debug_color = rl.BLUE
		case .ENEMY: debug_color = rl.RED
		case .NPC: debug_color = rl.YELLOW
		}

		renderer.draw_rect_outline(
			char_rect.x,
			char_rect.y,
			char_rect.width,
			char_rect.height,
			1,
			debug_color,
		)

		// Attack rect when attacking
		if character.state.is_attacking && .CAN_ATTACK in character.behaviors {
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
		using character.anim_data
		debug_text := fmt.tprintf(
			"%v %v HP:%d/%d",
			current_anim,
			character.type,
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
	for &character in characters {
		character_draw(&character)
	}
}

// Get all characters of a specific type
character_get_all_of_type :: proc(char_type: Character_Type) -> []^Character {
	result := make([dynamic]^Character)

	for &character in characters {
		if character.type == char_type {
			append(&result, &character)
		}
	}

	return result[:]
}

// Get player character (convenience function)
character_get_player :: proc() -> ^Character {
	for &character in characters {
		if character.type == .PLAYER {
			return &character
		}
	}
	return nil
}
