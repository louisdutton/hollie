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
              resvg
              go-task
              ffmpeg
              claude-code
              aseprite

              # debugging
              gdb

              # language support
              ols
              nixd
              alejandra
            ];
          };
        }
    );
  };
}
