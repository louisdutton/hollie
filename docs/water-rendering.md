# Graphic stylised water

The surface uses clear turquoise colour fields, a lighter shore band, cream foam,
and broad warped cellular patterns. Two offset pattern layers suggest a darker
underwater pattern and a sparse light surface pattern. Small ambient swells remain;
normal/specular lighting is secondary to the graphic shapes.

## Interaction shapes

Bodies intersecting the surface receive an irregular foam collar. Moving bodies
also get a curved front crest, oriented by movement and scaled by speed. Neither
effect emits expanding rings. Their outlines are warped and broken by the same
world-space pattern used across the water.

A bounded history of connected, distance-sampled segments records actual movement.
The shader unions their footprints into a short wake, narrows it with age, and
dissolves the shared cellular foam pattern into irregular patches. Segment outlines
are never rendered. The trail remains on the travelled path when a body turns or
stops. Stopping emits no new segments; contact foam remains while old wake patches
fade. Leaving water, spawning, teleporting, mounting and being picked up reset
contact history to prevent streaks across gaps.

There are at most 16 body contacts and 64 history segments, lasting 1.3 seconds.
Arrays are uploaded as shader uniforms; there is no water simulation grid or
per-frame texture upload. Excess history overwrites the oldest slot. Source shapes
approximate the waterline from collider bounds rather than sampling scene depth.
Swimming continues to emit no sphere/dust particles, and buoyancy is unchanged.

## Shoreline and shading

Once per level load, tile-centre water occupancy is reconstructed as a bilinear
field sampled eight times per tile. Marching triangles partition that field into
matching land and water polygons, rounding tile corners without moving tile centres.
Diagonal saddle ties resolve toward land to avoid connecting diagonal pools.
The contour is extruded down to the flat bed for bank walls. Interior land retains
its existing geometry; affected tiles use cached land, grass, bank, bed and water
meshes. Grass roots in water are omitted. Non-grass generated bankside land uses
a neutral earth tint rather than the original floor-model texture.

The RGBA8 distance-to-bank texture is generated from those exact contour segments,
with eight samples per tile. It drives shore colour, scalloped contact foam, broken
approaching bands and wave damping. Water-contact and bed-height queries use the
same triangulated field, not square tile boundaries. The shallow tint remains artistic.

Meshes and the foam texture are built only in room initialization and released on
unload. Drawing never checks occupancy for changes or rebuilds the shoreline. The
editor's existing exit/reload path regenerates them on the next level load.

World lighting and shadows are retained with a minimum ambient contribution so
cream foam reads in shade. Ambient swells use the cached subdivided surface.
Texture unit 11 is reserved for shore distance; shadows use unit 10.

## References and verification

- [Daniel Ilett's stylised water](https://danielilett.com/2020-04-05-tut5-3-urp-stylised-water/): warped cellular foam, offset light/dark patterns and intersection foam. Here the pattern is procedural GLSL and contacts come from colliders.
- [Caycee Martindale's water and ripples](https://caycee_martindale.artstation.com/projects/8BNKN6): textured water interaction with controlled travel and dissolve. This implementation uses a body-attached crest and a dissolving movement footprint.
- [Spirit Crossing ocean shader](https://hazelstagner.gay/2025/03/21/spirit-crossing-ocean-shader/): deliberately shaped surface layers and foam.
- [Cyanilux shoreline breakdown](https://www.cyanilux.com/tutorials/shoreline-shader-breakdown/): shore gradients and broken foam.

Automated checks cover connected travel sampling, turns, stationary contact, exits,
teleports, swimming particle suppression and shore distances. The removed solver's
propagation tests no longer describe this effect. GPU shader compilation, visual
balance and performance still require a graphical review: swim straight, turn,
stop, cross a bank, ride a turtle, and compare lit/shadowed water at gameplay zoom.
