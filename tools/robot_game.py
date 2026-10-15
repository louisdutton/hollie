"""Robot bindings for fixed-tick game input and asynchronous rendered captures."""

from html import escape
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import time

from robot.api import logger
from robot.api.deco import keyword, library
from robot.libraries.BuiltIn import BuiltIn
from game_control import Control_Client
from game_session import Session_Options, private_session


@library(scope="SUITE", auto_keywords=False)
class Hollie:
    def __init__(self, directory=None, output=None):
        self.output = Path(output) if output else None
        self.captures = self.output
        self.output_root = self.output
        self.client = Control_Client(directory) if directory else None
        self.context = None
        self.session = None
        self.trace = []

    @keyword
    def start_private_game(self, executable, backend="offscreen",
                           display_size="1280x720", render_size="640x360"):
        if self.context is not None:
            raise RuntimeError("A private game is already running in this journey")
        if backend not in ("offscreen", "gamescope"):
            raise ValueError(f"Unknown private display backend: {backend}")
        self.trace = []
        self.output_root = Path(BuiltIn().get_variable_value("${OUTPUT DIR}"))
        self.output = Path(tempfile.mkdtemp(prefix="session-", dir=self.output_root))
        self.captures = self.output / "control"
        options = Session_Options(Path(executable), gamescope=backend == "gamescope",
            display_size=display_size, render_size=render_size,
            gpu_device=os.environ.get("HOLLIE_GPU_DEVICE"))
        context = private_session(options, self.output)
        self.session = context.__enter__()
        self.context = context
        self.client = self.session.client
        width, height = (display_size if options.gamescope else render_size).split("x")
        return {"width": int(width), "height": int(height)}

    @keyword
    def finish_journey(self):
        try:
            if self.output is not None:
                self.save_journey_evidence()
        finally:
            if self.context is not None:
                context, self.context = self.context, None
                try:
                    context.__exit__(*sys.exc_info())
                finally:
                    self.session = None
                    self.client = None

    def artifact_link(self, path):
        return str(path.relative_to(self.output_root))

    def send(self, command, capture="", expected_error=""):
        if capture:
            if Path(capture).name != capture:
                raise ValueError("Captures must be plain filenames")
            command["capture"] = capture
        entry = {"command": command}
        self.trace.append(entry)
        started = time.perf_counter()
        try:
            response = self.client.send(command)
            entry["response"] = response
            if response["error"] != expected_error:
                raise AssertionError(f"Command {command!r}: {response!r}")
            if capture:
                logger.info(f'<a href="{escape(self.artifact_link(Path(response["capture"])), quote=True)}">{escape(capture)}</a>', html=True)
            return response["state"]
        except Exception as error:
            entry["error"] = str(error)
            raise
        finally:
            entry["seconds"] = time.perf_counter() - started

    @keyword
    def reset_game(self, room=None, players: int | None = None, seed: int | None = None, capture="", expected_error=""):
        options = {key: value for key, value in {"room": room, "players": players, "seed": seed}.items()
                   if value is not None}
        return self.send({"op": "reset", **options}, capture, expected_error)

    @keyword
    def advance_ticks(self, ticks: int, *keys, capture="", expected_error="", gamepads: list | None = None):
        command = {"op": "step", "frames": ticks}
        if keys:
            command["keys"] = list(keys)
        if gamepads is not None:
            command["gamepads"] = gamepads
        return self.send(command, capture, expected_error)

    @keyword
    def move_stick_for_ticks(self, ticks: int, left_x: float, left_y: float, player="Player_1", capture="", expected_error=""):
        return self.advance_ticks(ticks, gamepads=[{"player": player, "axes": [left_x, left_y]}],
                                  capture=capture, expected_error=expected_error)

    @keyword
    def press_gamepad_for_ticks(self, ticks: int, player, *buttons, capture="", expected_error=""):
        return self.advance_ticks(ticks, gamepads=[{"player": player, "buttons": list(buttons)}],
                                  capture=capture, expected_error=expected_error)

    @keyword
    def observe_game(self, capture=""):
        return self.send({"op": "observe"}, capture)

    @keyword
    def images_should_match(self, first, second):
        diff = f"diff-{Path(first).stem}-{Path(second).stem}.png"
        result = subprocess.run(["magick", "compare", "-metric", "AE", str(self.captures / first),
                                 str(self.captures / second), str(self.output / diff)],
                                capture_output=True, text=True, timeout=10)
        if result.returncode != 0:
            logger.info(f'<a href="{escape(self.artifact_link(self.output / diff), quote=True)}">Pixel difference</a>', html=True)
            raise AssertionError(f"{first} vs {second}: pixels differ (AE={result.stderr.strip()}); inspect {diff}")
        (self.output / diff).unlink(missing_ok=True)

    @keyword
    def image_dimensions_should_be(self, image, width: int, height: int):
        actual = subprocess.check_output(["magick", "identify", "-format", "%wx%h",
                                          str(self.captures / image)], text=True, timeout=10).strip()
        if actual != f"{width}x{height}":
            raise AssertionError(f"{image}: {actual}, expected {width}x{height}")

    @keyword
    def save_journey_evidence(self):
        (self.output / "commands.json").write_text(json.dumps(self.trace, indent=2) + "\n")
