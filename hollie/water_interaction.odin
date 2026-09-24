package hollie

import "core:math"
import "graphics"

WATER_FOAM_CONTACTS :: 16
WATER_FOAM_TRAILS :: 64
WATER_FOAM_LIFETIME :: f32(1.3)

Water_Foam_Contact :: struct {
	position, radius, direction: Vec2,
	speed:                       f32,
}

Water_Foam_Trail :: struct {
	start, end:            Vec2,
	radius, strength, age: f32,
}

Water_Foam_State :: struct {
	contacts:      [WATER_FOAM_CONTACTS]Water_Foam_Contact,
	contact_count: int,
	trails:        [WATER_FOAM_TRAILS]Water_Foam_Trail,
	next:          int,
}

water_foam: Water_Foam_State

water_interaction_fini :: proc() {
	water_foam = {}
}

// Sample actual travelled distance. Segments form one footprint; the shader
// dissolves a shared foam pattern through it rather than drawing each segment.
water_foam_track :: proc(state: ^Water_Foam_State, body: ^Transform, bounds: Aabb, wet: bool) {
	if !wet || bounds.min.y >= WATER_SURFACE || bounds.max.y <= WATER_SURFACE {
		body.water_contact_valid = false
		return
	}
	center := Vec2{(bounds.min.x + bounds.max.x) * 0.5, (bounds.min.z + bounds.max.z) * 0.5}
	radius := Vec2 {
		max((bounds.max.x - bounds.min.x) * 0.5, 3),
		max((bounds.max.z - bounds.min.z) * 0.5, 3),
	}
	speed := math.sqrt(body.velocity.x * body.velocity.x + body.velocity.y * body.velocity.y)
	direction := speed > 0.1 ? body.velocity / speed : Vec2{0, 1}
	if state.contact_count < WATER_FOAM_CONTACTS {
		state.contacts[state.contact_count] = {center, radius, direction, clamp(speed / 60, 0, 1)}
		state.contact_count += 1
	}
	delta := center - body.water_previous_position
	distance := math.sqrt(delta.x * delta.x + delta.y * delta.y)
	if !body.water_contact_valid || distance > 40 {
		body.water_previous_position = center
		body.water_contact_valid = true
		return
	}
	width := clamp(min(radius.x, radius.y), 3, 14)
	spacing := max(width * 0.4, 2)
	if distance < spacing do return
	travel := delta / distance
	for distance >= spacing {
		start := body.water_previous_position
		end := start + travel * spacing
		state.trails[state.next] = {
			start    = start,
			end      = end,
			radius   = width,
			strength = clamp(speed / 60, 0.35, 1),
		}
		state.next = (state.next + 1) % WATER_FOAM_TRAILS
		body.water_previous_position = end
		distance -= spacing
	}
}

water_update_interactions :: proc(dt: f32) {
	if dt <= 0 do return
	water_foam.contact_count = 0
	for &trail in water_foam.trails do trail.age = min(trail.age + dt, WATER_FOAM_LIFETIME)
	for &entity in world.entities {
		body: ^Transform
		collider: Collider
		switch &e in entity {
		case Player:
			if riding_animal_for_player(e.index) != nil {
				e.water_contact_valid = false
				continue
			}
			body, collider = &e.transform, e.collider
		case Enemy: body, collider = &e.transform, e.collider
		case Npc: body, collider = &e.transform, e.collider
		case Holdable:
			if e.held_by != 0 {
				e.water_contact_valid = false
				continue
			}
			body, collider = &e.transform, e.collider
		case Pressure_Plate, Gate, Door: continue
		}
		bounds := collision_aabb_at(body.position, collider, body.height)
		center := Vec2{(bounds.min.x + bounds.max.x) * 0.5, (bounds.min.z + bounds.max.z) * 0.5}
		water_foam_track(&water_foam, body, bounds, water_at(center))
	}
}

water_bind_interactions :: proc(shader: graphics.Shader) {
	contacts, headings: [WATER_FOAM_CONTACTS][4]f32
	for i in 0 ..< water_foam.contact_count {
		contact := water_foam.contacts[i]
		contacts[i] = {contact.position.x, contact.position.y, contact.radius.x, contact.radius.y}
		headings[i] = {contact.direction.x, contact.direction.y, contact.speed, 1}
	}
	starts, ends: [WATER_FOAM_TRAILS][4]f32
	for trail, i in water_foam.trails {
		if trail.strength <= 0 || trail.age >= WATER_FOAM_LIFETIME do continue
		starts[i] = {trail.start.x, trail.start.y, trail.radius, trail.age / WATER_FOAM_LIFETIME}
		ends[i] = {trail.end.x, trail.end.y, trail.strength, 1}
	}
	graphics.set_shader_vec4_array(
		shader,
		graphics.get_shader_location(shader, "foam_contacts[0]"),
		contacts[:],
	)
	graphics.set_shader_vec4_array(
		shader,
		graphics.get_shader_location(shader, "foam_headings[0]"),
		headings[:],
	)
	graphics.set_shader_vec4_array(
		shader,
		graphics.get_shader_location(shader, "foam_starts[0]"),
		starts[:],
	)
	graphics.set_shader_vec4_array(
		shader,
		graphics.get_shader_location(shader, "foam_ends[0]"),
		ends[:],
	)
}
