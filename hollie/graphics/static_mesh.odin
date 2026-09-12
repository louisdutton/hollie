package graphics

import "core:c"
import rl "vendor:raylib"

// Copy into raylib-owned memory: UnloadModel releases both CPU and GPU data.
load_indexed_model :: proc(positions: []Vec3, colors: []Colour, indices: []u16) -> Model {
	assert(len(positions) == len(colors) && len(positions) <= 65536)
	assert(len(indices) % 3 == 0)
	mesh := rl.Mesh {
		vertexCount   = c.int(len(positions)),
		triangleCount = c.int(len(indices) / 3),
	}
	mesh.vertices = cast([^]f32)rl.MemAlloc(c.uint(len(positions) * size_of(Vec3)))
	mesh.colors = cast([^]u8)rl.MemAlloc(c.uint(len(colors) * size_of(Colour)))
	mesh.indices = cast([^]u16)rl.MemAlloc(c.uint(len(indices) * size_of(u16)))
	for position, index in positions {
		for axis in 0 ..< 3 do mesh.vertices[index * 3 + axis] = position[axis]
		color := colors[index]
		mesh.colors[index * 4 + 0] = color.r
		mesh.colors[index * 4 + 1] = color.g
		mesh.colors[index * 4 + 2] = color.b
		mesh.colors[index * 4 + 3] = color.a
	}
	for index, offset in indices do mesh.indices[offset] = index
	rl.UploadMesh(&mesh, false)
	return rl.LoadModelFromMesh(mesh)
}
