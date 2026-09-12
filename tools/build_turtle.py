"""Build an original low-poly turtle prototype; run with Blender in background."""
import math
import pathlib
import bpy
from mathutils import Vector

bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)
for action in list(bpy.data.actions):
    bpy.data.actions.remove(action)
bpy.context.scene.render.fps = 60

def material(name, color):
    result = bpy.data.materials.new(name)
    result.diffuse_color = (*color, 1)
    return result

shell = material("jade shell", (0.18, 0.42, 0.26))
skin = material("sea green", (0.36, 0.65, 0.43))
scute = material("shell plates", (0.46, 0.57, 0.25))
eye = material("eyes", (0.025, 0.04, 0.025))
parts = []

def part(name, position, scale, mat, bone_name=None):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=12, ring_count=6, location=position)
    obj = bpy.context.object
    obj.name = name
    obj.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(mat)
    parts.append((obj, bone_name or name))
    return obj

# Model faces -X, matching the other animals. Blender Z maps to world Y.
part("torso", (0, 0, 0.14), (0.40, 0.30, 0.17), shell)
part("head", (-0.43, 0, 0.15), (0.16, 0.12, 0.10), skin)
part("eye-left", (-0.51, -0.09, 0.20), (0.022, 0.022, 0.022), eye, "head")
part("eye-right", (-0.51, 0.09, 0.20), (0.022, 0.022, 0.022), eye, "head")
part("tail", (0.42, 0, 0.10), (0.13, 0.05, 0.04), skin)
for side, sign in (("left", -1), ("right", 1)):
    part(f"flipper-front-{side}", (-0.20, sign*0.32, 0.07), (0.19, 0.20, 0.035), skin)
    part(f"flipper-back-{side}", (0.26, sign*0.25, 0.06), (0.13, 0.15, 0.035), skin)
for x, y in ((0, 0), (-0.19, 0), (0.19, 0), (0, -0.15), (0, 0.15)):
    part("scute", (x, y, 0.285 if y == 0 else 0.25), (0.12, 0.105, 0.035), scute, "torso")

hinges = {obj.name: obj.location.copy() for obj, name in parts if obj.name == name}
armature = bpy.data.objects.new("turtle-rig", bpy.data.armatures.new("turtle-rig"))
bpy.context.collection.objects.link(armature)
bpy.context.view_layer.objects.active = armature
armature.select_set(True)
bpy.ops.object.mode_set(mode="EDIT")
for name, hinge in hinges.items():
    bone = armature.data.edit_bones.new(name)
    bone.head = hinge
    bone.tail = hinge + Vector((0, 0, 0.1))
bpy.ops.object.mode_set(mode="OBJECT")
for obj, name in parts:
    group = obj.vertex_groups.new(name=name)
    group.add(range(len(obj.data.vertices)), 1, "REPLACE")
    modifier = obj.modifiers.new("skin", "ARMATURE")
    modifier.object = armature
    obj.parent = armature
armature.animation_data_create()
for clip, amplitude in (("walk", 18), ("run", 32), ("down", 0), ("jump", 0)):
    action = bpy.data.actions.new(clip)
    armature.animation_data.action = action
    for frame in range(61):
        phase = frame / 60 * math.tau
        for bone in armature.pose.bones:
            bone.rotation_mode = "XYZ"
            bone.rotation_euler = (0, 0, 0)
            bone.location = (0, 0, 0)
            if bone.name.startswith("flipper"):
                sign = -1 if "left" in bone.name else 1
                offset = math.pi if "back" in bone.name else 0
                bone.rotation_euler.y = math.radians(amplitude) * math.sin(phase + offset) * sign
            if bone.name in ("torso", "head", "tail"):
                bone.location.y = math.sin(phase) * 0.008 * (amplitude / 32)
            bone.keyframe_insert("rotation_euler", frame=frame)
            bone.keyframe_insert("location", frame=frame)
armature.animation_data.action = None
bpy.ops.object.select_all(action="SELECT")
output = pathlib.Path(__file__).resolve().parents[1] / "res/world/props/animal-turtle-raylib.glb"
bpy.ops.export_scene.gltf(filepath=str(output), export_format="GLB", use_selection=True,
    export_animations=True, export_animation_mode="ACTIONS", export_skins=True)
