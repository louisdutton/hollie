# Painterly water

Water uses broad teal washes, sparse curved strokes, warm broken foam, and small
ambient waves. Procedural strokes keep the surface editable without a bitmap
asset. Existing gameplay wakes contribute displacement, normal variation and
foam. Buoyancy continues to use the fixed gameplay surface height.

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

Automated tests cover diagonal shore distances, tile-seam continuity, room edges
and changed occupancy. GPU shader compilation, appearance and performance need
an in-game review on a graphical machine. Review narrow channels, concave banks,
swimmers, overlapping wakes, cast shadows, camera zoom, and water edits. Refraction,
directional wakes, flow maps and cached water meshes remain future work.
