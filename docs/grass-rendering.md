# Demo meadow rendering

The implementation is informed by recreations, not a claim to reproduce Nintendo's proprietary BOTW/TOTK renderer:

- [WalkingFat's BOTW study](https://walkingfat.com/还原《塞尔达-旷野之息》的草地/): terrain-aligned grass lighting, height-masked transmission/highlights, coherent wind, and anchored bending that avoids stretching.
- [Smyth's WebGL recreation](https://smythdesign.com/blog/stylized-grass-webgl/): five-vertex blades and shared world-space colour/cloud fields.

The demo retains 36 blades per tile, five indexed vertices per blade, and cached 4×4-tile meshes. UVs carry the same world-space root for every vertex of a blade. Wind and interaction are sampled at that root, then bend a constant-curvature centreline. Its analytic arc length stays fixed; the two mesh segments approximate that arc. Ground vertices bypass bending.

Rooms author grass blades independently from their floor material through the optional `layers.grass` array. Each cell is an unsigned density from 0 (no blades) to 255 (all 36 deterministic blade placements). Missing layers contain no blades, and intermediate densities retain a stable subset across reloads. Grass floor tiles retain their continuous meadow ground treatment even where the blade density is zero.

Ground and grass share one subtle, broad albedo field and the same ambient, key and fill light uniforms as the world through the shared [environment lighting](environment-rendering.md) state. Stable per-blade resting lean overlaps neighbouring silhouettes without adding geometry. Curvature-derived normals and a restrained upper-leaf sheen reveal travelling wind fronts under the shared key light. Resting lean, wind, live body contact, and fading trails all feed the same directional constant-curvature displacement. Shadows sample displaced positions. Meadow and wind noise are evaluated at vertices. Cloud shading is currently removed.

The meadow palette blends fresh green and light yellow-green to complement the stylised turquoise water, retaining saturation without returning to dark olive tones. Upper leaves receive a subtle yellow-green tint; roots retain the shared ground colour. The existing lighting, shadows, and wind sheen remain unchanged.

Moving players, animals, NPCs, and unheld boxes share collider-sized live bending and recovery trails. Mounted animals supply the footprint instead of their riders; carried, swimming, and vertically separated bodies are excluded. Each chunk accepts up to 32 overlapping live contacts, replacing the two player-only slots. Trails retain the existing 64-imprint budget, lifetime, and chunk filtering. Room unload and editor entry release cached meshes. No geometry is regenerated each frame.

Visual matching and frame-time measurements require an in-game review. Automated Odin checks do not validate runtime GLSL compilation or the visual result.
