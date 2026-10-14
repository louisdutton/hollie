{
  pkgs,
  lib,
  config,
  ...
}: let
  runtime_libraries = with pkgs; [alsa-lib udev libxkbcommon vulkan-loader wayland libGL xorg.libX11 xorg.libXcursor xorg.libXi xorg.libXrandr];
in {
  imports = [./nix/assets.nix ./nix/automation.nix ./nix/verification.nix];
  packages = [pkgs.pkg-config] ++ runtime_libraries;
  languages = {
    nix.enable = true;
    rust.enable = true;
  };
  env = {
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
  tasks."hollie:run".exec = "cargo run --locked --bin hollie";
}
