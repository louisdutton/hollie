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
  scenarios = ["audio" "movement" "gamepad" "editor" "debug" "rooms" "surfaces" "riding" "dismount" "carrying" "throwing" "bison"];
in {
  packages = with pkgs; [gamescope xwayland python3 xorg.xorgserver xorg.xprop xdotool openbox imagemagick mesa];
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
        (scenario: "${probe_command} --gpu --scenario tools/scenarios/${scenario}.json")
        scenarios
        + ''

          ${probe_command} --gpu --windowed --gamescope --display-size 3840x2160 --scenario tools/scenarios/display.json
        '';
    };
    "hollie:automation-probe-native" = probe_task "--windowed --scenario tools/scenarios/rooms.json";
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
