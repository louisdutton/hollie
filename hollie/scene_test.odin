package hollie

import "core:testing"

Scene_Test_State :: struct {
	app:             Game_State,
	scene_alive:     bool,
	update_finished: bool,
	changes:         int,
	quit:            bool,
}

scene_test_update :: proc(screen: Scene, dt: f32) {
	state := cast(^Scene_Test_State)context.user_ptr
	assert(screen == .Gameplay && state.scene_alive)
	assert(dt == 0.025)
	scene_request(&state.app, .Title)
	// The outgoing updater can finish while its resources are still alive.
	assert(state.app.scene == .Gameplay && state.scene_alive)
	if state.quit do state.app.state = .Exiting
	state.update_finished = true
}

scene_test_change :: proc(previous, next: Scene) {
	state := cast(^Scene_Test_State)context.user_ptr
	assert(state.update_finished && state.scene_alive)
	assert(previous == .Gameplay && next == .Title)
	state.scene_alive = false
	state.changes += 1
}

@(test)
test_scene_change_waits_for_outgoing_update_to_finish :: proc(t: ^testing.T) {
	state := Scene_Test_State {
		app = {scene = .Gameplay},
		scene_alive = true,
	}
	context.user_ptr = &state
	scene_update(&state.app, 0.025, scene_test_update, scene_test_change)
	testing.expect(t, state.update_finished)
	testing.expect_value(t, state.changes, 1)
	testing.expect_value(t, state.app.scene, Scene.Title)
	testing.expect(t, state.app.pending_scene == nil)
}

@(test)
test_quitting_does_not_load_a_pending_scene :: proc(t: ^testing.T) {
	state := Scene_Test_State {
		app = {scene = .Gameplay},
		scene_alive = true,
		quit = true,
	}
	context.user_ptr = &state
	scene_update(&state.app, 0.025, scene_test_update, scene_test_change)
	testing.expect(t, state.update_finished && state.scene_alive)
	testing.expect_value(t, state.changes, 0)
	testing.expect_value(t, state.app.scene, Scene.Gameplay)
	testing.expect(t, state.app.pending_scene == nil)
}
