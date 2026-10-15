"""Local Robot keywords: one mailbox request per batched game action."""

from collections import Counter
import json
from pathlib import Path
import shutil
import subprocess

from robot.api import logger
from robot.api.deco import keyword, library
from pilot_support import Recorded_Client


@library(scope="SUITE", auto_keywords=False)
class Hollie:
    def __init__(self, source, output):
        self.output = Path(output)
        self.client = Recorded_Client(source, output)
        self.checks = Counter()

    def send(self, command, capture="", expected_error=""):
        if capture:
            if Path(capture).name != capture:
                raise ValueError("Captures must be plain filenames")
            command["capture"] = capture
        response = self.client.send(command)
        if response["error"] != expected_error:
            raise AssertionError(f"Command {command!r}: {response!r}")
        if capture:
            shutil.copyfile(response["capture"], self.output / capture)
            logger.info(f'<a href="{capture}">{capture}</a>', html=True)
        return response["state"]

    @keyword
    def reset_game(self, capture="", **options):
        return self.send({"op": "reset", **options}, capture)

    @keyword
    def advance_ticks(self, ticks: int, *keys, capture="", expected_error=""):
        command = {"op": "step", "frames": ticks}
        if keys:
            command["keys"] = list(keys)
        return self.send(command, capture, expected_error)

    @keyword
    def move_stick_for_ticks(self, ticks: int, left_x: float, left_y: float):
        return self.send({"op": "step", "frames": ticks,
                          "gamepads": [{"player": "Player_1", "axes": [left_x, left_y]}]})

    @keyword
    def observe_game(self):
        return self.send({"op": "observe"})

    @keyword
    def reset_should_fail(self, room, error):
        return self.send({"op": "reset", "room": room}, expected_error=error)

    @keyword
    def states_should_match(self, first, second):
        self.checks["equal_state"] += 1
        if first != second:
            raise AssertionError(f"States differ: {first!r} != {second!r}")

    @keyword
    def player_should_have_moved(self, first, second):
        self.checks["player_moved"] += 1
        if first["players"][0]["body"]["position"] == second["players"][0]["body"]["position"]:
            raise AssertionError("Player did not move")

    @keyword
    def frames_between_should_be(self, first, second, ticks: int):
        self.checks["frame_delta"] += 1
        actual = second["frame"] - first["frame"]
        if actual != ticks:
            raise AssertionError(f"Frame delta {actual}, expected {ticks}")

    @keyword
    def mounted_actor_should_be(self, state, actor: int):
        self.checks["field"] += 1
        actual = state["players"][0]["mounted"]
        if actual != actor:
            raise AssertionError(f"Mounted actor {actual}, expected {actor}")

    @keyword
    def images_should_match(self, first, second):
        self.checks["pixels"] += 1
        result = subprocess.run(["magick", "compare", "-metric", "AE", str(self.output / first),
                                 str(self.output / second), str(self.output / "replay-diff.png")],
                                capture_output=True, text=True, timeout=10)
        if result.returncode != 0:
            raise AssertionError(f"Replay pixels differ: {result.stderr.strip()}")

    @keyword
    def image_dimensions_should_be(self, image, width: int, height: int):
        self.checks["dimensions"] += 1
        actual = subprocess.check_output(["magick", "identify", "-format", "%wx%h",
                                          str(self.output / image)], text=True, timeout=10).strip()
        if actual != f"{width}x{height}":
            raise AssertionError(f"{image}: {actual}, expected {width}x{height}")

    @keyword
    def save_journey_evidence(self):
        self.client.save()
        (self.output / "checks.json").write_text(json.dumps(self.checks, indent=2) + "\n")
