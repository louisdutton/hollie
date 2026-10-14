{pkgs, ...}: {
  profiles.assets.module = {
    packages = [pkgs.blender];
    tasks = {
      "hollie:assets:figurines".exec = ''
        set -e
        blender --version
        for asset in figurine figurine-cube; do
          blender -b --python tools/bake_kenney_figurine.py -- \
            "res/world/props/$asset.glb" "res/world/props/$asset-raylib.glb"
        done
      '';
      "hollie:assets:animals".exec = ''
        set -e
        blender --version
        for asset in animal-dog animal-horse animal-bison; do
          blender -b --python tools/bake_kenney_animal.py -- \
            "res/world/props/$asset.glb" "res/world/props/$asset-raylib.glb"
        done
      '';
      "hollie:assets:pressure-pad".exec = ''
        set -e
        blender --version
        blender -b --python tools/bake_kenney_pressure_pad.py -- \
          res/world/props/button-floor-square.glb res/world/props/button-floor-square-raylib.glb
      '';
      "hollie:assets:turtle".exec = ''
        set -e
        blender --version
        blender -b --python tools/build_turtle.py
      '';
      "hollie:assets:bake".after = [
        "hollie:assets:figurines"
        "hollie:assets:animals"
        "hollie:assets:pressure-pad"
        "hollie:assets:turtle"
      ];
    };
  };
}
