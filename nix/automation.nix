{
  pkgs,
  config,
  ...
}: let
  session_command = ''python3 tools/game_session.py --executable "${config.env.CARGO_TARGET_DIR}/debug/hollie" --gpu'';
in {
  packages = with pkgs; [
    gamescope
    xwayland
    (python3.withPackages (python: [python.robotframework (python.callPackage ./pabot.nix {})]))
    xorg.xorgserver
    xorg.xprop
    xdotool
    openbox
    imagemagick
    mesa
  ];
  profiles.automation.module.processes.hollie-control = {
    exec = "exec " + session_command;
    after = ["hollie:build-debug"];
    restart.on = "never";
    shutdown.grace = 15;
  };
  scripts.hollie-session.exec = ''
    set -e
    devenv tasks run hollie:build-debug
    exec ${session_command} "$@"
  '';
  tasks."hollie:automation-probe" = {
    after = ["hollie:build-debug"];
    exec = ''
      set -e
      artifacts="$(mktemp -d --tmpdir hollie-robot-XXXXXXXX)"
      pabot --processes 4 --no-pabotlib --pythonpath tools \
        --artifacts png,json,log --artifactsinsubfolders \
        --suitesfrom "${config.devenv.state}/robot-last.xml" \
        --outputdir "$artifacts" tools/robot
      ln -sfn "$artifacts/output.xml" "${config.devenv.state}/robot-last.xml"
    '';
  };
}
