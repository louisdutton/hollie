"""Bake Prototype Kit animals with their original rigid-part animations.

Usage: blender -b --python tools/bake_kenney_animal.py -- INPUT.glb OUTPUT.glb
"""

import pathlib
import sys

sys.dont_write_bytecode = True
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from bake_kenney_figurine import main

main(part_names=None, animated_node_names=None, add_carry=False)
