package hollie

import "core:testing"

@(test)
test_environment_day_night_toggle_restores_complete_presets :: proc(t: ^testing.T) {
	state := ENVIRONMENT_DAY
	environment_toggle_period(&state)
	testing.expect_value(t, state, ENVIRONMENT_NIGHT)
	testing.expect(t, state.ambient.x < ENVIRONMENT_DAY.ambient.x)
	testing.expect(t, state.sun_color.y < ENVIRONMENT_DAY.sun_color.y)
	testing.expect(t, state.water_light_floor.z < ENVIRONMENT_DAY.water_light_floor.z)
	environment_toggle_period(&state)
	testing.expect_value(t, state, ENVIRONMENT_DAY)
}
