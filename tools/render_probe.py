"""Explicit, bounded native rendering probe; run via hollie:render-probe."""

import os
from pathlib import Path
import signal
import subprocess
import tempfile
import time


def main():
    repo = Path(__file__).resolve().parent.parent
    output = Path(tempfile.mkdtemp(prefix="hollie-render-probe-"))
    print(f"Probe artifacts: {output}", flush=True)
    env = os.environ.copy()
    env["RES_ROOT"] = str(repo / "res")
    processes = []
    logs = []

    def start(name, command):
        log = (output / f"{name}.log").open("w")
        logs.append(log)
        process = subprocess.Popen(
            command, cwd=repo, env=env, stdout=log,
            stderr=subprocess.STDOUT, start_new_session=True,
        )
        processes.append(process)
        return process

    def run(command, timeout=10):
        return subprocess.run(
            command, cwd=repo, env=env, check=True,
            capture_output=True, text=True, timeout=timeout,
        ).stdout.strip()

    def wait_until(predicate, process, description):
        deadline = time.monotonic() + 10
        while time.monotonic() < deadline:
            if process.poll() is not None:
                raise RuntimeError(f"{description}: process exited {process.returncode}")
            result = predicate()
            if result:
                return result
            time.sleep(0.1)
        raise RuntimeError(f"Timed out waiting for {description}")

    def find_window():
        result = subprocess.run(
            ["xdotool", "search", "--onlyvisible", "--pid", str(game.pid)],
            env=env, capture_output=True, text=True, timeout=2,
        )
        return result.stdout.splitlines()[0] if result.stdout.strip() else None

    def press(key):
        # SDL can miss down/up events delivered within one slow software frame.
        run(["xdotool", "keydown", "--clearmodifiers", key])
        time.sleep(0.25)
        run(["xdotool", "keyup", key])

    try:
        # Xvfb chooses an unused display; never connect to the user's desktop.
        display_file = output / "display"
        with display_file.open("w") as display:
            log = (output / "xvfb.log").open("w")
            logs.append(log)
            xvfb = subprocess.Popen(
                ["Xvfb", "-displayfd", str(display.fileno()), "-screen", "0",
                 "1280x720x24", "-nolisten", "tcp", "-noreset"],
                stdout=log, stderr=subprocess.STDOUT,
                pass_fds=(display.fileno(),), start_new_session=True,
            )
            processes.append(xvfb)
            display_number = wait_until(
                lambda: display_file.read_text().strip(), xvfb, "virtual display",
            )
        env["DISPLAY"] = f":{display_number}"
        gl_probe = subprocess.run(
            ["glxinfo", "-B"], cwd=repo, env=env,
            capture_output=True, text=True, timeout=10,
        )
        gl_info = gl_probe.stdout + gl_probe.stderr
        (output / "opengl.txt").write_text(gl_info + "\n")
        print(gl_info, flush=True)
        gl_probe.check_returncode()
        if "OpenGL renderer string:" not in gl_info:
            raise RuntimeError("OpenGL context unavailable; see opengl.txt")
        wm = start("openbox", ["openbox", "--sm-disable"])
        wait_until(
            lambda: "_NET_SUPPORTING_WM_CHECK(WINDOW)" in run(
                ["xprop", "-root", "_NET_SUPPORTING_WM_CHECK"]
            ), wm, "window manager",
        )
        build = subprocess.run(
            ["odin", "build", "hollie", "-debug", f"-out:{output / 'hollie'}"],
            cwd=repo, env=env, capture_output=True, text=True, timeout=180,
        )
        (output / "build.log").write_text(build.stdout + build.stderr)
        build.check_returncode()
        game = start("game", [str(output / "hollie")])
        window = wait_until(find_window, game, "game window")
        run(["xdotool", "windowactivate", "--sync", window])
        for scene in ("title", "gameplay"):
            if scene == "gameplay":
                press("Return")
            time.sleep(3)
            if game.poll() is not None:
                raise RuntimeError(f"Game exited before {scene} capture")
            run(["magick", "import", "-window", window, str(output / f"{scene}.png")])
        press("BackSpace")
        game.wait(timeout=5)
        if game.returncode != 0:
            raise RuntimeError(f"Game exited {game.returncode}")
        print("Captured title.png and gameplay.png; inspect images and game.log.", flush=True)
    finally:
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


if __name__ == "__main__":
    main()
