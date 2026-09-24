package hollie

import "core:testing"

@(test)
test_environment_cloud_drift_is_frame_rate_independent :: proc(t: ^testing.T) {
	slow, fast := ENVIRONMENT_DAY, ENVIRONMENT_DAY
	for i in 0 ..< 30 do environment_update(&slow, 1.0 / 30)
	for i in 0 ..< 120 do environment_update(&fast, 1.0 / 120)
	testing.expect(t, abs(slow.cloud_offset.x - fast.cloud_offset.x) < 0.0001)
	testing.expect(t, abs(slow.cloud_offset.y - fast.cloud_offset.y) < 0.0001)
	testing.expect(t, abs(slow.cloud_offset.x - slow.wind_velocity.x) < 0.0001)
	previous := slow.cloud_offset
	environment_update(&slow, 0)
	environment_update(&slow, -1)
	testing.expect_value(t, slow.cloud_offset, previous)
	testing.expect_value(t, slow.sun_color, ENVIRONMENT_DAY.sun_color)
	testing.expect_value(t, slow.cloud_coverage, ENVIRONMENT_DAY.cloud_coverage)
}
