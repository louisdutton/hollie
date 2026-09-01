{pkgs, ...}: {
  packages = [
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
  };

  tasks = {
    "hollie:run" = {
      exec = "odin run hollie -debug";
      env = {
        # Raylib's face-button constants are positional, including on Nintendo pads.
        SDL_GAMECONTROLLER_USE_BUTTON_LABELS = "0";
      };
    };
    "hollie:check".exec = "odin check hollie -debug";
    "hollie:test".exec = "odin test hollie -all-packages -out:/tmp/hollie-tests";
    "hollie:validate-content".exec = "odin run hollie/content_validate -out:/tmp/hollie-content-validate -- res res/maps/*.json";
    "hollie:verify".exec = ''
      set -e
      odin check hollie -debug
      odin test hollie -all-packages -out:/tmp/hollie-tests
      odin run hollie/content_validate -out:/tmp/hollie-content-validate -- res res/maps/*.json
    '';
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
