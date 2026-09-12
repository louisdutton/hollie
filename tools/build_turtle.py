"""Build the cel-shaded turtle and its procedural posing rig.

Usage: blender -b --python tools/build_turtle.py
Optional: append -- --preview /tmp/turtle.png for an offline studio render.
See turtle_rig.md for the coordinate and runtime posing contract.
"""
import math
import pathlib
import sys

import bpy
from mathutils import Vector

ROOT = pathlib.Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "res/world/props/animal-turtle-raylib.glb"


def material(name, color):
    result = bpy.data.materials.new(name)
    result.diffuse_color = (*color, 1)
    result.use_nodes = True
    shader = result.node_tree.nodes.get("Principled BSDF")
    shader.inputs["Base Color"].default_value = (*color, 1)
    shader.inputs["Roughness"].default_value = 1
    return result


bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)
for action in list(bpy.data.actions):
    bpy.data.actions.remove(action)
scene = bpy.context.scene
scene.render.fps = 60
scene.frame_start = 0
scene.frame_end = 60

shell = material("shell_moss", (0.19, 0.34, 0.16))
plates = material("shell_sage", (0.34, 0.48, 0.22))
skin = material("skin_jade", (0.40, 0.62, 0.36))
rim = material("warm_ochre", (0.64, 0.58, 0.30))
eye = material("ink", (0.025, 0.037, 0.025))
highlight = material("cream", (0.88, 0.86, 0.65))
parts = []


def mesh_part(name, vertices, faces, mat, bone):
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(mat)
    parts.append((obj, bone))
    return obj


def ellipsoid(name, position, scale, mat, bone, segments=12, rings=6):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments, ring_count=rings, location=position)
    obj = bpy.context.object
    obj.name = name
    obj.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(mat)
    parts.append((obj, bone))
    return obj


# -X forward, -Y left, Z up. Broad shell keeps the existing saddle footprint.
def dome(radius, angle, lift=0):
    return (0.40 * radius * math.cos(angle), 0.30 * radius * math.sin(angle),
            0.145 + 0.205 * math.sqrt(max(0, 1 - radius * radius)) + lift)


ellipsoid("plastron", (0, 0, 0.115), (0.395, 0.295, 0.075), rim, "torso", 24)
ellipsoid("shell_lip", (0, 0, 0.15), (0.415, 0.312, 0.048), rim, "torso", 24)
# Continuous dark dome beneath inset polygon plates: seams follow the surface.
vertices = [(0, 0, 0.305)]
for radius in (0.32, 0.66, 0.88, 1):
    vertices.extend(dome(radius, i * math.tau / 24, -0.045) for i in range(24))
faces = [(0, 1 + i, 1 + (i + 1) % 24) for i in range(24)]
for row in range(3):
    a, b = 1 + row * 24, 1 + (row + 1) * 24
    faces.extend((a+i, b+i, b+(i+1)%24, a+(i+1)%24) for i in range(24))
faces.append(tuple(reversed(range(73, 97))))
mesh_part("carapace", vertices, faces, shell, "torso")
# Two bands of broad scutes, with a small central crown. No floating beads.
for band, (inner, outer, count) in enumerate(((0.02, 0.48, 6), (0.50, 0.97, 12))):
    for index in range(count):
        start = index * math.tau / count + 0.018
        end = (index + 1) * math.tau / count - 0.018
        middle = (start + end) / 2
        points = [dome(inner, start, 0.004), dome(outer, start, 0.004),
                  dome(outer, middle, 0.004), dome(outer, end, 0.004),
                  dome(inner, end, 0.004), dome(inner, middle, 0.004)]
        # Centre follows the curved shell, avoiding large planar intersections.
        points.append(dome((inner + outer) / 2, middle, 0.005))
        mesh_part(f"scute_{band}_{index}", points,
                  [(6, i, (i+1)%6) for i in range(6)], plates, "torso")

ellipsoid("neck", (-0.35, 0, 0.145), (0.17, 0.095, 0.08), skin, "neck")
ellipsoid("head", (-0.495, 0, 0.18), (0.16, 0.135, 0.115), skin, "head", 16, 8)
ellipsoid("lower_beak", (-0.555, 0, 0.123), (0.10, 0.098, 0.031), rim, "jaw")
for side, sign in (("left", -1), ("right", 1)):
    ellipsoid(f"eye_socket_{side}", (-0.53, sign*0.113, 0.218),
              (0.048, 0.027, 0.048), rim, "head")
    ellipsoid(f"eye_{side}", (-0.545, sign*0.132, 0.223),
              (0.030, 0.013, 0.033), eye, "head")
    ellipsoid(f"eye_glint_{side}", (-0.555, sign*0.143, 0.237),
              (0.009, 0.004, 0.010), highlight, "head", 8, 4)
    ellipsoid(f"nostril_{side}", (-0.642, sign*0.045, 0.195),
              (0.007, 0.009, 0.006), eye, "head", 8, 4)

# All bone axes align with Blender Z, so local Y is vertical in exported GLTF.
hinges = {
    "root": ((0, 0, 0), None),
    "torso": ((0, 0, 0.14), "root"),
    "neck": ((-0.28, 0, 0.15), "torso"),
    "head": ((-0.425, 0, 0.17), "neck"),
    "jaw": ((-0.485, 0, 0.135), "head"),
    "tail": ((0.34, 0, 0.115), "torso"),
}


def tapered_part(name, sections, bone):
    vertices = []
    for x, y, z, width, thickness in sections:
        for i in range(8):
            angle = i * math.tau / 8
            vertices.append((x + width * math.cos(angle), y, z + thickness * math.sin(angle)))
    faces = [tuple(reversed(range(8)))]
    for row in range(len(sections)-1):
        faces.extend((row*8+i, row*8+(i+1)%8, (row+1)*8+(i+1)%8, (row+1)*8+i)
                     for i in range(8))
    faces.append(tuple(range((len(sections)-1)*8, len(sections)*8)))
    # Section ordering reverses on the opposite side; keep outward normals.
    if sections[-1][1] > sections[0][1]:
        faces = [tuple(reversed(face)) for face in faces]
    mesh_part(name, vertices, faces, skin, bone)


for side, sign in (("left", -1), ("right", 1)):
    for limb, x, length, width in (("front", -0.22, 0.31, 0.105), ("back", 0.25, 0.22, 0.09)):
        name = f"flipper-{limb}-{side}"
        hinges[name] = ((x, sign*0.215, 0.105), "torso")
        tapered_part(name, [(x, sign*0.20, 0.10, width*0.65, 0.038),
                           (x-0.025, sign*0.31, 0.065, width, 0.027),
                           (x+0.04, sign*(0.20+length*0.8), 0.055, width*0.6, 0.020),
                           (x+0.075, sign*(0.20+length), 0.065, 0.015, 0.009)], name)
ellipsoid("tail", (0.405, 0, 0.105), (0.105, 0.042, 0.033), skin, "tail")

bpy.ops.object.select_all(action="DESELECT")
armature = bpy.data.objects.new("turtle_rig", bpy.data.armatures.new("turtle_rig"))
bpy.context.collection.objects.link(armature)
bpy.context.view_layer.objects.active = armature
armature.select_set(True)
armature.show_in_front = True
bpy.ops.object.mode_set(mode="EDIT")
for name, (hinge, parent) in hinges.items():
    bone = armature.data.edit_bones.new(name)
    bone.head = hinge
    bone.tail = Vector(hinge) + Vector((0, 0, 0.075))
    if parent:
        bone.parent = armature.data.edit_bones[parent]
bpy.ops.object.mode_set(mode="OBJECT")
for obj, name in parts:
    group = obj.vertex_groups.new(name=name)
    group.add(list(range(len(obj.data.vertices))), 1, "REPLACE")
# Join by material to avoid a draw call for every scute and facial feature.
bpy.ops.object.select_all(action="DESELECT")
for obj, _ in parts:
    obj.select_set(True)
bpy.context.view_layer.objects.active = parts[0][0]
bpy.ops.object.join()
body = bpy.context.object
body.name = "turtle"
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
modifier = body.modifiers.new("rig", "ARMATURE")
modifier.object = armature
body.parent = armature

armature.animation_data_create()
for clip, amplitude in (("walk", 14), ("run", 26), ("down", 0), ("jump", 0)):
    action = bpy.data.actions.new(clip)
    action.use_fake_user = True
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
                stroke = phase + offset + (math.pi if sign < 0 else 0)
                bone.rotation_euler.y = math.radians(amplitude) * math.sin(stroke)
                bone.rotation_euler.x = math.radians(amplitude*0.35) * math.cos(stroke) * sign
                if clip == "jump":
                    bone.rotation_euler.x = math.radians(18) * sign
            if bone.name == "torso":
                bone.location.y = (1-math.cos(phase*2)) * 0.002 * amplitude/26
            if bone.name == "tail":
                bone.rotation_euler.y = math.sin(phase) * math.radians(amplitude*0.3)
            if bone.name == "head":
                bone.rotation_euler.z = math.sin(phase*2) * math.radians(amplitude*0.08)
            bone.keyframe_insert("rotation_euler", frame=frame)
            bone.keyframe_insert("location", frame=frame)
armature.animation_data.action = None
for bone in armature.pose.bones:
    bone.rotation_euler = (0, 0, 0)
    bone.location = (0, 0, 0)
scene.frame_set(0)
bpy.ops.object.select_all(action="DESELECT")
body.select_set(True)
armature.select_set(True)
bpy.context.view_layer.objects.active = armature
bpy.ops.export_scene.gltf(filepath=str(OUTPUT), export_format="GLB", use_selection=True,
                          export_animations=True, export_animation_mode="ACTIONS", export_skins=True)
source = ROOT / "res/world/props/turtle.blend"
bpy.ops.wm.save_as_mainfile(filepath=str(source))
print(f"Turtle: {len(body.data.polygons)} polygons, {len(hinges)} bones")

if "--preview" in sys.argv:
    destination = sys.argv[sys.argv.index("--preview") + 1]
    scene.render.engine = "CYCLES"
    scene.cycles.samples = 32
    scene.world.color = (0.3, 0.3, 0.3)
    bpy.ops.object.camera_add(location=(-1.15, -1.4, 1.05))
    camera = bpy.context.object
    camera.rotation_euler = (Vector((-0.06, 0, 0.14))-camera.location).to_track_quat("-Z", "Y").to_euler()
    camera.data.type = "ORTHO"
    camera.data.ortho_scale = 1.5
    scene.camera = camera
    bpy.ops.object.light_add(type="AREA", location=(-1, -2, 3))
    bpy.context.object.data.energy = 140
    bpy.context.object.data.shape = "DISK"
    bpy.context.object.data.size = 3
    scene.render.resolution_x = 900
    scene.render.resolution_y = 900
    scene.render.resolution_percentage = 100
    scene.render.filepath = destination
    bpy.ops.render.render(write_still=True)
