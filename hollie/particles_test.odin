package hollie

import "core:testing"

// Called by the dust-trail test so global particle state is not shared by
// concurrently running tests.
check_landing_dust_requires_a_dry_impact_transition :: proc(t: ^testing.T) {
	saved_particles := particle_system
	particle_system = {}
	defer {
		delete(particle_system.particles)
		particle_system = saved_particles
	}
	body := Transform {
		position = {10, 20},
		height   = 12,
		grounded = true,
	}
	collider := Collider {
		size   = {16, 20, 12},
		offset = {-8, 2, -6},
	}
	particle_emit_landing(&body, collider, true, 100)
	particle_emit_landing(&body, collider, false, 20)
	body.grounded = false
	particle_emit_landing(&body, collider, false, 100)
	body.grounded = true
	body.swimming = true
	particle_emit_landing(&body, collider, false, 100)
	testing.expect_value(t, len(particle_system.particles), 0)
	body.swimming = false
	particle_emit_landing(&body, collider, false, 100)
	count := len(particle_system.particles)
	testing.expect(t, count > 0)
	for particle in particle_system.particles {
		testing.expect(t, particle.dust)
		testing.expect_value(t, particle.height, f32(14.6))
	}
	particle_emit_landing(&body, collider, true, 100)
	testing.expect_value(t, len(particle_system.particles), count)
}
