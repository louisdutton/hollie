package hollie

import "core:math/linalg"
import "core:math/rand"
import "renderer"
import rl "vendor:raylib"

// Single particle definition
Particle :: struct {
	position:     Vec2,
	velocity:     Vec2,
	lifetime:     f32,
	max_lifetime: f32,
	size:         f32,
	color:        rl.Color,
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

	for _ in 0..<PARTICLE_COUNT {
		// Random direction and speed
		angle := rand.float32() * 2 * 3.14159
		speed := rand.float32_range(50.0, 120.0)
		velocity := Vec2{
			linalg.cos(angle) * speed,
			linalg.sin(angle) * speed,
		}

		// Random particle properties
		lifetime := rand.float32_range(0.3, 0.8)
		size := rand.float32_range(2.0, 6.0)

		// Random dust/debris colors (browns, grays, yellows)
		color_variants := []rl.Color{
			{139, 116, 84, 255},   // Brown
			{160, 160, 160, 255},  // Gray
			{205, 186, 89, 255},   // Sandy yellow
			{101, 67, 33, 255},    // Dark brown
			{188, 158, 130, 255},  // Light brown
		}
		color := color_variants[rand.int31() % i32(len(color_variants))]

		particle := Particle{
			position     = position,
			velocity     = velocity,
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
	dt := rl.GetFrameTime()

	// Update particles and remove expired ones
	for i := len(particle_system.particles) - 1; i >= 0; i -= 1 {
		particle := &particle_system.particles[i]

		// Update position
		particle.position.x += particle.velocity.x * dt
		particle.position.y += particle.velocity.y * dt

		// Apply gravity and friction
		particle.velocity.y += 200.0 * dt  // Gravity
		particle.velocity.x *= 0.98        // Air friction
		particle.velocity.y *= 0.98

		// Update lifetime
		particle.lifetime -= dt

		// Remove expired particles
		if particle.lifetime <= 0 {
			unordered_remove(&particle_system.particles, i)
		}
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
		renderer.draw_circle(
			particle.position.x,
			particle.position.y,
			particle.size,
			color
		)
	}
}