package hollie

import "core:testing"

@(test)
test_room_registry_discovers_shipped_rooms_by_id :: proc(t: ^testing.T) {
	registry, registry_error := room_registry_load("res/maps", "res")
	defer destroy_room_registry_error(&registry_error)
	testing.expect_value(t, registry_error.kind, Room_Registry_Error_Kind.none)
	if registry_error.kind != .none do return
	defer destroy_room_registry(&registry)

	testing.expect_value(t, len(registry.entries), 3)
	if len(registry.entries) != 3 do return
	testing.expect_value(t, registry.entries[0].id, "desert")
	testing.expect_value(t, registry.entries[1].id, "olivewood")
	testing.expect_value(t, registry.entries[2].id, "small_room")

	olivewood, found := room_registry_find(&registry, "olivewood")
	testing.expect(t, found, "olivewood should be addressable by stable room ID")
	if found do testing.expect_value(t, olivewood.name, "Olivewood")

	_, missing := room_registry_find(&registry, "missing")
	testing.expect(t, !missing, "unknown room IDs should not resolve")
}
