"""Bounded Bevy rendering/control session on a private display or compositor."""

import argparse
import json
import os
import re
from pathlib import Path
import shutil
import signal
import subprocess
import sys
import tempfile
import time

sys.dont_write_bytecode = True
from game_control import Control_Client


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--executable", type=Path, required=True)
    parser.add_argument("--gpu", action="store_true")
    parser.add_argument("--gamescope", action="store_true")
    parser.add_argument("--windowed", action="store_true", help="Exercise the native window on the private display")
    parser.add_argument("--gpu-device", default=os.environ.get("HOLLIE_GPU_DEVICE"), help="WGPU adapter name substring")
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--journey", type=Path, help="Run a Robot journey on this private session")
    mode.add_argument("--serve", action="store_true")
    parser.add_argument("--display-size", default="1280x720")
    parser.add_argument("--render-size", default="640x360", help="Offscreen capture extent; native window tests retain their own size")
    parser.add_argument("--realtime", action="store_true", help="Pace offscreen updates at 60 Hz for comparison")
    parser.add_argument("--session-timeout", type=int, default=300)
    args = parser.parse_args()
    if not re.fullmatch(r"[1-9][0-9]*x[1-9][0-9]*", args.display_size):
        parser.error("--display-size must be WIDTHxHEIGHT")
    if not re.fullmatch(r"[1-9][0-9]*x[1-9][0-9]*", args.render_size) or any(
            int(size) > 8192 for size in args.render_size.split("x")):
        parser.error("--render-size must be WIDTHxHEIGHT with dimensions between 1 and 8192")
    if args.gamescope and not (args.gpu and args.windowed):
        parser.error("--gamescope requires --gpu --windowed")
    if args.session_timeout < 1:
        parser.error("--session-timeout must be positive")
    executable = args.executable.resolve(strict=True)
    repo = Path(__file__).resolve().parent.parent
    output = Path(tempfile.mkdtemp(prefix="hollie-render-probe-"))
    print(f"Probe artifacts: {output}", flush=True)
    control = output / "control"
    control.mkdir()
    build = json.loads(os.environ.get("DEVENV_TASKS_OUTPUTS", "{}")).get("hollie:build-debug", {})
    if build.get("executable") != str(executable):
        build = {"executable": str(executable)}
    (output / "build-info.json").write_text(json.dumps(build, indent=2) + "\n")
    env = os.environ.copy()
    env.update(RES_ROOT=str(repo / "res"), HOLLIE_CONTROL_DIR=str(control), HOLLIE_OFFSCREEN="0" if args.windowed else "1",
               HOLLIE_CAPTURE_SIZE=args.render_size, HOLLIE_AUTOMATION_REALTIME="1" if args.realtime or args.serve else "0",
               HOLLIE_RENDERER_REPORT=str(output / "renderer.json"), WGPU_BACKEND="vulkan",
               WGPU_FORCE_FALLBACK_ADAPTER="false" if args.gpu else "true")
    (output / "session-settings.json").write_text(json.dumps({"render_size": args.render_size if not args.windowed else "native",
        "realtime": args.realtime or args.serve or args.windowed, "display_size": args.display_size}) + "\n")
    # Exercise decoding and playback without sending probe audio to host speakers.
    alsa_config = output / "asound.conf"
    alsa_config.write_text("pcm.!default { type null }\n")
    env["ALSA_CONFIG_PATH"] = str(alsa_config)
    for key in ("DISPLAY", "WAYLAND_DISPLAY", "WAYLAND_SOCKET", "GAMESCOPE_WAYLAND_DISPLAY", "ENABLE_GAMESCOPE_WSI", "STEAM_GAME_DISPLAY_0"):
        env.pop(key, None)
    if args.gpu_device:
        env["WGPU_ADAPTER_NAME"] = args.gpu_device
    elif not args.gpu:
        env.pop("WGPU_ADAPTER_NAME", None)
    processes, logs = [], []

    def terminate(signum, frame):
        raise SystemExit(128 + signum)

    previous_sigterm = signal.signal(signal.SIGTERM, terminate)

    def start(name, command):
        log = (output / f"{name}.log").open("w")
        logs.append(log)
        process = subprocess.Popen(command, cwd=repo, env=env, stdout=log,
                                   stderr=subprocess.STDOUT, start_new_session=True)
        processes.append(process)
        return process

    def wait_until(predicate, process, description, timeout=30):
        deadline = time.monotonic() + timeout
        while time.monotonic() < deadline:
            if process.poll() is not None:
                raise RuntimeError(f"{description}: process exited {process.returncode}")
            result = predicate()
            if result:
                return result
            time.sleep(0.1)
        raise TimeoutError(f"Timed out waiting for {description}")

    try:
        if args.gamescope:
            runtime = output / "runtime"
            runtime.mkdir(mode=0o700)
            env["XDG_RUNTIME_DIR"] = str(runtime)
            env["ENABLE_GAMESCOPE_WSI"] = "1"
            width, height = args.display_size.split("x")
            game = start("game", ["gamescope", "--backend", "headless", "--expose-wayland",
                "-w", width, "-h", height, "-W", width, "-H", height, "-r", "60", "--", str(executable)])
        else:
            # Let Xvfb allocate an unused display; never inherit the host display.
            display_file = output / "display"
            with display_file.open("w") as display:
                log = (output / "xvfb.log").open("w")
                logs.append(log)
                xvfb = subprocess.Popen(
                    ["Xvfb", "-displayfd", str(display.fileno()), "-screen", "0",
                     f"{args.display_size}x24", "-nolisten", "tcp", "-noreset"],
                    stdout=log, stderr=subprocess.STDOUT,
                    pass_fds=(display.fileno(),), start_new_session=True)
                processes.append(xvfb)
                number = wait_until(lambda: display_file.read_text().strip(), xvfb, "virtual display")
            env["DISPLAY"] = f":{number}"
            wm = start("openbox", ["openbox", "--sm-disable"])

            def wm_ready():
                result = subprocess.run(["xprop", "-root", "_NET_SUPPORTING_WM_CHECK"],
                                        env=env, capture_output=True, text=True, timeout=2)
                return "_NET_SUPPORTING_WM_CHECK(WINDOW)" in result.stdout

            wait_until(wm_ready, wm, "window manager")
            game = start("game", [str(executable)])
        report = output / "renderer.json"
        wait_until(report.is_file, game, "Bevy renderer")
        renderer = json.loads(report.read_text())
        print(json.dumps(renderer), flush=True)
        software = renderer["device_type"] == "Cpu" or any(
            name in renderer["name"].lower() for name in ("llvmpipe", "lavapipe", "software"))
        if args.gpu and software:
            raise RuntimeError(f"GPU session selected a software adapter: {renderer}")
        if not args.gpu and not software:
            raise RuntimeError(f"Software session selected a hardware adapter: {renderer}")
        client = Control_Client(control, game)
        ready = client.wait_for_response(0)
        if ready["error"]:
            raise RuntimeError(ready["error"])
        if args.journey:
            from robot_game import run_journey
            run_journey(control, args.journey, output)
            print(f"Journey passed: {args.journey.stem}", flush=True)
        elif args.serve:
            print(f"Paused control session: {control}", flush=True)
            deadline = time.monotonic() + args.session_timeout
            while game.poll() is None and time.monotonic() < deadline:
                time.sleep(0.1)
            if game.poll() is None:
                raise TimeoutError("Control session reached --session-timeout")
        else:
            for command in ({"op": "observe", "capture": "title.png"},
                            {"op": "reset", "room": "demo", "players": 1,
                             "seed": 42, "capture": "gameplay.png"}):
                response = client.send(command)
                if response["error"]:
                    raise RuntimeError(response["error"])
                shutil.copy2(response["capture"], output / command["capture"])
            print("Captured title.png and gameplay.png; inspect images and game.log.", flush=True)
        if args.gamescope and not args.serve and not args.journey:
            for filename in ("title.png", "gameplay.png"):
                size = subprocess.check_output(["magick", "identify", "-format", "%wx%h", str(output / filename)],
                    env=env, text=True, timeout=10).strip()
                print(f"Gamescope render extent: {filename}: {size} (display {args.display_size})", flush=True)
                if size != args.display_size:
                    raise AssertionError(f"Gamescope rendered {size}, expected {args.display_size}")
        if args.windowed and not args.gamescope and not args.serve:
            subprocess.run(["magick", "import", "-window", "root", str(output / "display.png")],
                           env=env, check=True, timeout=30)
            if not args.journey:
                for filename in ("title.png", "gameplay.png", "display.png"):
                    size = subprocess.check_output(
                        ["magick", "identify", "-format", "%wx%h", str(output / filename)],
                        env=env, text=True, timeout=10).strip()
                    if size != args.display_size:
                        raise AssertionError(f"{filename} rendered at {size}, expected native {args.display_size}")
                # The game clear colour is blue; black side strips indicate pillarboxing.
                for side in ("West", "East"):
                    brightness = float(subprocess.check_output(
                        ["magick", str(output / "display.png"), "-gravity", side,
                         "-crop", "8x0+0+0", "+repage", "-format", "%[fx:mean]", "info:"],
                        env=env, text=True, timeout=10))
                    if brightness < 0.01:
                        raise AssertionError(f"Black {side} border on the private display")
                print(f"Native fullscreen verified: {args.display_size}, no black side bars", flush=True)
        if game.poll() is None:
            response = client.send({"op": "stop"})
            if response["error"]:
                raise RuntimeError(response["error"])
        game.wait(timeout=10)
        runtime_log = (output / "game.log").read_text()
        if re.search(r"ERROR (?:bevy_render|bevy_asset)|panicked at", runtime_log):
            raise RuntimeError(f"Rendering or asset errors; inspect {output / 'game.log'}")
        if game.returncode != 0:
            raise RuntimeError(f"Game exited {game.returncode}; inspect game.log")
    finally:
        signal.signal(signal.SIGTERM, signal.SIG_IGN)
        for process in reversed(processes):
            if process.poll() is None:
                os.killpg(process.pid, signal.SIGTERM)
                try:
                    process.wait(timeout=3)
                except subprocess.TimeoutExpired:
                    os.killpg(process.pid, signal.SIGKILL)
                    process.wait(timeout=3)
        for log in logs:
            log.close()
        signal.signal(signal.SIGTERM, previous_sigterm)


if __name__ == "__main__":
    main()
