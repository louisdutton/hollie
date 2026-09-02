# Art pipeline

Gameplay geometry and source-image resolution are independent. Replacing prototype art must not require changing collision, entity positions, or room dimensions.

## Tiles

Room tilesets define two sizes:

- `tile_size` is the logical size of one tile in world units.
- `source_tile_size` is the pixel size of one cell in the tileset image.
- `smooth` selects bilinear filtering for hand-drawn source art. It defaults to point filtering for legacy pixel assets.

For example, a 64-pixel hand-drawn tile can continue to occupy a 16-unit gameplay cell:

```json
"tileset": {
  "path": "art/tileset/placeholder.png",
  "tile_size": 16,
  "source_tile_size": 64,
  "columns": 8,
  "smooth": true
}
```

## Animated characters

Each character animation profile independently defines:

- `source_frame_size`: the pixel dimensions of a frame in its source strip;
- `world_size`: the size at which that frame is drawn in the game world;
- `anchor`: the normalized point in the drawn image placed at the entity position;
- `smooth`: whether to use bilinear filtering.

An anchor of `{0.5, 1.0}` places the character's feet at its entity position. Collider sizes remain independent.

## Props and scenery

Standalone scenery images use map-defined world bounds and optional smooth filtering. Single-image entity sprites are also drawn from their full source image into independent world bounds. Prototype images should therefore be replaced in place rather than baked into the legacy 16-pixel tileset.

## Prototype asset policy

Active world art lives under `res/art/prototype`. It is deliberately generic:

- every player, NPC, and enemy uses the same anonymous character image;
- all ground uses the same neutral texture and decoration tiles are empty;
- carryable objects and puzzle elements share one generic object marker.

The old production-style files may remain in the repository as references, but gameplay code and room files should not point at them during the prototype phase.
