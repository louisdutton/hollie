# Demo meadow rendering

The implementation is informed by recreations, not a claim to reproduce Nintendo's proprietary BOTW/TOTK renderer:

- [WalkingFat's BOTW study](https://walkingfat.com/还原《塞尔达-旷野之息》的草地/): terrain-aligned grass lighting, height-masked transmission/highlights, coherent wind, and anchored bending that avoids stretching.
- [Smyth's WebGL recreation](https://smythdesign.com/blog/stylized-grass-webgl/): five-vertex blades and shared world-space colour/cloud fields.

The demo retains 36 blades per tile, five indexed vertices per blade, and cached 4×4-tile meshes. UVs carry the same world-space root for every vertex of a blade. Wind and interaction are sampled at that root, then bend a constant-curvature centreline. Its analytic arc length stays fixed; the two mesh segments approximate that arc. Ground vertices bypass bending.

Rooms author grass blades independently from their floor material through the optional `layers.grass` array. Each cell is an unsigned density from 0 (no blades) to 255 (all 36 deterministic blade placements). Missing layers contain no blades, and intermediate densities retain a stable subset across reloads. Grass floor tiles retain their continuous meadow ground treatment even where the blade density is zero.

Ground and grass share one subtle, broad albedo field and the same ambient, key and fill light uniforms as the world. Stable per-blade resting lean overlaps neighbouring silhouettes without adding geometry. Curvature-derived normals and a restrained upper-leaf sheen reveal travelling wind fronts under the shared key light. Broad moving cloud cover gently attenuates direct light. Resting lean, wind, live player contact, and fading trails all feed the same directional constant-curvature displacement. Shadows sample displaced positions. Noise is evaluated at vertices instead of every fragment.

The meadow palette blends light, desaturated sage and mint to complement the stylised turquoise water. Upper leaves receive a subtle warm pastel tint; roots retain the shared ground colour. The existing lighting, shadows, and wind sheen remain unchanged.

Player trails retain the existing lifetime and chunk filtering. Room unload and editor entry release cached meshes. No geometry is regenerated each frame.

Visual matching and frame-time measurements require an in-game review. Automated Odin checks do not validate runtime GLSL compilation or the visual result.
