"""Explicit, bounded Bevy rendering/control session on a private Xvfb display."""

import argparse
import json
import os
from pathlib import Path
import shutil
import signal
import subprocess
import sys
import tempfile
import time

sys.dont_write_bytecode = True
from game_control import Control_Client, run_scenario


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--executable", type=Path, required=True)
    parser.add_argument("--gpu", action="store_true")
    parser.add_argument("--windowed", action="store_true", help="Exercise the native window on the private display")
    parser.add_argument("--gpu-device", default=os.environ.get("HOLLIE_GPU_DEVICE"), help="WGPU adapter name substring")
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--scenario", type=Path)
    mode.add_argument("--serve", action="store_true")
    parser.add_argument("--session-timeout", type=int, default=300)
    args = parser.parse_args()
    if args.session_timeout < 1:
        parser.error("--session-timeout must be positive")
    repo = Path(__file__).resolve().parent.parent
    output = Path(tempfile.mkdtemp(prefix="hollie-render-probe-"))
    print(f"Probe artifacts: {output}", flush=True)
    control = output / "control"
    control.mkdir()
    shutil.copy2(args.executable, output / "hollie")
    (output / "build-source.txt").write_text(str(args.executable.resolve()) + "\n")
    env = os.environ.copy()
    env.update(RES_ROOT=str(repo / "res"), HOLLIE_CONTROL_DIR=str(control), HOLLIE_OFFSCREEN="0" if args.windowed else "1",
               HOLLIE_RENDERER_REPORT=str(output / "renderer.json"), WGPU_BACKEND="vulkan",
               WGPU_FORCE_FALLBACK_ADAPTER="false" if args.gpu else "true")
    env.pop("WAYLAND_DISPLAY", None)
    env["WINIT_UNIX_BACKEND"] = "x11"
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
        # Let Xvfb allocate an unused display; never inherit the host display.
        display_file = output / "display"
        with display_file.open("w") as display:
            log = (output / "xvfb.log").open("w")
            logs.append(log)
            xvfb = subprocess.Popen(
                ["Xvfb", "-displayfd", str(display.fileno()), "-screen", "0",
                 "1280x720x24", "-nolisten", "tcp", "-noreset"],
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
        game = start("game", [str(output / "hollie")])
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
        if args.scenario:
            run_scenario(client, args.scenario, output)
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
        if game.poll() is None:
            response = client.send({"op": "stop"})
            if response["error"]:
                raise RuntimeError(response["error"])
        game.wait(timeout=10)
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
