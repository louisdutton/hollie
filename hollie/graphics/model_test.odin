package graphics

import "core:testing"
import rl "vendor:raylib"

@(test)
test_animated_bounds_follow_gpu_skinning_pose :: proc(t: ^testing.T) {
	vertices := [6]f32{-1, 0, -1, 1, 1, 1}
	weights := [8]f32{1, 0, 0, 0, 1, 0, 0, 0}
	indices: [8]u8
	pose: Matrix
	for axis in 0 ..< 4 do pose[axis, axis] = 1
	pose[1, 3] = 2
	matrices := [1]Matrix{pose}
	meshes := [1]rl.Mesh {
		{
			vertexCount = 2,
			vertices = &vertices[0],
			boneWeights = &weights[0],
			boneIndices = &indices[0],
		},
	}
	model := Model {
		meshCount    = 1,
		meshes       = &meshes[0],
		boneMatrices = &matrices[0],
	}
	bounds := get_animated_model_bounding_box(model)
	testing.expect_value(t, bounds.min, Vec3{-1, 2, -1})
	testing.expect_value(t, bounds.max, Vec3{1, 3, 1})
}
