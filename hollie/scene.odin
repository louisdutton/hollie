package hollie

import "audio"
import "tween"

Scene :: enum {
	Title = 0,
	Gameplay,
}

// Input handlers request a change; resource teardown waits until the updater returns.
scene_request :: proc(state: ^Game_State, screen: Scene) {
	state.pending_scene = screen
}

scene_update :: proc(
	state: ^Game_State,
	dt: f32,
	update_scene: proc(_: Scene, _: f32) = scene_update_current,
	change_scene: proc(_: Scene, _: Scene) = scene_change,
) {
	update_scene(state.scene, dt)
	pending := state.pending_scene
	state.pending_scene = nil
	if state.state == .Exiting do return
	if screen, ok := pending.?; ok && screen != state.scene {
		change_scene(state.scene, screen)
		state.scene = screen
	}
}

scene_update_current :: proc(screen: Scene, dt: f32) {
	switch screen {
	case .Title:
		audio.music_update(game.music)
		update_title_screen(dt)
	case .Gameplay: gameplay_update(dt)
	}
}

@(private)
scene_change :: proc(previous, screen: Scene) {
	// Scene tweens borrow addresses in scene state and must not outlive it.
	tween.clear()
	// Unload current screen
	switch previous {
	case .Title: unload_title_screen()
	case .Gameplay: gameplay_fini()
	}

	// Init next screen
	switch screen {
	case .Title:
		audio.music_play(game.music)
		init_title_screen()
	case .Gameplay:
		audio.music_stop(game.music)
		gameplay_init()
	}

}
