# Art pipeline

The world-art pipeline is 3D and resolution independent. Room files store logical grid, collision, structure bounds, and entities; they do not reference tileset or scenery images.

## Coordinate contract

- `grid.tile_size` defines one gameplay cell in world units.
- Gameplay `x/y` maps to 3D `x/z`.
- Model scale is derived from gameplay bounds, independently of source mesh dimensions.
- Collision and interaction bounds never come from render meshes.

This keeps map behavior stable when prototype models are replaced with final models.

## Prototype asset policy

Active prototype world art is a minimal GLB subset of the Kenney Prototype Kit in `res/art/kenney/prototype-kit`. Use the same anonymous figurine for every character and the same generic models for repeated gameplay roles. The goal is legibility and mechanics, not visual identity.

Do not introduce runtime-generated primitives as world art or a second 2D world renderer. Debug overlays may use renderer primitives because they visualize collision and authoring state rather than shipped art. UI may continue to use raster assets.

Final art should use a stylized, hand-crafted 3D look rather than pixel art, entering through this existing GLB loading, transform, material, and native-animation path.
