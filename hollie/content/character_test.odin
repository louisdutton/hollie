package content

import "core:testing"

@(test)
test_character_kind_wire_names :: proc(t: ^testing.T) {
	for expected_kind in Character_Kind {
		expected_name, named := character_kind_to_wire(expected_kind)
		testing.expect(t, named, "known character kind should have a name")
		if !named do continue

		kind, decoded := character_kind_from_wire(expected_name)
		testing.expect(t, decoded, "known character kind should decode")
		if decoded do testing.expect_value(t, kind, expected_kind)
	}

	goblin_name, _ := character_kind_to_wire(.Goblin)
	testing.expect_value(t, goblin_name, "Goblin")

	_, decoded := character_kind_from_wire("Orc")
	testing.expect(t, !decoded, "unknown character kind should not decode")
}
