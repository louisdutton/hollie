# Turtle asset

`build_turtle.py` generates `res/world/props/animal-turtle-raylib.glb` and
`res/world/props/turtle.blend`. Run with Blender in background:

```sh
blender -b --python tools/build_turtle.py
blender -b --python tools/build_turtle.py -- --preview /tmp/turtle.png
```

The editable source includes the mesh, materials, armature, and four actions.
The generator recreates the scene; port source edits into the script before
regenerating. The model uses 1,357 polygons before export triangulation, six
matte materials, flat normals, and no textures or subdivision modifiers.
The game shader supplies cel shading; the optional offline Cycles preview
shows geometry and palette, not the game's exact shading.

## Rig contract

Forward is -X. Blender Z becomes game Y; Blender Y becomes game -Z.
The shell retains approximately the prototype's 0.8 by 0.6 footprint.
Existing bone names with hyphens are retained as asset identifiers.

| Bone | Parent | Purpose |
| --- | --- | --- |
| root | none | Entire character |
| torso | root | Shell tilt, breathing, saddle reference |
| neck | torso | Head assembly look direction and retraction |
| head | neck | Nods and look adjustments |
| jaw | head | Beak opening |
| tail | torso | Tail sway |
| flipper-front-left / flipper-front-right | torso | Shoulder strokes |
| flipper-back-left / flipper-back-right | torso | Hip strokes |

Pivots sit inside overlapping joints to hide rigid seams during modest rotations.
Every vertex has one full-weight influence, matching the engine's CPU and GPU
bone overlays. This is a rigid-part rig. Start with 15–25 degree flipper strokes,
15 degree head nods and 10 degree jaw opening; extreme rotations and deep
retraction require additional deformation work. Bones point along Blender +Z:
pose-local Y rotates around vertical, X banks flippers, Z nods the head/jaw.

`walk` and `run` are one-second, 60 fps reference strokes with alternating limbs.
`down` is the neutral standing pose expected by the idle blend. `jump` holds
flippers spread. Every action contains every bone for compatible blending.
Runtime gait phase and speed blending continue to drive these clips.

For procedural poses, sample a clip first, then apply model-space bone matrix
overlays about `currentPose[bone].translation`. Engine matrix helpers modify
only the named bone and do not propagate to descendants. Apply neck overlays
to neck, head and jaw; head overlays to head and jaw; torso/root overlays to
all descendants. Use the same pivot for every bone in an overlay. Existing look
and ram overlays include the jaw. Resample before posing to avoid accumulation.

Shell, lip, plates and belly belong to `torso`, preserving animated saddle bounds.
Eyes and nostrils belong to `head`, following head motion.
