# 3D prototype

Hollie's gameplay remains a two-dimensional simulation. Rendering maps the existing room plane into 3D as follows:

- gameplay `x` becomes world `x`;
- gameplay `y` becomes world `z`;
- model height uses world `y`;
- collision maps, AI, combat, doors, and room files remain unchanged.

The gameplay view uses a fixed orthographic 3D camera. The debug editor deliberately retains its direct 2D view so room geometry and collision cells remain easy to author.

## Prototype assets

File-backed OBJ models live under `res/art/prototype/3d`:

- `tile.obj` is the textured ground plane;
- `pawn.obj` is shared by every character;
- `object.obj` represents holdables, pressure plates, and gates;
- `house.obj` replaces flat scenery in the current Olivewood slice.

The secret room derives low prototype walls from the boundary of its non-rectangular floor. Door collider edges are left open, so its two-cell entrance extrusion remains visible and traversable.

Character animation state and frame timing still come from the existing animator. For this experiment, frames drive simple model transforms such as bobbing, jumping, attacking, falling, and rolling. A production 3D direction would replace those transforms with rigged model clips without changing gameplay state selection.

## Intentional experiment boundaries

- The room editor is still 2D.
- Gameplay collision is still planar.
- Models use deliberately plain prototype materials.
- There is no production lighting, skeletal animation, or camera occlusion handling yet.
- The 2D renderer and raster assets remain available, making the experiment reversible.
