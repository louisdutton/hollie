# 3D world architecture

Hollie has one world implementation: a two-dimensional gameplay simulation rendered as a 3D scene. Gameplay `x/y` maps to world `x/z`, while model height uses world `y`. Collision maps, AI, combat, doors, and room transitions remain planar by design.

Entity collision remains box-based. Character, pickup, and pressure-pad footprints, offsets, and debug heights are derived from their loaded GLB bounds at the same scale used for drawing; character footprints use a rotation-invariant square so facing changes do not change collision. Models are grounded from their lower mesh bound. Gates and doors retain their authored gameplay dimensions because their meshes are assembled or scaled to those map-defined areas.

Both gameplay and the debug editor use the same fixed orthographic 3D view. The editor overlays collision cells, entity markers, and its cursor in that scene.

All world models use directional lighting with restrained ambient, warm key, and cool fill contributions. Lighting is implemented in file-backed GLSL shaders under `res/shaders`. Characters automatically select the CPU- or GPU-skinning-compatible vertex path used by the active raylib build. Both paths share one fragment-lighting model, including the pure-white damage-flash blend.

## Prototype models

Prototype world models are a checked-in subset of Kenney's Prototype Kit under `res/art/kenney/prototype-kit`:

- `floor-square.glb` builds the ground grid;
- `figurine-raylib.glb` is shared by every player, NPC, and enemy;
- `crate-color.glb`, `button-floor-square-raylib.glb`, and `shape-cube.glb` represent interactive objects;
- `wall.glb` and `wall-doorway-wide.glb` build room and house boundaries;
- `indicator-doorway.glb` marks transitions.

The bundled models are licensed CC0; the original `License.txt` is stored beside them.
`figurine.glb` is the untouched Kenney source. Its clips animate rigid object nodes,
which raylib does not expose through `LoadModelAnimations`. The checked-in
`figurine-raylib.glb` rigidly skins those same parts and bakes the exact 27 supplied
clips onto bones. Regenerate it with `tools/bake_kenney_figurine.py`; this is a
format-compatibility step, not a replacement animation system.

`button-floor-square.glb` is likewise the untouched pressure-pad source. Its
object-node `toggle`, `toggle-on`, and `toggle-off` clips are baked onto the
two-bone `button-floor-square-raylib.glb` by `tools/bake_kenney_pressure_pad.py`
so raylib can evaluate the supplied motion without a parallel animation path.

The secret room derives walls from its non-rectangular floor mask. Door collider edges stay open, preserving its two-cell bottom entrance extrusion. Olivewood's house is assembled from the same model kit, with its south doorway aligned to the transition collider.

## Animation

Gameplay owns animation states and timing, while all visible character motion comes from native clips embedded in Kenney's rigged figurine. Idle, run, death, and attack select `idle`, `walk`, `die`, and `attack-melee-right`. Carrying uses a baked mask layer: Kenney's `holding-both` locks both arms, rotated upright toward the overhead object, while Kenney's `walk` continues on the legs, torso, and head. The kit has no dedicated jump or roll clips, so both use its `sprint` clip as prototype fallbacks rather than procedural animation. Every character intentionally shares this model during prototyping. Players, enemies, and NPCs retain their last full movement vector and rotate around world `y` to face it, including vertical and diagonal directions; attacks lock facing to their attack vector.

Visible clips play from elapsed time at their authored speed, independently of the legacy sprite-frame counters that still govern gameplay timing. Each state declares an explicit playback mode: continuous idle, walk, and carry clips loop, while jump, death, attack, and roll play once and hold their final frame. The compatibility GLBs bake source transforms at 60 Hz, and character state changes crossfade over 120 ms. Pressure pads use Kenney's native `toggle-on` and `toggle-off` clips, play them once, and hold the depressed or raised end pose without a color tint. The figurine's authored forward axis is world `+z`, so model rotation maps that axis onto movement and attack direction.

Production models should replace these GLBs through the same model-loading and animation-selection path. There is no parallel sprite renderer to maintain.
