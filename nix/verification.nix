{...}: {
  tasks = {
    # Cargo tracks source, dependency and compiler changes and missing outputs.
    "hollie:build-debug" = {
      after = ["hollie:format"];
      exec = "cargo build --locked --bin hollie";
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
        python3 -m robot --dryrun --pythonpath tools --variable CONTROL_SOURCE:unused --variable ARTIFACT_DIR:unused --output NONE --log NONE --report NONE tools/robot
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
