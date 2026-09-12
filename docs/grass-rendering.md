# Demo meadow rendering

The implementation is informed by recreations, not a claim to reproduce Nintendo's proprietary BOTW/TOTK renderer:

- [WalkingFat's BOTW study](https://walkingfat.com/还原《塞尔达-旷野之息》的草地/): terrain-aligned grass lighting, height-masked transmission/highlights, coherent wind, and anchored bending that avoids stretching.
- [Smyth's WebGL recreation](https://smythdesign.com/blog/stylized-grass-webgl/): five-vertex blades and shared world-space colour/cloud fields.

The demo retains 36 blades per tile, five indexed vertices per blade, and cached 4×4-tile meshes. UVs carry the same world-space root for every vertex of a blade. Wind and interaction are sampled at that root, then bend a constant-curvature centreline. Its analytic arc length stays fixed; the two mesh segments approximate that arc. Ground vertices bypass bending.

Ground and grass share one broad albedo field and the same ambient, key and fill light uniforms as the world. Terrain-aligned normals prevent independently lit ribbon faces. Upper-leaf transmission and soft highlights depend on the light and camera; moving cloud cover attenuates direct light. Shadows sample displaced positions. Noise is evaluated at vertices instead of every fragment.

Player trails retain the existing lifetime and chunk filtering. Room unload and editor entry release cached meshes. No geometry is regenerated each frame.

Visual matching and frame-time measurements require an in-game review. Automated Odin checks do not validate runtime GLSL compilation or the visual result.
