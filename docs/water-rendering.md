# Painterly water

Water uses broad teal washes, sparse curved strokes, warm broken foam, and small
ambient waves. Procedural strokes keep the surface editable without a bitmap
asset. Swimming does not emit dust/sphere particles. Buoyancy continues to use
the fixed gameplay surface height.

## Interactive surface

Moving bodies drive a persistent damped height-field wave equation, rather than
depositing rendered circles or ribbons. Each body supplies its previous and current
submerged footprint. Their displaced-volume difference perturbs height; a five-point
Laplacian accelerates neighbouring cells, so disturbances propagate, overlap, reflect
at banks and settle. Still bodies add no forcing. Entry/exit changes displacement;
spawn and teleport establish fresh contact without drawing a path across the room.
Mounted riders and held objects do not duplicate their carrier's interaction.

The CPU grid is bounded to 256 cells on the longest room axis, plus a dry border.
Spacing is at least one world unit and normally one eighth of a tile, increasing
for large rooms. Updates subdivide frame time into steps no longer than 1/120 s,
interpolating body motion within each step. At wave speed 22 the worst-case Courant
number is 0.184, below the 2D stencil limit of 1/sqrt(2). Solid cells use a reflecting
boundary; damping removes energy. Occupancy is refreshed for editor changes.

An RGBA32F texture carries height, two surface derivatives and short-lived turbulence
foam. Rendering samples it for displacement and normals, with restrained foam only
at disturbed locations. Texture unit 12 is reserved for it. Simulation continues
after bodies stop. Signed height also drives restrained light crest and dark trough
tones: normal-only lighting was too subtle at the isometric camera. The tonal
response is continuous, with a 0.10-world-unit half-response, and vanishes exactly
at rest. Shading normals exaggerate the simulated slope by 1.5 for readability;
geometric displacement retains its 0.65 scale. Room/rendering teardown releases
arrays and GPU resources.

This is a linear small-wave solver, not a full shallow-water or fluid-volume solver.
It does not simulate breaking waves, spray, advected currents or feedback into
buoyancy. The CPU implementation makes dynamics testable headlessly; GPU ping-pong
textures are a future option if profiling warrants it. Large rooms lose spatial
detail at the resolution cap. GPU upload cost and in-game appearance need review.

A cached RGBA8 texture stores distance to non-water cells, capped at one tile.
Four samples per tile plus boundary samples provide a continuous bilinear field,
including diagonal corners and room edges. Texel centres coincide with sample
positions. Water occupancy and dimensions are compared before drawing so editor
changes rebuild the texture; room and rendering teardown release it. The field
controls shore tint, opacity, foam and wave damping. Shore tint is an artistic
cue, not actual bed depth, and the bank geometry remains square.

The shader uses the world's ambient, key and fill lights and shadow map, with
an orthographic view direction for restrained highlights. Fine normal ripples
supplement the existing 4×4 surface cells per tile. Banks and volume bottoms stay
anchored. Texture unit 11 holds shoreline data across immediate-mode batch
flushes; the existing shadow map uses unit 10.

References informing the direction:

- [Spirit Crossing ocean shader](https://hazelstagner.gay/2025/03/21/spirit-crossing-ocean-shader/): deliberate crest shapes, warped layers and sparse shimmer. Our strokes are procedural rather than painted textures.
- [Cyanilux shoreline breakdown](https://www.cyanilux.com/tutorials/shoreline-shader-breakdown/): shore gradients, broken foam and travelling bands. Our gradient comes from tile occupancy rather than screen depth or authored UVs.
- [GPU Gems water](https://developer.nvidia.com/gpugems/gpugems/part-i-natural-effects/chapter-1-effective-water-simulation-physical-models): separate geometric waves from finer shading detail.
- [Evan Wallace's WebGL water source](https://github.com/evanw/webgl-water/blob/master/water.js): persistent height/velocity simulation, displaced-volume interaction and normals derived from the resulting height field. Our CPU solver uses explicit world units, bounded timesteps and tile-bank boundaries.
- [SideFX shallow-water introduction](https://www.sidefx.com/docs/houdini/heightfields/shallowintro.html): height-field methods suit ponds and small waves, with stability and breaking-wave limitations. Our linear solver does not implement Houdini's shallow-water model.

Automated tests cover propagation beyond body footprints, displaced-volume balance,
decay, land barriers, still bodies, frame-rate consistency, swimming particle
suppression, diagonal shore distances, tile-seam continuity, room edges and changed
occupancy. GPU shader compilation, appearance and performance need
an in-game review on a graphical machine. Review narrow channels, concave banks,
swimmers, overlapping wakes, cast shadows, camera zoom, and water edits. Refraction,
flow maps and cached water meshes remain future work.
