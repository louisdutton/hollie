"""Bake Kenney's rigid-node figurine clips into a raylib-compatible skin.

Run with Blender in background mode:
    blender -b --python tools/bake_kenney_figurine.py -- \
        res/art/kenney/prototype-kit/figurine.glb \
        res/art/kenney/prototype-kit/figurine-raylib.glb

The source animation is sampled verbatim. Each mesh part is rigidly weighted to
one bone. A carry-walk clip layers Kenney's holding arms over Kenney's walk.
"""

import math
import pathlib
import sys

import bpy
from mathutils import Matrix
from mathutils.kdtree import KDTree


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


def set_source_action(action, nodes, rest_basis, overrides=None):
    overrides = overrides or {}
    for node in nodes:
        node.animation_data_clear()
        node.matrix_basis = rest_basis[node.name].copy()
        node_action = overrides.get(node.name, action)
        slots = {slot.identifier: slot for slot in node_action.slots}
        slot = slots.get(f"OB{node.name}")
        if slot is not None:
            node.animation_data_create()
            node.animation_data.action = node_action
            node.animation_data.action_slot = slot


def sample_frames(action):
    start, end = action.frame_range
    frames = [float(frame) for frame in range(math.floor(start), math.floor(end) + 1)]
    if not math.isclose(frames[-1], end):
        frames.append(float(end))
    return frames


def bake_action(
    clip_name,
    source_action,
    nodes,
    parts,
    rest_basis,
    rest_world,
    armature,
    overrides=None,
    post_rotations=None,
    motion_weights=None,
):
    post_rotations = post_rotations or {}
    motion_weights = motion_weights or {}
    baked_action = bpy.data.actions.new(clip_name)
    armature.animation_data.action = baked_action
    for pose_bone in armature.pose.bones:
        pose_bone.rotation_mode = "QUATERNION"

    set_source_action(source_action, nodes, rest_basis, overrides)
    for frame in sample_frames(source_action):
        bpy.context.scene.frame_set(int(frame), subframe=frame - int(frame))
        bpy.context.view_layer.update()
        for node in nodes:
            if node.name in motion_weights:
                node.matrix_basis = rest_basis[node.name].lerp(node.matrix_basis, motion_weights[node.name])
        bpy.context.view_layer.update()
        for part in parts:
            pose_bone = armature.pose.bones[part.name]
            # Armature deformation is pose * inverse(bind). Include the bind
            # matrix explicitly so Blender's bone-axis conversion cannot move
            # the authored hinge during GLB export.
            animated_world = part.matrix_world @ post_rotations.get(
                part.name, Matrix.Identity(4)
            )
            deformation = animated_world @ rest_world[part.name].inverted()
            pose_bone.matrix = deformation @ pose_bone.bone.matrix_local
            pose_bone.keyframe_insert("location", frame=frame, group=part.name)
            pose_bone.keyframe_insert(
                "rotation_quaternion", frame=frame, group=part.name
            )
            pose_bone.keyframe_insert("scale", frame=frame, group=part.name)


def main(part_names=PART_NAMES, animated_node_names=ANIMATED_NODE_NAMES, add_carry=True, add_jump=False, add_ride=True):
    source_path, output_path = arguments()
    output_path.parent.mkdir(parents=True, exist_ok=True)

    # Preserve the source duration but bake transforms at raylib's 60 Hz GLTF
    # sampling rate, avoiding a second interpolation from a coarse 24 Hz bake.
    bpy.context.scene.render.fps = 60

    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for collection in (bpy.data.actions, bpy.data.armatures, bpy.data.meshes):
        for block in list(collection):
            collection.remove(block)

    bpy.ops.import_scene.gltf(filepath=str(source_path))
    if part_names is None:
        part_names = tuple(obj.name for obj in bpy.data.objects if obj.type == "MESH")
    if animated_node_names is None:
        animated_node_names = tuple(obj.name for obj in bpy.data.objects)
    nodes = [bpy.data.objects[name] for name in animated_node_names]
    parts = [bpy.data.objects[name] for name in part_names]
    source_actions = [(action.name, action) for action in bpy.data.actions]
    source_actions_by_name = dict(source_actions)
    static_action = bpy.data.actions.get("static")

    # The imported static clip contains the authored rest transforms.
    bpy.context.scene.frame_set(0)
    initial_basis = {node.name: node.matrix_basis.copy() for node in nodes}
    if static_action is not None:
        set_source_action(static_action, nodes, initial_basis)
    else:
        for node in nodes:
            node.animation_data_clear()
            node.matrix_basis = initial_basis[node.name].copy()
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

    bpy.context.view_layer.update()
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
    if len(actual_vertices) != len(expected_vertices):
        raise RuntimeError("Joining changed the vertex count")
    # Joining can introduce tiny coordinate rounding differences that reorder
    # lexicographically sorted vertices. Compare spatially instead.
    tree = KDTree(len(actual_vertices))
    for index, vertex in enumerate(actual_vertices):
        tree.insert(vertex, index)
    tree.balance()
    rest_error = max(tree.find(vertex)[2] for vertex in expected_vertices)
    if rest_error > 0.000001:
        raise RuntimeError(f"Joined rest geometry moved by {rest_error}")

    armature_data = bpy.data.armatures.new("figurine-armature")
    armature = bpy.data.objects.new("figurine-armature", armature_data)
    bpy.context.collection.objects.link(armature)
    bpy.context.view_layer.objects.active = armature
    armature.select_set(True)
    character_mesh.select_set(False)
    bpy.ops.object.mode_set(mode="EDIT")
    for part_name in part_names:
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
        bake_action(
            clip_name,
            source_action,
            nodes,
            parts,
            rest_basis,
            rest_world,
            armature,
            motion_weights={"arm-left": 0.35, "arm-right": 0.35} if add_carry and clip_name == "walk" else None,
        )

    if add_carry:
        holding_action = source_actions_by_name["holding-both"]
        bake_action(
            "walk-holding-both",
            source_actions_by_name["walk"],
            nodes,
            parts,
            rest_basis,
            rest_world,
            armature,
            overrides={"arm-left": holding_action, "arm-right": holding_action},
            post_rotations={
                "arm-left": Matrix.Rotation(-math.pi / 2, 4, "X"),
                "arm-right": Matrix.Rotation(-math.pi / 2, 4, "X"),
            },
        )

    if add_ride:
        # Author a seated astride pose at the existing hip/shoulder hinges.
        # In Blender the figurine faces -Y, with Z up and its left side at +X.
        for node in nodes:
            node.animation_data_clear()
            node.matrix_basis = rest_basis[node.name].copy()
        rotations = {
            "torso": Matrix.Rotation(math.radians(20), 4, "X"),
            "head": Matrix.Rotation(math.radians(-10), 4, "X"),
            "arm-left": Matrix.Rotation(math.radians(-65), 4, "X") @ Matrix.Rotation(math.radians(10), 4, "Y"),
            "arm-right": Matrix.Rotation(math.radians(-65), 4, "X") @ Matrix.Rotation(math.radians(-10), 4, "Y"),
            "leg-left": Matrix.Rotation(math.radians(-20), 4, "X") @ Matrix.Rotation(math.radians(-60), 4, "Y"),
            "leg-right": Matrix.Rotation(math.radians(-20), 4, "X") @ Matrix.Rotation(math.radians(60), 4, "Y"),
        }
        ride_action = bpy.data.actions.new("ride")
        armature.animation_data.action = ride_action
        # This clip is a speed-driven pose range, not a timed animation.
        for frame in range(61):
            amount = frame / 60
            rotations["torso"] = Matrix.Rotation(math.radians(20 * amount), 4, "X")
            rotations["head"] = Matrix.Rotation(math.radians(-10 * amount), 4, "X")
            for side, inward in (("left", 10), ("right", -10)):
                rotations[f"arm-{side}"] = Matrix.Rotation(math.radians(-45 - 20 * amount), 4, "X") @ Matrix.Rotation(math.radians(inward), 4, "Y")
            for node in nodes:
                if node.name in rotations:
                    node.matrix_basis = rest_basis[node.name] @ rotations[node.name]
            bpy.context.view_layer.update()
            for part in parts:
                pose_bone = armature.pose.bones[part.name]
                pose_bone.matrix = part.matrix_world @ rest_world[part.name].inverted() @ pose_bone.bone.matrix_local
                pose_bone.keyframe_insert("location", frame=frame, group=part.name)
                pose_bone.keyframe_insert("rotation_quaternion", frame=frame, group=part.name)
                pose_bone.keyframe_insert("scale", frame=frame, group=part.name)

    if add_jump:
        # A held airborne extension: front legs reach forward (-X), rear legs
        # stretch back. Blender uses Z up; all four rigid legs stay straight.
        jump_action = bpy.data.actions.new("jump")
        armature.animation_data.action = jump_action
        for part in parts:
            pose_bone = armature.pose.bones[part.name]
            world = rest_world[part.name].copy()
            if part.name.startswith("leg-"):
                location, _, scale = world.decompose()
                angle = math.radians(55 if "front" in part.name else -55)
                world = Matrix.LocRotScale(location, Matrix.Rotation(angle, 3, "Y").to_quaternion(), scale)
            pose_bone.matrix = world @ rest_world[part.name].inverted() @ pose_bone.bone.matrix_local
            for frame in (0, 60):
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
    print(f"Baked {len(source_actions)} Kenney clips (carry layer: {add_carry}, jump pose: {add_jump}) to {output_path}")


if __name__ == "__main__":
    main()
