package content

import "core:reflect"

Character_Kind :: enum {
	Goblin,
	Skeleton,
	Human,
}

character_kind_from_wire :: proc(name: string) -> (Character_Kind, bool) {
	return reflect.enum_from_name(Character_Kind, name)
}

character_kind_to_wire :: proc(kind: Character_Kind) -> (string, bool) {
	return reflect.enum_name_from_value(kind)
}
