"""Private Bevy game sessions for Robot and interactive control."""

import argparse
from contextlib import contextmanager
from dataclasses import dataclass
import json
import os
from pathlib import Path
import re
import signal
import subprocess
import sys
import tempfile
import time

sys.dont_write_bytecode = True
from game_control import Control_Client


@dataclass
class Session_Options:
    executable: Path
    gamescope: bool = False
    gpu_device: str | None = None
    display_size: str = "1280x720"
    render_size: str = "640x360"
    realtime: bool = False
    session_timeout: int = 300


@dataclass
class Game_Session:
    client: Control_Client
    game: subprocess.Popen
    output: Path


@contextmanager
def private_session(args, output=None):
    if not re.fullmatch(r"[1-9][0-9]*x[1-9][0-9]*", args.display_size):
        raise ValueError("--display-size must be WIDTHxHEIGHT")
    if not re.fullmatch(r"[1-9][0-9]*x[1-9][0-9]*", args.render_size) or any(
            int(size) > 8192 for size in args.render_size.split("x")):
        raise ValueError("--render-size must be WIDTHxHEIGHT with dimensions between 1 and 8192")
    if args.session_timeout < 1:
        raise ValueError("--session-timeout must be positive")
    executable = args.executable.resolve(strict=True)
    repo = Path(__file__).resolve().parent.parent
    output = Path(output or tempfile.mkdtemp(prefix="hollie-session-"))
    output.mkdir(parents=True, exist_ok=True)
    print(f"Session artifacts: {output}", flush=True)
    control = output / "control"
    control.mkdir()
    build = json.loads(os.environ.get("DEVENV_TASKS_OUTPUTS", "{}")).get("hollie:build-debug", {})
    if build.get("executable") != str(executable):
        build = {"executable": str(executable)}
    (output / "build-info.json").write_text(json.dumps(build, indent=2) + "\n")
    env = os.environ.copy()
    env.update(RES_ROOT=str(repo / "res"), HOLLIE_CONTROL_DIR=str(control), HOLLIE_OFFSCREEN="0" if args.gamescope else "1",
               HOLLIE_CAPTURE_SIZE=args.render_size, HOLLIE_AUTOMATION_REALTIME="1" if args.realtime else "0",
               HOLLIE_RENDERER_REPORT=str(output / "renderer.json"), WGPU_BACKEND="vulkan",
               WGPU_FORCE_FALLBACK_ADAPTER="false")
    (output / "session-settings.json").write_text(json.dumps({"render_size": "native" if args.gamescope else args.render_size,
        "realtime": args.realtime or args.gamescope, "display_size": args.display_size}) + "\n")
    # Exercise decoding and playback without sending probe audio to host speakers.
    alsa_config = output / "asound.conf"
    alsa_config.write_text("pcm.!default { type null }\n")
    env["ALSA_CONFIG_PATH"] = str(alsa_config)
    for key in ("DISPLAY", "WAYLAND_DISPLAY", "WAYLAND_SOCKET", "GAMESCOPE_WAYLAND_DISPLAY", "ENABLE_GAMESCOPE_WSI", "STEAM_GAME_DISPLAY_0"):
        env.pop(key, None)
    if args.gpu_device:
        env["WGPU_ADAPTER_NAME"] = args.gpu_device
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
            game = start("game", [str(executable)])
        report = output / "renderer.json"
        wait_until(report.is_file, game, "Bevy renderer")
        renderer = json.loads(report.read_text())
        print(json.dumps(renderer), flush=True)
        software = renderer["device_type"] == "Cpu" or any(
            name in renderer["name"].lower() for name in ("llvmpipe", "lavapipe", "software"))
        if software:
            raise RuntimeError(f"GPU session selected a software adapter: {renderer}")
        client = Control_Client(control, game)
        ready = client.wait_for_response(0)
        if ready["error"]:
            raise RuntimeError(ready["error"])
        yield Game_Session(client, game, output)
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


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--executable", type=Path, required=True)
    parser.add_argument("--gamescope", action="store_true")
    parser.add_argument("--gpu-device", default=os.environ.get("HOLLIE_GPU_DEVICE"))
    parser.add_argument("--display-size", default="1280x720")
    parser.add_argument("--render-size", default="640x360")
    parser.add_argument("--session-timeout", type=int, default=300)
    options = Session_Options(**vars(parser.parse_args()), realtime=True)
    with private_session(options) as session:
        print(f"Paused control session: {session.output / 'control'}", flush=True)
        deadline = time.monotonic() + options.session_timeout
        while session.game.poll() is None and time.monotonic() < deadline:
            time.sleep(0.1)
        if session.game.poll() is None:
            raise TimeoutError("Control session reached --session-timeout")


if __name__ == "__main__":
    main()
