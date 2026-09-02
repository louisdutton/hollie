"""Bake Kenney's rigid-node figurine clips into a raylib-compatible skin.

Run with Blender in background mode:
    blender -b --python tools/bake_kenney_figurine.py -- \
        res/art/kenney/prototype-kit/figurine.glb \
        res/art/kenney/prototype-kit/figurine-raylib.glb

The source animation is sampled verbatim. Each mesh part is rigidly weighted to
one bone; no procedural or replacement animation is introduced.
"""

import math
import pathlib
import sys

import bpy
from mathutils import Matrix


PART_NAMES = ("leg-left", "leg-right", "torso", "arm-left", "arm-right", "head")
ANIMATED_NODE_NAMES = ("root",) + PART_NAMES


def arguments():
    try:
        separator = sys.argv.index("--")
    except ValueError as error:
        raise SystemExit("Expected input and output paths after '--'") from error
    values = sys.argv[separator + 1 :]
    if len(values) != 2:
        raise SystemExit("Usage: blender -b --python SCRIPT -- INPUT.glb OUTPUT.glb")
    return tuple(pathlib.Path(value).resolve() for value in values)


def set_source_action(action, nodes, rest_basis):
    slots = {slot.identifier: slot for slot in action.slots}
    for node in nodes:
        node.animation_data_clear()
        node.matrix_basis = rest_basis[node.name].copy()
        slot = slots.get(f"OB{node.name}")
        if slot is not None:
            node.animation_data_create()
            node.animation_data.action = action
            node.animation_data.action_slot = slot


def sample_frames(action):
    start, end = action.frame_range
    frames = [float(frame) for frame in range(math.floor(start), math.floor(end) + 1)]
    if not math.isclose(frames[-1], end):
        frames.append(float(end))
    return frames


def main():
    source_path, output_path = arguments()
    output_path.parent.mkdir(parents=True, exist_ok=True)

    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for collection in (bpy.data.actions, bpy.data.armatures, bpy.data.meshes):
        for block in list(collection):
            collection.remove(block)

    bpy.ops.import_scene.gltf(filepath=str(source_path))
    nodes = [bpy.data.objects[name] for name in ANIMATED_NODE_NAMES]
    parts = [bpy.data.objects[name] for name in PART_NAMES]
    source_actions = [(action.name, action) for action in bpy.data.actions]
    static_action = bpy.data.actions["static"]

    # The imported static clip contains the authored rest transforms.
    bpy.context.scene.frame_set(0)
    initial_basis = {node.name: node.matrix_basis.copy() for node in nodes}
    set_source_action(static_action, nodes, initial_basis)
    bpy.context.view_layer.update()
    rest_basis = {node.name: node.matrix_basis.copy() for node in nodes}
    rest_world = {part.name: part.matrix_world.copy() for part in parts}
    expected_vertices = sorted(
        tuple(rest_world[part.name] @ vertex.co)
        for part in parts
        for vertex in part.data.vertices
    )

    # Put all part geometry into armature space and retain one rigid vertex group
    # per part. Joining preserves the source materials and their texture.
    baked_parts = []
    for source in parts:
        baked = source.copy()
        baked.data = source.data.copy()
        bpy.context.collection.objects.link(baked)
        baked.name = f"baked-{source.name}"
        # Object.copy() also copies the source animation controller. It must not
        # be allowed to reapply a limb transform to the joined mesh object.
        baked.animation_data_clear()
        baked.parent = None
        baked.data.transform(rest_world[source.name])
        baked.matrix_parent_inverse = Matrix.Identity(4)
        baked.matrix_basis = Matrix.Identity(4)
        group = baked.vertex_groups.new(name=source.name)
        group.add(range(len(baked.data.vertices)), 1.0, "REPLACE")
        baked_parts.append(baked)

    bpy.ops.object.select_all(action="DESELECT")
    for baked in baked_parts:
        baked.select_set(True)
    bpy.context.view_layer.objects.active = baked_parts[0]
    bpy.ops.object.join()
    character_mesh = bpy.context.view_layer.objects.active
    character_mesh.name = "figurine-mesh"
    actual_vertices = sorted(
        tuple(character_mesh.matrix_world @ vertex.co)
        for vertex in character_mesh.data.vertices
    )
    rest_error = max(
        abs(actual[axis] - expected[axis])
        for actual, expected in zip(actual_vertices, expected_vertices)
        for axis in range(3)
    )
    if rest_error > 0.000001:
        raise RuntimeError(f"Joined rest geometry moved by {rest_error}")

    armature_data = bpy.data.armatures.new("figurine-armature")
    armature = bpy.data.objects.new("figurine-armature", armature_data)
    bpy.context.collection.objects.link(armature)
    bpy.context.view_layer.objects.active = armature
    armature.select_set(True)
    character_mesh.select_set(False)
    bpy.ops.object.mode_set(mode="EDIT")
    for part_name in PART_NAMES:
        bone = armature_data.edit_bones.new(part_name)
        # Bind each rigid bone at the original object's authored origin. This is
        # the hinge used by Kenney's rotations (shoulder, hip, neck, and so on).
        bone.matrix = rest_world[part_name]
        bone.length = 0.1
    bpy.ops.object.mode_set(mode="OBJECT")

    modifier = character_mesh.modifiers.new("figurine-skin", "ARMATURE")
    modifier.object = armature
    character_mesh.parent = armature

    # Free the original names so the baked clips retain Kenney's exact names.
    for name, action in source_actions:
        action.name = f"source:{name}"

    armature.animation_data_create()
    for clip_name, source_action in source_actions:
        baked_action = bpy.data.actions.new(clip_name)
        armature.animation_data.action = baked_action
        for pose_bone in armature.pose.bones:
            pose_bone.rotation_mode = "QUATERNION"

        set_source_action(source_action, nodes, rest_basis)
        for frame in sample_frames(source_action):
            bpy.context.scene.frame_set(int(frame), subframe=frame - int(frame))
            bpy.context.view_layer.update()
            for part in parts:
                pose_bone = armature.pose.bones[part.name]
                # Armature deformation is pose * inverse(bind). Include the bind
                # matrix explicitly so Blender's bone-axis conversion cannot
                # move the authored hinge during GLB export.
                deformation = part.matrix_world @ rest_world[part.name].inverted()
                pose_bone.matrix = deformation @ pose_bone.bone.matrix_local
                pose_bone.keyframe_insert("location", frame=frame, group=part.name)
                pose_bone.keyframe_insert("rotation_quaternion", frame=frame, group=part.name)
                pose_bone.keyframe_insert("scale", frame=frame, group=part.name)

    # Remove the source hierarchy and source-only actions before export.
    armature.animation_data.action = None
    for source in list(bpy.data.objects):
        if source not in (armature, character_mesh):
            bpy.data.objects.remove(source, do_unlink=True)
    for _name, action in source_actions:
        bpy.data.actions.remove(action)

    bpy.ops.object.select_all(action="DESELECT")
    armature.select_set(True)
    character_mesh.select_set(True)
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
    print(f"Baked {len(source_actions)} Kenney clips to {output_path}")


if __name__ == "__main__":
    main()
