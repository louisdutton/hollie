package spatial

import "core:math/linalg"

Vec3 :: linalg.Vector3f32

Box :: struct {
	min: Vec3,
	max: Vec3,
}

boxes_intersect :: proc(a, b: Box) -> bool {
	return(
		a.min.x < b.max.x &&
		a.max.x > b.min.x &&
		a.min.y < b.max.y &&
		a.max.y > b.min.y &&
		a.min.z < b.max.z &&
		a.max.z > b.min.z \
	)
}
