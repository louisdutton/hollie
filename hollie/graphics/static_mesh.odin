package graphics

import "core:c"
import "core:math"
import rl "vendor:raylib"

// Copy into raylib-owned memory: UnloadModel releases both CPU and GPU data.
load_indexed_model :: proc(
	positions: []Vec3,
	colors: []Colour,
	indices: []u16,
	texcoords: []Vec2,
	with_normals: bool = false,
) -> Model {
	assert(len(positions) == len(colors) && len(positions) <= 65536)
	assert(len(positions) == len(texcoords))
	assert(len(indices) % 3 == 0)
	mesh := rl.Mesh {
		vertexCount   = c.int(len(positions)),
		triangleCount = c.int(len(indices) / 3),
	}
	mesh.vertices = cast([^]f32)rl.MemAlloc(c.uint(len(positions) * size_of(Vec3)))
	mesh.colors = cast([^]u8)rl.MemAlloc(c.uint(len(colors) * size_of(Colour)))
	mesh.indices = cast([^]u16)rl.MemAlloc(c.uint(len(indices) * size_of(u16)))
	mesh.texcoords = cast([^]f32)rl.MemAlloc(c.uint(len(texcoords) * size_of(Vec2)))
	for position, index in positions {
		for axis in 0 ..< 3 do mesh.vertices[index * 3 + axis] = position[axis]
		mesh.texcoords[index * 2] = texcoords[index].x
		mesh.texcoords[index * 2 + 1] = texcoords[index].y
		color := colors[index]
		mesh.colors[index * 4 + 0] = color.r
		mesh.colors[index * 4 + 1] = color.g
		mesh.colors[index * 4 + 2] = color.b
		mesh.colors[index * 4 + 3] = color.a
	}
	for index, offset in indices do mesh.indices[offset] = index
	if with_normals {
		mesh.normals = cast([^]f32)rl.MemAlloc(c.uint(len(positions) * size_of(Vec3)))
		for i in 0 ..< len(positions) * 3 do mesh.normals[i] = 0
		for i := 0; i < len(indices); i += 3 {
			a, b, c := indices[i], indices[i + 1], indices[i + 2]
			u, v := positions[b] - positions[a], positions[c] - positions[a]
			n := Vec3{u.y * v.z - u.z * v.y, u.z * v.x - u.x * v.z, u.x * v.y - u.y * v.x}
			length := math.sqrt(n.x * n.x + n.y * n.y + n.z * n.z)
			if length <= 0 do continue
			n /= length
			for index in indices[i:i + 3] {
				// Keep the front normal when explicit reverse-winding faces reuse vertices.
				if mesh.normals[int(index) * 3] != 0 || mesh.normals[int(index) * 3 + 1] != 0 || mesh.normals[int(index) * 3 + 2] != 0 do continue
				for axis in 0 ..< 3 do mesh.normals[int(index) * 3 + axis] = n[axis]
			}
		}
	}
	rl.UploadMesh(&mesh, false)
	return rl.LoadModelFromMesh(mesh)
}
