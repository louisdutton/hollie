# Asset tooling

Asset baking is an explicit operation. Review and commit generated models
together with changes to their generator or source; keep source assets and
license files.

Use the `assets` devenv profile when baking. Task definitions and their commands
live in [devenv.nix](../devenv.nix); baker arguments live in the scripts themselves.

Treat GLB files ending in `-raylib.glb` as generated output. Review changes to
animation names, axes, scale, and mesh bounds alongside the corresponding content
and rendering code. The suffix is a legacy asset identifier; these models are
used by Bevy and their bakers also supply authored poses absent from the originals.

Port edits to the turtle's generated `.blend` scene back into the generator
before regenerating it. See [turtle_rig.md](turtle_rig.md) for the source/rig
contract and offline preview guidance.
