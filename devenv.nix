{pkgs, ...}: {
  packages = [pkgs.raylib];

  languages = {
    nix.enable = true;
    odin.enable = true;
  };

  env = {
    XDG_SESSION_TYPE = "x11";
    RES_ROOT = "./res";
  };

  tasks = {
    "hollie:run".exec = "odin run hollie -debug";
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
