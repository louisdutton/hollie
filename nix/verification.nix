{
  pkgs,
  config,
  ...
}: {
  tasks = {
    "hollie:build-debug" = {
      after = ["hollie:format"];
      execIfModified = [
        "src"
        "Cargo.toml"
        "Cargo.lock"
        "build.rs"
        ".cargo"
        "rust-toolchain"
        "rust-toolchain.toml"
        "devenv.nix"
        "devenv.yaml"
        "devenv.lock"
        "nix"
        "assets/hollie-background.png"
        # Cargo clean must invalidate the task cache as well as source edits.
        "${config.env.CARGO_TARGET_DIR}/debug/hollie"
      ];
      exec = ''
        set -e
        cargo build --locked --bin hollie
        ${pkgs.jq}/bin/jq -n \
          --arg executable "${config.env.CARGO_TARGET_DIR}/debug/hollie" \
          --arg sha256 "$(${pkgs.coreutils}/bin/sha256sum "${config.env.CARGO_TARGET_DIR}/debug/hollie" | ${pkgs.coreutils}/bin/cut -d ' ' -f 1)" \
          '{executable: $executable, sha256: $sha256}' > "$DEVENV_TASK_OUTPUT_FILE"
      '';
    };
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
      exec = ''
        set -e
        python3 -c 'import pathlib; [compile(p.read_text(), str(p), "exec") for p in pathlib.Path("tools").glob("*.py")]'
        python3 -m unittest discover -s tools -p 'test_*.py'
        python3 -m robot --dryrun --pythonpath tools --output NONE --log NONE --report NONE tools/robot
      '';
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
    files = "(^src/|^res/|^assets/|^tools/|^Cargo\\.(toml|lock)$|^devenv\\.|^nix/)";
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
