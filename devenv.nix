{pkgs, ...}: let
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
    (pkgs.raylib.override {platform = "SDL";})
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

  tasks = {
    "hollie:automation-session".exec = ''
      export LIBGL_DRIVERS_PATH=${pkgs.mesa}/lib/dri
      export LD_LIBRARY_PATH=${pkgs.lib.makeLibraryPath [pkgs.mesa pkgs.libglvnd pkgs.sdl3]}
      export __GLX_VENDOR_LIBRARY_NAME=mesa
      export __EGL_VENDOR_LIBRARY_FILENAMES=${pkgs.mesa}/share/glvnd/egl_vendor.d/50_mesa.json
      export VGL_EGLLIB=${pkgs.libglvnd}/lib/libEGL.so.1
      python3 tools/render_probe.py --gpu --serve
    '';
    "hollie:automation-probe".exec = ''
      set -e
      export LIBGL_DRIVERS_PATH=${pkgs.mesa}/lib/dri
      export LD_LIBRARY_PATH=${pkgs.lib.makeLibraryPath [pkgs.mesa pkgs.libglvnd pkgs.sdl3]}
      export __GLX_VENDOR_LIBRARY_NAME=mesa
      export __EGL_VENDOR_LIBRARY_FILENAMES=${pkgs.mesa}/share/glvnd/egl_vendor.d/50_mesa.json
      export VGL_EGLLIB=${pkgs.libglvnd}/lib/libEGL.so.1
      python3 tools/render_probe.py --gpu --scenario tools/scenarios/movement.json
      python3 tools/render_probe.py --gpu --scenario tools/scenarios/gamepad.json
    '';
    "hollie:render-probe-gpu".exec = ''
      export LIBGL_DRIVERS_PATH=${pkgs.mesa}/lib/dri
      export LD_LIBRARY_PATH=${pkgs.lib.makeLibraryPath [pkgs.mesa pkgs.libglvnd pkgs.sdl3]}
      export __GLX_VENDOR_LIBRARY_NAME=mesa
      export __EGL_VENDOR_LIBRARY_FILENAMES=${pkgs.mesa}/share/glvnd/egl_vendor.d/50_mesa.json
      export VGL_EGLLIB=${pkgs.libglvnd}/lib/libEGL.so.1
      python3 tools/render_probe.py --gpu
    '';
    "hollie:render-probe".exec = ''
      export LIBGL_ALWAYS_SOFTWARE=1
      export LIBGL_DRIVERS_PATH=${pkgs.mesa}/lib/dri
      export LD_LIBRARY_PATH=${pkgs.lib.makeLibraryPath [pkgs.mesa pkgs.libglvnd]}
      export __GLX_VENDOR_LIBRARY_NAME=mesa
      python3 tools/render_probe.py
    '';
    "hollie:run".exec = "odin run hollie -debug";
    "hollie:check".exec = "odin check hollie -debug";
    "hollie:test".exec = "odin test hollie -all-packages -out:/tmp/hollie-tests";
    "hollie:validate-content".exec = "odin run hollie/content_validate -out:/tmp/hollie-content-validate -- res res/maps/*.json";
    "hollie:verify".exec = ''
      set -e
      verify_dir=$(mktemp -d)
      trap 'rm -rf "$verify_dir"' EXIT
      treefmt
      odin check hollie -debug
      odin build hollie -o:speed -out:"$verify_dir/hollie-release"
      odin test hollie -all-packages -out:"$verify_dir/hollie-tests"
      odin run hollie/content_validate -out:"$verify_dir/hollie-content-validate" -- res res/maps/*.json
      python3 -c 'import pathlib; [compile(p.read_text(), str(p), "exec") for p in pathlib.Path("tools").glob("*.py")]'
    '';
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
