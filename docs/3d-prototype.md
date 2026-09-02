# 3D world architecture

Hollie has one world implementation: a two-dimensional gameplay simulation rendered as a 3D scene. Gameplay `x/y` maps to world `x/z`, while model height uses world `y`. Collision maps, AI, combat, doors, and room transitions remain planar by design.

Both gameplay and the debug editor use the same fixed orthographic 3D view. The editor overlays collision cells, entity markers, and its cursor in that scene.

All world models share a directional lighting material with ambient, warm key, and cool fill contributions. Lighting is implemented in file-backed GLSL shaders under `res/shaders`, so replacement models use the same material path.

## Prototype models

Prototype world models are a checked-in subset of Kenney's Prototype Kit under `res/art/kenney/prototype-kit`:

- `floor-square.glb` builds the ground grid;
- `figurine.glb` is shared by every player, NPC, and enemy;
- `crate-color.glb`, `button-floor-round.glb`, and `shape-cube.glb` represent interactive objects;
- `wall.glb` and `wall-doorway-wide.glb` build room and house boundaries;
- `indicator-doorway.glb` marks transitions.

The bundled models are licensed CC0; the original `License.txt` is stored beside them.

The secret room derives walls from its non-rectangular floor mask. Door collider edges stay open, preserving its two-cell bottom entrance extrusion. Olivewood's house is assembled from the same model kit, with its south doorway aligned to the transition collider.

## Animation

Gameplay owns animation states and timing. Those states select native clips embedded in Kenney's rigged figurine (`idle`, `walk`, `die`, `attack-melee-right`, and `holding-both`). Jump and roll retain gameplay-driven motion on top of the model animation. Every character intentionally shares this model during prototyping. Players, enemies, and NPCs retain their last full movement vector and rotate around world `y` to face it, including vertical and diagonal directions; attacks lock facing to their attack vector.

Production models should replace these GLBs through the same model-loading and animation-selection path. There is no parallel sprite renderer to maintain.
