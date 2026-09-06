package renderer

import "core:c"

RL_ATTACHMENT_DEPTH :: c.int(100)
RL_ATTACHMENT_TEXTURE2D :: c.int(100)
SHADER_UNIFORM_INT :: c.int(0)

foreign import raylib_rlgl "system:raylib"

@(default_calling_convention = "c", link_prefix = "rl")
foreign raylib_rlgl {
	LoadFramebuffer :: proc() -> c.uint ---
	EnableFramebuffer :: proc(id: c.uint) ---
	DisableFramebuffer :: proc() ---
	LoadTextureDepth :: proc(width, height: c.int, use_render_buffer: bool) -> c.uint ---
	FramebufferAttach :: proc(fbo_id, texture_id: c.uint, attach_type, texture_type, mip_level: c.int) ---
	FramebufferComplete :: proc(id: c.uint) -> bool ---
	UnloadFramebuffer :: proc(id: c.uint) ---
	EnableShader :: proc(id: c.uint) ---
	ActiveTextureSlot :: proc(slot: c.int) ---
	EnableTexture :: proc(id: c.uint) ---
	SetUniform :: proc(location: c.int, value: rawptr, uniform_type, count: c.int) ---
}

load_framebuffer :: #force_inline proc() -> c.uint {return LoadFramebuffer()}
enable_framebuffer :: #force_inline proc(id: c.uint) {EnableFramebuffer(id)}
disable_framebuffer :: #force_inline proc() {DisableFramebuffer()}
load_texture_depth :: #force_inline proc(width, height: c.int, use_render_buffer: bool) -> c.uint {
	return LoadTextureDepth(width, height, use_render_buffer)
}
framebuffer_attach :: #force_inline proc(
	fbo_id, texture_id: c.uint,
	attach_type, texture_type, mip_level: c.int,
) {
	FramebufferAttach(fbo_id, texture_id, attach_type, texture_type, mip_level)
}
framebuffer_complete :: #force_inline proc(id: c.uint) -> bool {return FramebufferComplete(id)}
unload_framebuffer :: #force_inline proc(id: c.uint) {UnloadFramebuffer(id)}
enable_shader :: #force_inline proc(id: c.uint) {EnableShader(id)}
active_texture_slot :: #force_inline proc(slot: c.int) {ActiveTextureSlot(slot)}
enable_texture :: #force_inline proc(id: c.uint) {EnableTexture(id)}
set_uniform :: #force_inline proc(location: c.int, value: rawptr, uniform_type, count: c.int) {
	SetUniform(location, value, uniform_type, count)
}
