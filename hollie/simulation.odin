package hollie

MAX_SIMULATION_DELTA :: f32(0.1)

// Discard excess time after stalls. UI and scene tweens use unclamped frame time.
simulation_delta_time :: proc(frame_dt: f32) -> f32 {
	return clamp(frame_dt, 0, MAX_SIMULATION_DELTA)
}

// Gameplay phases are ordered: support motion, intent, body motion, puzzles, visuals.
simulation_update :: proc(dt: f32) {
	water_time += dt
	// Moving pads carry their resting bodies before input is evaluated.
	pressure_plate_update_surfaces(dt)
	riding_sync_players()

	player_update_input()
	health_update(dt)
	player_update_movement(dt)
	ai_update_movement(dt)

	simulation_update_positions(dt)
	holdable_update_release_contacts(&world)
	water_update_interactions(dt)
	// Pressure plates must see riders at their post-movement positions.
	riding_sync_players()
	puzzle_update()
	// Gate closure can eject mounts; align riders again before animation and drawing.
	riding_sync_players()
	animation_update_entities(dt)
	grass_update_trail(dt)
	simulation_cleanup_dead(&world)
}

simulation_cleanup_dead :: proc(state: ^World_State) {
	for i := len(state.entities) - 1; i >= 0; i -= 1 {
		switch &e in state.entities[i] {
		case Enemy: if e.is_dying && e.death_timer >= DEATH_DURATION {
					particle_create_explosion(e.position)
					entity_remove_at(i, state)
				}
		case Npc: if e.is_dying && e.death_timer >= DEATH_DURATION {
					particle_create_explosion(e.position)
					entity_remove_at(i, state)
				}
		case Player, Pressure_Plate, Gate, Holdable, Door: continue
		}
	}
}
