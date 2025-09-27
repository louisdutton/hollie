{
  description = "A Nix-flake-based Odin development environment";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

  outputs = {
    self,
    nixpkgs,
  }: let
    supportedSystems = [
      "x86_64-linux"
      "aarch64-linux"
    ];

    forEachSupportedSystem = f:
      nixpkgs.lib.genAttrs supportedSystems (
        system:
          f {
            pkgs = import nixpkgs {
              inherit system;
              config.allowUnfree = true;
            };
          }
      );
  in {
    devShells = forEachSupportedSystem (
      {pkgs}:
        with pkgs; {
          default = mkShell {
            nativeBuildInputs = [
              odin
              sdl3
              raylib
            ];

            packages = [
              # tools
              claude-code
              aseprite

              # debugging
              gdb

              # language support
              ols
              nixd
              alejandra
            ];

            # GALLIUM_HUD = "fps,cpu";
            XDG_SESSION_TYPE = "x11"; # wayland can't handle fullscreen
          };
        }
    );
  };
}
