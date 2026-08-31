package hollie

import "core:testing"

@(test)
test_room_registry_discovers_shipped_rooms_by_id :: proc(t: ^testing.T) {
	registry, registry_error := room_registry_load("res/maps", "res")
	defer destroy_room_registry_error(&registry_error)
	testing.expect_value(t, registry_error.kind, Room_Registry_Error_Kind.none)
	if registry_error.kind != .none do return
	defer destroy_room_registry(&registry)

	testing.expect(t, len(registry.entries) >= 3, "all shipped rooms should be discovered")
	for index in 1 ..< len(registry.entries) {
		testing.expect(
			t,
			registry.entries[index - 1].id < registry.entries[index].id,
			"room registry order should be deterministic",
		)
	}

	olivewood, found := room_registry_find(&registry, "olivewood")
	testing.expect(t, found, "olivewood should be addressable by stable room ID")
	if found do testing.expect_value(t, olivewood.name, "Olivewood")
	_, desert_found := room_registry_find(&registry, "desert")
	testing.expect(t, desert_found, "desert should be registered")
	_, small_room_found := room_registry_find(&registry, "small_room")
	testing.expect(t, small_room_found, "small_room should be registered")

	_, missing := room_registry_find(&registry, "missing")
	testing.expect(t, !missing, "unknown room IDs should not resolve")
}
