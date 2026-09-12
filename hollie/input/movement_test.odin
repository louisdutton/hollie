package input

import "../graphics"
import "core:testing"

@(test)
test_movement_input_preserves_stick_tilt_and_limits_diagonal_speed :: proc(t: ^testing.T) {
	testing.expect_value(t, combine_movement_input({}, {0.1, 0.1}), graphics.Vec2{})
	partial := combine_movement_input({}, {0.5, 0})
	testing.expect(t, abs(partial.x - 0.375) < 0.001)
	diagonal := combine_movement_input({1, 1}, {1, 1})
	testing.expect(t, abs(diagonal.x * diagonal.x + diagonal.y * diagonal.y - 1) < 0.001)
	testing.expect_value(t, combine_movement_input({}, {}), graphics.Vec2{})
}
