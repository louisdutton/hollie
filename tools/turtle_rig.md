# Turtle asset

The generator recreates the Blender scene; port edits to the generated `.blend`
back into `build_turtle.py` before regenerating. Its optional offline Cycles
preview shows geometry and palette, not the game's exact shading.

Forward is -X in the authored asset. Blender Z becomes glTF/Bevy Y; Blender Y
becomes -Z. Retain the existing bone names as asset identifiers and preserve the
prototype's approximate 0.8 by 0.6 footprint when changing the model.

This is a rigid-part rig: overlapping joints hide seams during modest rotations.
Extreme rotations and deep neck retraction require additional deformation work.
Keep shell geometry on `torso` so it follows the saddle, and facial geometry on
`head` so it follows head motion. Preserve complete bone coverage in authored
clips for blending and procedural animation.
