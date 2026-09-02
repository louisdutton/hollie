package hollie

import "core:c"
import rl "vendor:raylib"

RL_ATTACHMENT_DEPTH :: c.int(100)
RL_ATTACHMENT_TEXTURE2D :: c.int(100)

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
