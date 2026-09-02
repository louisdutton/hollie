# Development

- Never run the game or invoke `devenv tasks run hollie:run`.
- Use `devenv tasks run hollie:verify` for non-graphical verification.
- Use `devenv shell` only for one-off commands.

# Art

- The game world is 3D. Do not add or maintain a parallel 2D world-rendering implementation.
- Use file-backed GLB models from the Kenney Prototype Kit for prototype world art; do not use runtime primitives as world art.
- Keep prototype models on the same loading and rendering path as their eventual production replacements.
- UI may use raster images. Final world art should be stylized, hand-crafted 3D rather than pixel art, replacing prototypes through the existing 3D asset pipeline.
