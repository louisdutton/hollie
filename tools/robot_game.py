"""Robot bindings for fixed-tick game input and asynchronous rendered captures."""

from html import escape
import json
from pathlib import Path
import shutil
import subprocess
import time

from robot.api import logger
from robot.api.deco import keyword, library
from game_control import Control_Client


@library(scope="SUITE", auto_keywords=False)
class Hollie:
    def __init__(self, directory, output):
        self.output = Path(output)
        self.client = Control_Client(directory)
        self.trace = []

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
                shutil.copyfile(response["capture"], self.output / capture)
                logger.info(f'<a href="{escape(capture, quote=True)}">{escape(capture)}</a>', html=True)
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
        result = subprocess.run(["magick", "compare", "-metric", "AE", str(self.output / first),
                                 str(self.output / second), str(self.output / diff)],
                                capture_output=True, text=True, timeout=10)
        if result.returncode != 0:
            logger.info(f'<a href="{escape(diff, quote=True)}">Pixel difference</a>', html=True)
            raise AssertionError(f"{first} vs {second}: pixels differ (AE={result.stderr.strip()}); inspect {diff}")

    @keyword
    def image_dimensions_should_be(self, image, width: int, height: int):
        actual = subprocess.check_output(["magick", "identify", "-format", "%wx%h",
                                          str(self.output / image)], text=True, timeout=10).strip()
        if actual != f"{width}x{height}":
            raise AssertionError(f"{image}: {actual}, expected {width}x{height}")

    @keyword
    def save_journey_evidence(self):
        (self.output / "commands.json").write_text(json.dumps(self.trace, indent=2) + "\n")


def run_journey(directory, suite, output):
    import robot
    from robot.api import TestSuite
    suite = Path(suite)
    if not suite.is_file() or suite.suffix != ".robot" or TestSuite.from_file_system(str(suite)).test_count != 1:
        raise ValueError("Each .robot file must contain one journey with its own private game session")
    result = robot.run(str(suite), pythonpath=[str(Path(__file__).parent)],
                       variable=[f"CONTROL_DIR:{Path(directory).resolve()}", f"ARTIFACT_DIR:{Path(output).resolve()}"],
                       outputdir=str(output), console="quiet")
    if result:
        raise AssertionError(f"Journey failed; inspect {output / 'log.html'}")
