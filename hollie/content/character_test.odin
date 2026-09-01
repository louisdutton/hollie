package content

import "core:testing"

@(test)
test_character_kind_wire_names :: proc(t: ^testing.T) {
	for expected_name, expected_kind in CHARACTER_KIND_WIRE_NAMES {
		kind, decoded := character_kind_from_wire(expected_name)
		testing.expect(t, decoded, "known character kind should decode")
		if decoded do testing.expect_value(t, kind, expected_kind)

		name, encoded := character_kind_to_wire(expected_kind)
		testing.expect(t, encoded, "known character kind should encode")
		if encoded do testing.expect_value(t, name, expected_name)
	}

	_, decoded := character_kind_from_wire("orc")
	testing.expect(t, !decoded, "unknown character kind should not decode")
}
