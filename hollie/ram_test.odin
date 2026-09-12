package hollie

import "core:testing"

@(test)
test_ram_detects_swept_head_on_contact :: proc(t: ^testing.T) {
	body := AABB {
		min = {0, 0, 0},
		max = {10, 10, 10},
	}
	wall := AABB {
		min = {11, 0, -10},
		max = {12, 18, 20},
	}
	time, speed, hit := ram_contact(body, wall, {140, 0}, 1.0 / 120)
	testing.expect(t, hit)
	testing.expect(t, abs(time - 1.0 / 140) < 0.0001)
	testing.expect(t, speed >= BISON_RAM_SPEED)
	_, _, away := ram_contact(body, wall, {-140, 0}, 0.1)
	testing.expect(t, !away)
	body.min.y, body.max.y = 20, 30
	_, _, above := ram_contact(body, wall, {140, 0}, 0.1)
	testing.expect(t, !above)
}

@(test)
test_ram_glancing_contact_uses_normal_speed :: proc(t: ^testing.T) {
	body := AABB {
		min = {0, 0, 0},
		max = {10, 10, 10},
	}
	wall := AABB {
		min = {10.1, 0, -100},
		max = {12, 18, 100},
	}
	_, speed, hit := ram_contact(body, wall, {20, 138}, 1.0 / 120)
	testing.expect(t, hit)
	testing.expect(t, speed < BISON_RAM_SPEED)
}
