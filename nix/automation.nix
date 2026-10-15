{
  pkgs,
  lib,
  config,
  ...
}: let
  probe_command = ''python3 tools/render_probe.py --executable "${config.env.CARGO_TARGET_DIR}/debug/hollie"'';
  probe_task = arguments: {
    after = ["hollie:build-debug"];
    exec = probe_command + " " + arguments;
  };
  journeys = ["audio" "movement" "gamepad" "editor" "debug" "rooms" "surfaces" "riding" "dismount" "carrying" "throwing" "bison"];
in {
  packages = with pkgs; [gamescope xwayland (python3.withPackages (python: [python.robotframework])) xorg.xorgserver xorg.xprop xdotool openbox imagemagick mesa];
  profiles.automation.module.processes.hollie-control = {
    exec = "exec " + probe_command + " --gpu --serve";
    after = ["hollie:build-debug"];
    restart.on = "never";
    shutdown.grace = 15;
  };
  tasks = {
    "hollie:automation-session" = probe_task "--gpu --serve";
    "hollie:automation-session-native" = probe_task "--windowed --serve";
    "hollie:automation-session-gamescope" = probe_task "--gpu --windowed --gamescope --display-size 3840x2160 --serve";
    "hollie:automation-probe" = {
      after = ["hollie:build-debug"];
      # Keep GPU sessions serial; concurrent renderers contend for device resources.
      exec =
        "set -e\n"
        + lib.concatMapStringsSep "\n"
        (journey: "${probe_command} --gpu --journey tools/robot/${journey}.robot")
        journeys
        + ''

          ${probe_command} --gpu --windowed --gamescope --display-size 3840x2160 --journey tools/robot/display.robot
        '';
    };
    "hollie:automation-probe-native" = probe_task "--windowed --journey tools/robot/rooms.robot";
    "hollie:render-probe" = probe_task "--windowed";
    "hollie:render-probe-gpu" = probe_task "--gpu";
    "hollie:render-probe-gamescope" = probe_task "--gpu --windowed --gamescope --display-size 3840x2160";
    "hollie:render-probe-wide" = {
      after = ["hollie:build-debug"];
      exec = ''
        set -e
        ${probe_command} --windowed --display-size 1920x1080
        ${probe_command} --windowed --display-size 2560x1080
      '';
    };
    "hollie:render-probe-4k" = {
      after = ["hollie:build-debug"];
      exec = ''
        set -e
        ${probe_command} --windowed --display-size 3840x2160
        WINIT_X11_SCALE_FACTOR=2 ${probe_command} --windowed --display-size 3840x2160
      '';
    };
  };
}
