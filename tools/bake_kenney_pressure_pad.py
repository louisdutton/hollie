"""Bake Kenney's rigid-node pressure-pad clips into a raylib-compatible skin.

Run with Blender in background mode:
    blender -b --python tools/bake_kenney_pressure_pad.py -- \
        res/art/kenney/prototype-kit/button-floor-square.glb \
        res/art/kenney/prototype-kit/button-floor-square-raylib.glb
"""

import math
import pathlib
import sys

import bpy
from mathutils import Matrix


PART_NAMES = ("button-floor-square", "button")
CLIP_NAMES = {"toggle", "toggle-off", "toggle-on"}


def arguments():
    try:
        separator = sys.argv.index("--")
    except ValueError as error:
        raise SystemExit("Expected input and output paths after '--'") from error
    values = sys.argv[separator + 1 :]
    if len(values) != 2:
        raise SystemExit("Usage: blender -b --python SCRIPT -- INPUT.glb OUTPUT.glb")
    return tuple(pathlib.Path(value).resolve() for value in values)


def sample_frames(action):
    start, end = action.frame_range
    frames = [float(frame) for frame in range(math.floor(start), math.floor(end) + 1)]
    if not math.isclose(frames[-1], end):
        frames.append(float(end))
    return frames


def set_source_action(action, parts, rest_basis):
    for part in parts:
        part.animation_data_clear()
        part.matrix_basis = rest_basis[part.name].copy()
    moving_part = parts[1]
    slot = next((slot for slot in action.slots if slot.identifier == "OBbutton"), None)
    if slot is None:
        raise RuntimeError(f"Animation {action.name} has no OBbutton action slot")
    moving_part.animation_data_create()
    moving_part.animation_data.action = action
    moving_part.animation_data.action_slot = slot


def bake_action(clip_name, action, parts, rest_basis, rest_world, armature):
    baked_action = bpy.data.actions.new(clip_name)
    armature.animation_data.action = baked_action
    for pose_bone in armature.pose.bones:
        pose_bone.rotation_mode = "QUATERNION"

    set_source_action(action, parts, rest_basis)
    for frame in sample_frames(action):
        bpy.context.scene.frame_set(int(frame), subframe=frame - int(frame))
        bpy.context.view_layer.update()
        for part in parts:
            pose_bone = armature.pose.bones[part.name]
            deformation = part.matrix_world @ rest_world[part.name].inverted()
            pose_bone.matrix = deformation @ pose_bone.bone.matrix_local
            pose_bone.keyframe_insert("location", frame=frame, group=part.name)
            pose_bone.keyframe_insert("rotation_quaternion", frame=frame, group=part.name)
            pose_bone.keyframe_insert("scale", frame=frame, group=part.name)


def main():
    source_path, output_path = arguments()
    output_path.parent.mkdir(parents=True, exist_ok=True)
    bpy.context.scene.render.fps = 60

    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for collection in (bpy.data.actions, bpy.data.armatures, bpy.data.meshes):
        for block in list(collection):
            collection.remove(block)

    bpy.ops.import_scene.gltf(filepath=str(source_path))
    parts = [bpy.data.objects[name] for name in PART_NAMES]
    source_actions = list(bpy.data.actions)
    if {action.name for action in source_actions} != CLIP_NAMES:
        raise RuntimeError("Pressure-pad source clips do not match the expected Kenney clips")

    for part in parts:
        part.animation_data_clear()
    bpy.context.view_layer.update()
    rest_basis = {part.name: part.matrix_basis.copy() for part in parts}
    rest_world = {part.name: part.matrix_world.copy() for part in parts}

    baked_parts = []
    for source in parts:
        baked = source.copy()
        baked.data = source.data.copy()
        bpy.context.collection.objects.link(baked)
        baked.name = f"baked-{source.name}"
        baked.animation_data_clear()
        baked.parent = None
        baked.data.transform(rest_world[source.name])
        baked.matrix_basis = Matrix.Identity(4)
        group = baked.vertex_groups.new(name=source.name)
        group.add(range(len(baked.data.vertices)), 1.0, "REPLACE")
        baked_parts.append(baked)

    bpy.ops.object.select_all(action="DESELECT")
    for baked in baked_parts:
        baked.select_set(True)
    bpy.context.view_layer.objects.active = baked_parts[0]
    bpy.ops.object.join()
    pad_mesh = bpy.context.view_layer.objects.active
    pad_mesh.name = "pressure-pad-mesh"

    armature_data = bpy.data.armatures.new("pressure-pad-armature")
    armature = bpy.data.objects.new("pressure-pad-armature", armature_data)
    bpy.context.collection.objects.link(armature)
    bpy.context.view_layer.objects.active = armature
    armature.select_set(True)
    pad_mesh.select_set(False)
    bpy.ops.object.mode_set(mode="EDIT")
    for part_name in PART_NAMES:
        bone = armature_data.edit_bones.new(part_name)
        bone.matrix = rest_world[part_name]
        bone.length = 0.1
    bpy.ops.object.mode_set(mode="OBJECT")

    modifier = pad_mesh.modifiers.new("pressure-pad-skin", "ARMATURE")
    modifier.object = armature
    pad_mesh.parent = armature

    for action in source_actions:
        action.name = f"source:{action.name}"
    armature.animation_data_create()
    for source_action in source_actions:
        clip_name = source_action.name.removeprefix("source:")
        bake_action(clip_name, source_action, parts, rest_basis, rest_world, armature)

    armature.animation_data.action = None
    for source in list(bpy.data.objects):
        if source not in (armature, pad_mesh):
            bpy.data.objects.remove(source, do_unlink=True)
    for action in source_actions:
        bpy.data.actions.remove(action)

    bpy.ops.object.select_all(action="DESELECT")
    armature.select_set(True)
    pad_mesh.select_set(True)
    bpy.context.view_layer.objects.active = armature
    bpy.ops.export_scene.gltf(
        filepath=str(output_path),
        export_format="GLB",
        use_selection=True,
        export_animations=True,
        export_animation_mode="ACTIONS",
        export_bake_animation=True,
        export_skins=True,
    )
    print(f"Baked {len(source_actions)} Kenney pressure-pad clips to {output_path}")


if __name__ == "__main__":
    main()
