package hollie

import "core:c"
import "core:math"
import "graphics"
import "tilemap"

WATER_FIELD_MAX_CELLS :: 256

water_field: Water_Field
water_field_texture: graphics.Texture_2D
water_field_dirty: bool
water_disturbances: [dynamic]Water_Disturbance

water_interaction_fini :: proc() {
	if water_field_texture.id != 0 do graphics.unload_texture(water_field_texture)
	water_field_texture = {}
	water_field_fini(&water_field)
	delete(water_disturbances)
	water_disturbances = {}
	water_field_dirty = false
}

water_interaction_prepare :: proc() {
	size := f32(tilemap.get_tile_size())
	extent := Vec2{f32(tilemap.get_tilemap_width()), f32(tilemap.get_tilemap_height())} * size
	if extent.x <= 0 || extent.y <= 0 do return
	spacing := max(max(size / 8, 1), max(extent.x, extent.y) / WATER_FIELD_MAX_CELLS)
	width, height := int(math.ceil(extent.x / spacing)) + 2, int(math.ceil(extent.y / spacing)) + 2
	if water_field.width != width ||
	   water_field.height != height ||
	   water_field.spacing != spacing {
		water_interaction_fini()
		water_field = water_field_init(width, height, spacing)
		water_field_dirty = true
	}
	for y in 1 ..< height - 1 {
		for x in 1 ..< width - 1 {
			i := y * width + x
			point := Vec2{f32(x) - 0.5, f32(y) - 0.5} * spacing
			wet := water_at(point)
			if water_field.wet[i] == wet do continue
			water_field.wet[i] = wet
			water_field.cells[i], water_field.next[i] = {}, {}
			water_field_dirty = true
		}
	}
}

water_update_interactions :: proc(dt: f32) {
	if dt <= 0 do return
	water_interaction_prepare()
	if water_field.width == 0 do return
	clear(&water_disturbances)
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
		radius := Vec2 {
			max(collider.size.x * 0.65, water_field.spacing * 1.5),
			max(collider.size.z * 0.65, water_field.spacing * 1.5),
		}
		depth := f32(0)
		if water_at(center) && bounds.max.y >= WATER_SURFACE {
			depth = clamp(WATER_SURFACE - bounds.min.y, 0, min(radius.x, radius.y) * 0.6)
		}
		previous, previous_depth := body.water_previous_position, body.water_previous_depth
		delta := center - previous
		// Spawn/teleport establishes contact without sweeping across the room.
		if !body.water_contact_valid || delta.x * delta.x + delta.y * delta.y > 40 * 40 {
			previous, previous_depth = center, depth
		}
		if previous_depth > 0 || depth > 0 {
			append(
				&water_disturbances,
				Water_Disturbance{previous, center, radius, previous_depth, depth},
			)
		}
		body.water_previous_position, body.water_previous_depth = center, depth
		body.water_contact_valid = true
	}
	water_field_advance(&water_field, water_disturbances[:], dt)
	water_field_dirty = true
}

water_bind_interactions :: proc(shader: graphics.Shader) {
	water_interaction_prepare()
	if water_field.width == 0 do return
	if water_field_dirty || water_field_texture.id == 0 {
		water_field_encode(&water_field)
		if water_field_texture.id == 0 {
			water_field_texture = graphics.load_texture_float4(
				water_field.pixels,
				water_field.width,
				water_field.height,
			)
		} else {
			graphics.update_texture_float4(water_field_texture, water_field.pixels)
		}
		water_field_dirty = false
	}
	texture_slot := c.int(12)
	graphics.enable_shader(shader.id)
	graphics.active_texture_slot(texture_slot)
	graphics.enable_texture(water_field_texture.id)
	location := graphics.get_shader_location(shader, "interaction_map")
	graphics.set_uniform(location, &texture_slot, graphics.SHADER_UNIFORM_INT, 1)
	graphics.active_texture_slot(0)
	rendering_set_shader_vec3(
		shader,
		"interaction_map_info",
		{f32(water_field.width), f32(water_field.height), water_field.spacing},
	)
}
