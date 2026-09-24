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

The existing cached RGBA8 distance-to-bank texture stays in use, including diagonal
corners and room edges. Four samples per tile are bilinearly interpolated. Tile
edits refresh it; teardown releases it. It drives shore colour, scalloped contact
foam, broken approaching bands and wave damping. The shallow tint is artistic;
the bed remains flat and the bank geometry remains square.

World lighting and shadows are retained with a minimum ambient contribution so
cream foam reads in shade. Ambient swells use the existing 4×4 cells per tile.
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
