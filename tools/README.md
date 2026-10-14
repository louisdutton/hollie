# Asset tooling

These Python scripts run inside Blender, using its `bpy` and `mathutils`
modules. Normal verification checks baker syntax without running Blender. Asset baking
is an explicit operation that overwrites the specified outputs; inspect and
commit the generated models together with changes to their generator or source.

Run from the repository root using the `assets` devenv profile. It supplies Blender
from the pinned nixpkgs input in `devenv.lock`; baking tasks print its version.
The source GLBs, runtime GLBs, and Kenney license are in `res/world/props/`.

| Generator | Source | Runtime output |
| --- | --- | --- |
| `bake_kenney_figurine.py` | `figurine.glb` or `figurine-cube.glb` | Corresponding `*-raylib.glb` |
| `bake_kenney_animal.py` | `animal-dog.glb`, `animal-horse.glb`, `animal-bison.glb` | Corresponding `*-raylib.glb` |
| `bake_kenney_pressure_pad.py` | `button-floor-square.glb` | `button-floor-square-raylib.glb` |
| `build_turtle.py` | Procedural definition in the script | `animal-turtle-raylib.glb` and editable `turtle.blend` |

Examples:

```sh
devenv --profile assets tasks run --show-output hollie:assets:figurines
devenv --profile assets tasks run --show-output hollie:assets:animals
devenv --profile assets tasks run --show-output hollie:assets:pressure-pad
devenv --profile assets tasks run --show-output hollie:assets:turtle
```

`hollie:assets:bake` runs all four groups. Baking is explicit and unconditional;
these tasks overwrite the listed outputs and are never dependencies of verification
or release packaging. Review generated assets together with their sources.

For a single model or custom baker options, use a one-off command with the profile:

```sh
devenv --profile assets shell -- blender -b --python tools/bake_kenney_figurine.py -- \
  res/world/props/figurine.glb res/world/props/figurine-raylib.glb
devenv --profile assets shell -- blender -b --python tools/bake_kenney_animal.py -- \
  res/world/props/animal-horse.glb res/world/props/animal-horse-raylib.glb
devenv --profile assets shell -- blender -b --python tools/bake_kenney_pressure_pad.py -- \
  res/world/props/button-floor-square.glb res/world/props/button-floor-square-raylib.glb
devenv --profile assets shell -- blender -b --python tools/build_turtle.py
```

The figurine baker is shared by the animal wrapper. It converts rigid animated
parts to a skin raylib can sample; its options control additional carry, jump,
and riding poses. Bone and clip names are consumed by runtime animation code.
The turtle's source/rig contract and optional offline preview command are in
[turtle_rig.md](turtle_rig.md). Port edits to its generated `.blend` scene back
into the generator before regenerating it.

Keep source assets and license files. Treat GLB files ending in `-raylib.glb` as
baked output, and review changes to animation names, axes, scale, and mesh bounds
alongside the corresponding content and rendering code.
