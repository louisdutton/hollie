package graphics

import "core:c"
import "core:math"
import rl "vendor:raylib"

Vec3 :: rl.Vector3
Bounding_Box :: rl.BoundingBox
Camera3D :: rl.Camera3D
Camera_Projection :: rl.CameraProjection
Model :: rl.Model
Model_Animation :: rl.ModelAnimation
Shader :: rl.Shader
Render_Texture2D :: rl.RenderTexture2D
Matrix :: rl.Matrix
Pixel_Format :: rl.PixelFormat

ORTHOGRAPHIC :: rl.CameraProjection.ORTHOGRAPHIC

load_model :: #force_inline proc(path: string) -> Model {
	return rl.LoadModel(cstring(raw_data(path)))
}

unload_model :: #force_inline proc(model: Model) {
	rl.UnloadModel(model)
}

model_is_loaded :: #force_inline proc(model: Model) -> bool {
	return model.meshCount > 0
}

model_uses_gpu_skinning :: proc(model: ^Model) -> bool {
	for mesh_index in 0 ..< int(model.meshCount) {
		mesh := &model.meshes[mesh_index]
		if mesh.boneWeights != nil && mesh.animVertices == nil do return true
	}
	return false
}

get_model_bounding_box :: #force_inline proc(model: Model) -> Bounding_Box {
	return rl.GetModelBoundingBox(model)
}

// Include the current pose even when raylib skins vertices on the GPU.
get_model_bone_index :: proc(model: Model, name: string) -> int {
	for index in 0 ..< int(model.skeleton.boneCount) {
		if string(cstring(&model.skeleton.bones[index].name[0])) == name do return index
	}
	return -1
}

get_animated_model_bounding_box :: proc(model: Model, bone_filter: int = -1) -> Bounding_Box {
	bounds := Bounding_Box {
		min = {1e9, 1e9, 1e9},
		max = {-1e9, -1e9, -1e9},
	}
	for mesh_index in 0 ..< int(model.meshCount) {
		mesh := model.meshes[mesh_index]
		for vertex_index in 0 ..< int(mesh.vertexCount) {
			if bone_filter >= 0 {
				matches := false
				if mesh.boneWeights != nil && mesh.boneIndices != nil {
					for influence in 0 ..< 4 {
						index := vertex_index * 4 + influence
						if int(mesh.boneIndices[index]) == bone_filter && mesh.boneWeights[index] > 0 do matches = true
					}
				}
				if !matches do continue
			}
			index := vertex_index * 3
			position := [4]f32 {
				mesh.vertices[index],
				mesh.vertices[index + 1],
				mesh.vertices[index + 2],
				1,
			}
			if mesh.animVertices != nil {
				position = {
					mesh.animVertices[index],
					mesh.animVertices[index + 1],
					mesh.animVertices[index + 2],
					1,
				}
			} else if mesh.boneWeights != nil && model.boneMatrices != nil {
				skinned: [4]f32
				for influence in 0 ..< 4 {
					bone_index := vertex_index * 4 + influence
					weight := mesh.boneWeights[bone_index]
					if weight == 0 do continue
					skinned +=
						(model.boneMatrices[mesh.boneIndices[bone_index]] * position) * weight
				}
				position = skinned
			}
			for axis in 0 ..< 3 {
				bounds.min[axis] = min(bounds.min[axis], position[axis])
				bounds.max[axis] = max(bounds.max[axis], position[axis])
			}
		}
	}
	return bounds
}

load_model_animations :: #force_inline proc(path: string, count: ^c.int) -> [^]Model_Animation {
	return rl.LoadModelAnimations(cstring(raw_data(path)), count)
}

// Layer a model-space yaw onto a rigid-part bone after sampling its animation.
rotate_model_bone_y :: proc(model: Model, bone: int, pivot: Vec3, angle: f32) {
	if bone < 0 || bone >= int(model.skeleton.boneCount) || model.boneMatrices == nil do return
	sine, cosine := math.sin(angle), math.cos(angle)
	rotation: Matrix
	rotation[0, 0], rotation[0, 2] = cosine, sine
	rotation[1, 1] = 1
	rotation[2, 0], rotation[2, 2] = -sine, cosine
	rotation[3, 3] = 1
	rotation[0, 3] = pivot.x - cosine * pivot.x - sine * pivot.z
	rotation[2, 3] = pivot.z + sine * pivot.x - cosine * pivot.z
	transform_model_bone(model, bone, rotation)
}

rotate_model_bone_z :: proc(model: Model, bone: int, pivot: Vec3, angle: f32) {
	sine, cosine := math.sin(angle), math.cos(angle)
	rotation: Matrix
	rotation[0, 0], rotation[0, 1] = cosine, -sine
	rotation[1, 0], rotation[1, 1] = sine, cosine
	rotation[2, 2], rotation[3, 3] = 1, 1
	rotation[0, 3] = pivot.x - cosine * pivot.x + sine * pivot.y
	rotation[1, 3] = pivot.y - sine * pivot.x - cosine * pivot.y
	transform_model_bone(model, bone, rotation)
}

transform_model_bone :: proc(model: Model, bone: int, rotation: Matrix) {
	if bone < 0 || bone >= int(model.skeleton.boneCount) || model.boneMatrices == nil do return
	model.boneMatrices[bone] = rotation * model.boneMatrices[bone]
	// GPU skinning consumes the modified matrix directly. Update the CPU
	// fallback too; these baked rigid parts have one bone per vertex.
	for mesh_index in 0 ..< int(model.meshCount) {
		mesh := model.meshes[mesh_index]
		if mesh.animVertices == nil || mesh.boneIndices == nil || mesh.boneWeights == nil do continue
		for vertex in 0 ..< int(mesh.vertexCount) {
			if int(mesh.boneIndices[vertex * 4]) != bone || mesh.boneWeights[vertex * 4] != 1 do continue
			i := vertex * 3
			position :=
				rotation *
				[4]f32{mesh.animVertices[i], mesh.animVertices[i + 1], mesh.animVertices[i + 2], 1}
			for axis in 0 ..< 3 do mesh.animVertices[i + axis] = position[axis]
			if mesh.animNormals != nil {
				normal :=
					rotation *
					[4]f32 {
							mesh.animNormals[i],
							mesh.animNormals[i + 1],
							mesh.animNormals[i + 2],
							0,
						}
				for axis in 0 ..< 3 do mesh.animNormals[i + axis] = normal[axis]
			}
		}
		rl.UpdateMeshBuffer(mesh, 0, mesh.animVertices, mesh.vertexCount * 3 * size_of(f32), 0)
		if mesh.animNormals != nil do rl.UpdateMeshBuffer(mesh, 2, mesh.animNormals, mesh.vertexCount * 3 * size_of(f32), 0)
	}
}

unload_model_animations :: #force_inline proc(animations: [^]Model_Animation, count: c.int) {
	rl.UnloadModelAnimations(animations, count)
}

update_model_animation :: #force_inline proc(
	model: Model,
	animation: Model_Animation,
	frame: f32,
) {
	rl.UpdateModelAnimation(model, animation, frame)
}

update_model_animation_blended :: #force_inline proc(
	model: Model,
	previous: Model_Animation,
	previous_frame: f32,
	current: Model_Animation,
	current_frame: f32,
	blend: f32,
) {
	rl.UpdateModelAnimationEx(model, previous, previous_frame, current, current_frame, blend)
}

draw_model :: #force_inline proc(
	model: Model,
	position, rotation_axis: Vec3,
	rotation_angle: f32,
	scale: Vec3,
	tint: Colour,
	bank: f32 = 0,
	bank_axis: Vec3 = {},
	bank_pivot: Vec3 = {},
) {
	draw_position, axis, angle := position, rotation_axis, rotation_angle
	if bank != 0 {
		// Compose the world-space bank with the model's facing rotation.
		a := bank_axis * math.sin(bank / 2)
		aw := math.cos(bank / 2)
		b := rotation_axis * math.sin(math.to_radians(rotation_angle) / 2)
		bw := math.cos(math.to_radians(rotation_angle) / 2)
		cross := Vec3{a.y * b.z - a.z * b.y, a.z * b.x - a.x * b.z, a.x * b.y - a.y * b.x}
		q := a * bw + b * aw + cross
		qw := aw * bw - (a.x * b.x + a.y * b.y + a.z * b.z)
		length := math.sqrt(q.x * q.x + q.y * q.y + q.z * q.z)
		if length > 0 {
			axis = q / length
			angle = math.to_degrees(2 * math.atan2(length, qw))
		}
		v := position - bank_pivot
		cross_v := Vec3 {
			bank_axis.y * v.z - bank_axis.z * v.y,
			bank_axis.z * v.x - bank_axis.x * v.z,
			bank_axis.x * v.y - bank_axis.y * v.x,
		}
		dot := bank_axis.x * v.x + bank_axis.y * v.y + bank_axis.z * v.z
		draw_position =
			bank_pivot +
			v * math.cos(bank) +
			cross_v * math.sin(bank) +
			bank_axis * dot * (1 - math.cos(bank))
	}
	rl.DrawModelEx(model, draw_position, axis, angle, scale, tint)
}

draw_cube :: #force_inline proc(position, size: Vec3, color: Colour) {
	rl.DrawCubeV(position, size, color)
}

draw_cube_outline :: #force_inline proc(position, size: Vec3, color: Colour) {
	rl.DrawCubeWiresV(position, size, color)
}

draw_sphere :: #force_inline proc(position: Vec3, radius: f32, color: Colour) {
	rl.DrawSphere(position, radius, color)
}

begin_mode_3d :: #force_inline proc(camera: Camera3D) {
	rl.BeginMode3D(camera)
}

end_mode_3d :: #force_inline proc() {
	rl.EndMode3D()
}

get_world_to_screen :: #force_inline proc(position: Vec3, camera: Camera3D) -> Vec2 {
	return rl.GetWorldToScreen(position, camera)
}

get_camera_view_matrix :: #force_inline proc(camera: ^Camera3D) -> Matrix {
	return rl.GetCameraViewMatrix(camera)
}

get_camera_projection_matrix :: #force_inline proc(camera: ^Camera3D, aspect: f32) -> Matrix {
	return rl.GetCameraProjectionMatrix(camera, aspect)
}

load_shader :: #force_inline proc(vertex_path, fragment_path: cstring) -> Shader {
	return rl.LoadShader(vertex_path, fragment_path)
}

unload_shader :: #force_inline proc(shader: Shader) {
	rl.UnloadShader(shader)
}

shader_is_loaded :: #force_inline proc(shader: Shader) -> bool {
	return rl.IsShaderValid(shader)
}

get_shader_location :: #force_inline proc(shader: Shader, name: cstring) -> c.int {
	return rl.GetShaderLocation(shader, name)
}

set_shader_float :: #force_inline proc(shader: Shader, location: c.int, value: ^f32) {
	rl.SetShaderValue(shader, location, value, .FLOAT)
}

set_shader_vec2 :: #force_inline proc(shader: Shader, location: c.int, value: ^f32) {
	rl.SetShaderValue(shader, location, value, .VEC2)
}

set_shader_vec3 :: #force_inline proc(shader: Shader, location: c.int, value: ^Vec3) {
	rl.SetShaderValue(shader, location, value, .VEC3)
}

set_shader_int :: #force_inline proc(shader: Shader, location: c.int, value: ^c.int) {
	rl.SetShaderValue(shader, location, value, .INT)
}

set_shader_matrix :: #force_inline proc(shader: Shader, location: c.int, value: Matrix) {
	rl.SetShaderValueMatrix(shader, location, value)
}

begin_shader :: #force_inline proc(shader: Shader) {
	rl.BeginShaderMode(shader)
}

end_shader :: #force_inline proc() {
	rl.EndShaderMode()
}

begin_render_texture :: #force_inline proc(target: Render_Texture2D) {
	rl.BeginTextureMode(target)
}

end_render_texture :: #force_inline proc() {
	rl.EndTextureMode()
}
