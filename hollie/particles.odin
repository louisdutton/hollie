package hollie

import "core:math"
import "core:math/linalg"
import "core:math/rand"
import "graphics"

// Single particle definition
Particle :: struct {
	position:     Vec2,
	velocity:     Vec2,
	height:       f32,
	rise_speed:   f32,
	dust:         bool,
	lifetime:     f32,
	max_lifetime: f32,
	size:         f32,
	color:        graphics.Colour,
}

// Particle system to manage multiple particles
Particle_System :: struct {
	particles: [dynamic]Particle,
}

// Global particle system
particle_system: Particle_System

// Initialize particle system
particle_system_init :: proc() {
	particle_system.particles = make([dynamic]Particle, 0, 100)
}

// Clean up particle system
particle_system_fini :: proc() {
	delete(particle_system.particles)
}

// Create explosion effect at given position
particle_create_explosion :: proc(position: Vec2) {
	PARTICLE_COUNT :: 15

	for _ in 0 ..< PARTICLE_COUNT {
		// Random direction and speed
		angle := rand.float32() * 2 * 3.14159
		speed := rand.float32_range(50.0, 120.0)
		velocity := Vec2{linalg.cos(angle) * speed, linalg.sin(angle) * speed}

		// Random particle properties
		lifetime := rand.float32_range(0.3, 0.8)
		size := rand.float32_range(2.0, 6.0)

		// Random dust/debris colors (browns, grays, yellows)
		color_variants := []graphics.Colour {
			{139, 116, 84, 255}, // Brown
			{160, 160, 160, 255}, // Gray
			{205, 186, 89, 255}, // Sandy yellow
			{101, 67, 33, 255}, // Dark brown
			{188, 158, 130, 255}, // Light brown
		}
		color := color_variants[rand.int31() % i32(len(color_variants))]

		particle := Particle {
			position     = position,
			velocity     = velocity,
			height       = 3,
			rise_speed   = rand.float32_range(12, 28),
			lifetime     = lifetime,
			max_lifetime = lifetime,
			size         = size,
			color        = color,
		}

		append(&particle_system.particles, particle)
	}
}

// Update all particles
particle_system_update :: proc() {
	dt := min(graphics.get_frame_time(), 0.1)

	// Update particles and remove expired ones
	for i := len(particle_system.particles) - 1; i >= 0; i -= 1 {
		particle := &particle_system.particles[i]

		// Update position
		particle.position.x += particle.velocity.x * dt
		particle.position.y += particle.velocity.y * dt

		// Apply gravity and friction
		particle.height += particle.rise_speed * dt
		particle.velocity *= math.exp(-4 * dt)
		if !particle.dust do particle.rise_speed -= 60 * dt
		particle.height = max(particle.height, 0)

		// Update lifetime
		particle.lifetime -= dt

		// Remove expired particles
		if particle.lifetime <= 0 {
			unordered_remove(&particle_system.particles, i)
		}
	}
}

// Emit by distance travelled, so trails stay evenly spaced at any frame rate.
particle_emit_trail :: proc(
	transform: ^Transform,
	previous: Vec2,
	previous_height: f32,
	was_grounded: bool,
	mounted: bool,
	size_scale: f32 = 1,
	color: graphics.Colour = {191, 174, 145, 90},
) {
	delta := transform.position - previous
	distance := math.sqrt(delta.x * delta.x + delta.y * delta.y)
	if !was_grounded || !transform.grounded || distance <= 0 || distance > 40 {
		transform.dust_distance = 0
		return
	}
	spacing := mounted ? f32(3) : f32(5)
	direction := delta / distance
	side := Vec2{-direction.y, direction.x}
	speed := math.sqrt(
		transform.velocity.x * transform.velocity.x + transform.velocity.y * transform.velocity.y,
	)
	strength := clamp(speed / RIDING_MOVEMENT_PROFILE.max_speed, 0, 1)
	next := spacing - transform.dust_distance
	for next <= distance {
		if len(particle_system.particles) < 512 {
			lifetime := rand.float32_range(0.35, 0.65)
			spread := rand.float32_range(-1, 1) * (mounted ? 3 : 1.5)
			append(
				&particle_system.particles,
				Particle {
					position = previous +
					direction * next -
					direction * (mounted ? -5 : 2) +
					side * spread,
					velocity = -direction * (3 + strength * 7) + side * rand.float32_range(-3, 3),
					height = previous_height +
					(transform.height - previous_height) * next / distance +
					0.8,
					rise_speed = rand.float32_range(2, 5),
					dust = true,
					lifetime = lifetime,
					max_lifetime = lifetime,
					size = rand.float32_range(2, 3.4) * (0.6 + strength) * size_scale,
					color = color,
				},
			)
		}
		next += spacing
	}
	transform.dust_distance = math.mod(transform.dust_distance + distance, spacing)
}

particle_crate_landing :: proc(body: ^Transform, collider: Collider, impact_speed: f32) {
	strength := clamp(impact_speed / 180, 0.2, 1)
	center :=
		body.position +
		Vec2{collider.offset.x + collider.size.x / 2, collider.offset.z + collider.size.z / 2}
	count := int(4 + strength * 6)
	for index in 0 ..< count {
		if len(particle_system.particles) >= 512 do break
		angle := (f32(index) + rand.float32() * 0.5) * 2 * math.PI / f32(count)
		direction := Vec2{math.cos(angle), math.sin(angle)}
		lifetime := rand.float32_range(0.35, 0.65)
		append(
			&particle_system.particles,
			Particle {
				position = center + direction * Vec2{collider.size.x, collider.size.z} * 0.5,
				velocity = direction * (5 + strength * 12),
				height = body.height + collider.offset.y + 0.6,
				rise_speed = rand.float32_range(2, 5),
				dust = true,
				lifetime = lifetime,
				max_lifetime = lifetime,
				size = rand.float32_range(1.5, 2.5) * (0.6 + strength),
				color = {191, 174, 145, 90},
			},
		)
	}
}

// Draw all particles
particle_system_draw :: proc() {
	for &particle in particle_system.particles {
		// Fade out over time
		alpha_factor := particle.lifetime / particle.max_lifetime
		color := particle.color
		color.a = u8(f32(color.a) * alpha_factor)

		// Draw particle as a small circle
		graphics.draw_circle(particle.position.x, particle.position.y, particle.size, color)
	}
}
