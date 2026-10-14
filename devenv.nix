{
  pkgs,
  lib,
  config,
  ...
}: let
  # 3.1.5 fixes SDL resize detection; nixpkgs still supplies 3.0.2.
  virtualgl_lib = pkgs.virtualglLib.overrideAttrs (_: {
    version = "3.1.5";
    src = pkgs.fetchurl {
      url = "https://github.com/VirtualGL/virtualgl/releases/download/3.1.5/VirtualGL-3.1.5.tar.gz";
      sha256 = "8a3249c4fa8eea928362ca97b8fe16e5b356e3a18cd16d87e3efa72a870750b6";
    };
  });
  virtualgl = pkgs.virtualgl.override {
    virtualglLib = virtualgl_lib;
    usei686VirtualglLib = false;
  };
  raylib = pkgs.raylib.override {platform = "SDL";};
  gpu_env = ''
    export LIBGL_DRIVERS_PATH=${pkgs.mesa}/lib/dri
    export LD_LIBRARY_PATH=${lib.makeLibraryPath [pkgs.mesa pkgs.libglvnd pkgs.sdl3]}
    export __GLX_VENDOR_LIBRARY_NAME=mesa
    export __EGL_VENDOR_LIBRARY_FILENAMES=${pkgs.mesa}/share/glvnd/egl_vendor.d/50_mesa.json
    export VGL_EGLLIB=${pkgs.libglvnd}/lib/libEGL.so.1
  '';
  debug_command = ''python3 tools/build_debug.py --cache "${config.devenv.state}/build-debug" --toolchain "${config.languages.odin.package}:${raylib}"'';
  probe_command = ''python3 tools/render_probe.py --executable "${config.devenv.state}/build-debug/hollie"'';
  temporary_task = command: {
    after = ["hollie:format"];
    exec = ''
      set -e
      task_dir=$(mktemp -d)
      trap 'rm -rf "$task_dir"' EXIT
      ${command}
    '';
  };
in {
  packages = [
    pkgs.python3
    # Private-display rendering probes; no host desktop tools are required.
    pkgs.xorg.xorgserver
    pkgs.xorg.xprop
    pkgs.xdotool
    pkgs.openbox
    pkgs.mesa-demos
    pkgs.imagemagick
    virtualgl
    # Let SDL filter duplicate physical and Steam Input virtual gamepads.
    raylib
  ];

  languages = {
    nix.enable = true;
    odin.enable = true;
  };

  env = {
    XDG_SESSION_TYPE = "x11";
    RES_ROOT = "./res";

    # Raylib's face-button constants are positional, including on Nintendo pads.
    SDL_GAMECONTROLLER_USE_BUTTON_LABELS = "0";
  };

  outputs.hollie = pkgs.stdenv.mkDerivation {
    pname = "hollie";
    version = "0.1.0";
    src = lib.fileset.toSource {
      root = ./.;
      fileset = lib.fileset.unions [./hollie ./res];
    };
    nativeBuildInputs = [config.languages.odin.package pkgs.makeWrapper];
    buildInputs = [raylib];
    buildPhase = ''
      runHook preBuild
      odin build hollie -o:speed -out:hollie-release
      runHook postBuild
    '';
    installPhase = ''
      runHook preInstall
      install -Dm755 hollie-release "$out/libexec/hollie"
      mkdir -p "$out/share/hollie"
      cp -r res "$out/share/hollie/res"
      makeWrapper "$out/libexec/hollie" "$out/bin/hollie" \
        --set RES_ROOT "$out/share/hollie/res" \
        --set SDL_GAMECONTROLLER_USE_BUTTON_LABELS 0
      runHook postInstall
    '';
    meta.mainProgram = "hollie";
  };

  profiles = {
    assets.module = {
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
    # No processes are registered in the default environment.
    automation.module = {
      processes.hollie-control = {
        exec = gpu_env + "exec " + probe_command + " --gpu --serve";
        after = ["hollie:build-debug"];
        restart.on = "never";
        shutdown.grace = 15;
      };
    };
  };

  tasks = {
    "hollie:build-debug" = {
      status = debug_command + " --status";
      exec = debug_command;
    };
    "hollie:automation-session" = {
      after = ["hollie:build-debug"];
      exec = gpu_env + probe_command + " --gpu --serve";
    };
    "hollie:automation-probe" = {
      after = ["hollie:build-debug"];
      exec =
        "set -e\n"
        + gpu_env
        + ''
          ${probe_command} --gpu --scenario tools/scenarios/movement.json
          ${probe_command} --gpu --scenario tools/scenarios/gamepad.json
        '';
    };
    "hollie:render-probe-gpu" = {
      after = ["hollie:build-debug"];
      exec = gpu_env + probe_command + " --gpu";
    };
    "hollie:render-probe" = {
      after = ["hollie:build-debug"];
      exec = ''
        export LIBGL_ALWAYS_SOFTWARE=1
        export LIBGL_DRIVERS_PATH=${pkgs.mesa}/lib/dri
        export LD_LIBRARY_PATH=${lib.makeLibraryPath [pkgs.mesa pkgs.libglvnd]}
        export __GLX_VENDOR_LIBRARY_NAME=mesa
        ${probe_command}
      '';
    };
    "hollie:run".exec = "odin run hollie -debug";
    "hollie:format".exec = "treefmt";
    "hollie:check" = {
      after = ["hollie:format"];
      exec = "odin check hollie -debug";
    };
    "hollie:build-release" = {
      after = ["hollie:format"];
      exec = "devenv build outputs.hollie";
    };
    "hollie:check-debug-cache" = temporary_task ''
      python3 tools/build_debug.py --cache "$task_dir" --toolchain "${config.languages.odin.package}:${raylib}"
      python3 tools/build_debug.py --cache "$task_dir" --toolchain "${config.languages.odin.package}:${raylib}" --status
    '';
    "hollie:test" = temporary_task ''odin test hollie -all-packages -out:"$task_dir/hollie-tests"'';
    "hollie:validate-content" = temporary_task ''odin run hollie/content_validate -out:"$task_dir/hollie-content-validate" -- res res/maps/*.json'';
    "hollie:check-tools" = {
      after = ["hollie:format"];
      exec = ''
        set -e
        python3 -c 'import pathlib; [compile(p.read_text(), str(p), "exec") for p in pathlib.Path("tools").glob("*.py")]'
        python3 -B -m unittest discover -s tools -p 'test_*.py'
      '';
    };
    "hollie:check-profiles" = {
      after = ["hollie:format"];
      exec = "devenv --profile assets --profile automation tasks list";
    };
    # Verification is unconditional; only the opt-in debug build is cached.
    "hollie:verify".after = [
      "hollie:check"
      "hollie:build-release"
      "hollie:check-debug-cache"
      "hollie:test"
      "hollie:validate-content"
      "hollie:check-tools"
      "hollie:check-profiles"
    ];
  };

  git-hooks.hooks.hollie-verify = {
    enable = true;
    name = "Hollie verification";
    entry = "devenv tasks run hollie:verify";
    files = "(^hollie/|^res/|^tools/|^devenv\\.|^odinfmt\\.json$)";
    pass_filenames = false;
  };

  treefmt = {
    enable = true;
    config.programs = {
      alejandra.enable = true;
      odinfmt.enable = true;
    };
    # https://github.com/numtide/treefmt-nix/issues/525
    config.settings.formatter.odinfmt.no-positional-arg-support = true;
  };
}
