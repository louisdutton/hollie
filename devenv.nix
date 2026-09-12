{pkgs, ...}: {
  packages = [
    pkgs.python3
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
