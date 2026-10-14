{
  pkgs,
  lib,
  config,
  ...
}: let
  runtime_libraries = with pkgs; [alsa-lib udev libxkbcommon vulkan-loader wayland libGL xorg.libX11 xorg.libXcursor xorg.libXi xorg.libXrandr];
  probe_command = ''python3 tools/render_probe.py --executable "${config.env.CARGO_TARGET_DIR}/debug/hollie"'';
  gpu_env = ''
    export WGPU_BACKEND=vulkan
    export WGPU_FORCE_FALLBACK_ADAPTER=false
  '';
in {
  packages = [pkgs.python3 pkgs.pkg-config pkgs.xorg.xorgserver pkgs.xorg.xprop pkgs.xdotool pkgs.openbox pkgs.imagemagick pkgs.mesa] ++ runtime_libraries;
  languages = {
    nix.enable = true;
    rust.enable = true;
  };
  env = {
    XDG_SESSION_TYPE = "x11";
    RES_ROOT = "./res";
    CARGO_TARGET_DIR = "${config.devenv.state}/cargo-target";
    LD_LIBRARY_PATH = lib.makeLibraryPath runtime_libraries;
  };
  outputs.hollie = pkgs.rustPlatform.buildRustPackage {
    pname = "hollie";
    version = "0.1.0";
    src = lib.fileset.toSource {
      root = ./.;
      fileset = lib.fileset.unions [./src ./res ./assets ./Cargo.toml ./Cargo.lock];
    };
    cargoLock.lockFile = ./Cargo.lock;
    nativeBuildInputs = [pkgs.pkg-config pkgs.makeWrapper];
    buildInputs = runtime_libraries;
    cargoBuildFlags = ["--bin" "hollie"];
    # Tests use the repository resources through the local verification task.
    doCheck = false;
    postInstall = ''
      mkdir -p "$out/share/hollie"
      cp -r res "$out/share/hollie/res"
      wrapProgram "$out/bin/hollie" \
        --set RES_ROOT "$out/share/hollie/res" \
        --prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath runtime_libraries}"
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
    # Cargo tracks source, dependency and compiler changes and missing outputs.
    "hollie:build-debug" = {
      after = ["hollie:format"];
      exec = "cargo build --locked --bin hollie";
    };
    "hollie:automation-session" = {
      after = ["hollie:build-debug"];
      exec = gpu_env + probe_command + " --gpu --serve";
    };
    "hollie:automation-session-native" = {
      after = ["hollie:build-debug"];
      exec = ''
        export WGPU_BACKEND=vulkan
        export WGPU_FORCE_FALLBACK_ADAPTER=true
        ${probe_command} --windowed --serve
      '';
    };
    "hollie:automation-probe" = {
      after = ["hollie:build-debug"];
      exec =
        "set -e\n"
        + gpu_env
        + ''
          ${probe_command} --gpu --scenario tools/scenarios/movement.json
          ${probe_command} --gpu --scenario tools/scenarios/gamepad.json
          ${probe_command} --gpu --scenario tools/scenarios/editor.json
          ${probe_command} --gpu --scenario tools/scenarios/rooms.json
          ${probe_command} --gpu --scenario tools/scenarios/surfaces.json
          ${probe_command} --gpu --scenario tools/scenarios/riding.json
          ${probe_command} --gpu --scenario tools/scenarios/carrying.json
          ${probe_command} --gpu --scenario tools/scenarios/throwing.json
          ${probe_command} --gpu --scenario tools/scenarios/bison.json
        '';
    };
    "hollie:automation-probe-native" = {
      after = ["hollie:build-debug"];
      exec = ''
        ${probe_command} --windowed --scenario tools/scenarios/rooms.json
      '';
    };
    "hollie:render-probe-wide" = {
      after = ["hollie:build-debug"];
      exec =
        "set -e\n"
        + ''
          ${probe_command} --windowed --display-size 1920x1080
          ${probe_command} --windowed --display-size 2560x1080
        '';
    };
    "hollie:render-probe-gpu" = {
      after = ["hollie:build-debug"];
      exec = gpu_env + probe_command + " --gpu";
    };
    "hollie:render-probe" = {
      after = ["hollie:build-debug"];
      exec = ''
        export WGPU_BACKEND=vulkan
        export WGPU_FORCE_FALLBACK_ADAPTER=true
        ${probe_command} --windowed
      '';
    };
    "hollie:run".exec = "cargo run --locked --bin hollie";
    "hollie:format".exec = "treefmt";
    "hollie:check" = {
      after = ["hollie:format"];
      exec = "cargo clippy --locked --all-targets";
    };
    "hollie:build-release" = {
      after = ["hollie:check" "hollie:build-debug" "hollie:test" "hollie:validate-content"];
      exec = "devenv build outputs.hollie";
    };
    "hollie:test" = {
      after = ["hollie:format"];
      exec = "cargo test --locked --all-targets";
    };
    "hollie:validate-content" = {
      after = ["hollie:format"];
      exec = "cargo run --locked --bin content_validate -- res";
    };
    "hollie:check-tools" = {
      after = ["hollie:format"];
      exec = ''python3 -c 'import pathlib; [compile(p.read_text(), str(p), "exec") for p in pathlib.Path("tools").glob("*.py")]' '';
    };
    "hollie:check-profiles" = {
      after = ["hollie:format"];
      exec = "devenv --profile assets --profile automation tasks list";
    };
    "hollie:verify".after = ["hollie:check" "hollie:build-debug" "hollie:build-release" "hollie:test" "hollie:validate-content" "hollie:check-tools" "hollie:check-profiles"];
  };
  git-hooks.hooks.hollie-verify = {
    enable = true;
    name = "Hollie verification";
    entry = "devenv tasks run hollie:verify";
    files = "(^src/|^res/|^assets/|^tools/|^Cargo\\.(toml|lock)$|^devenv\\.)";
    pass_filenames = false;
  };
  treefmt = {
    enable = true;
    config.programs = {
      alejandra.enable = true;
      rustfmt.enable = true;
    };
  };
}
