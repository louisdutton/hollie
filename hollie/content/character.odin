package content

Character_Kind :: enum {
	GOBLIN,
	SKELETON,
	HUMAN,
}

CHARACTER_KIND_WIRE_NAMES := [Character_Kind]string {
	.GOBLIN   = "goblin",
	.SKELETON = "skeleton",
	.HUMAN    = "human",
}

character_kind_from_wire :: proc(name: string) -> (Character_Kind, bool) {
	for candidate, kind in CHARACTER_KIND_WIRE_NAMES {
		if candidate == name do return kind, true
	}
	return {}, false
}

character_kind_to_wire :: proc(kind: Character_Kind) -> (string, bool) {
	index := int(kind)
	if index < 0 || index >= len(CHARACTER_KIND_WIRE_NAMES) do return "", false
	return CHARACTER_KIND_WIRE_NAMES[kind], true
}
