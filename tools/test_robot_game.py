"""Control adapter invariants without starting a renderer or display."""

import json
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

from robot_game import Hollie, run_journey


class Robot_Journey_Tests(unittest.TestCase):
    def test_multiple_journeys_require_separate_sessions(self):
        with tempfile.TemporaryDirectory() as directory, patch("robot_game.Control_Client") as client:
            output = Path(directory)
            suite = output / "multiple.robot"
            suite.write_text("*** Test Cases ***\nFirst\n    No Operation\nSecond\n    No Operation\n")
            with self.assertRaisesRegex(ValueError, "one journey"):
                run_journey(output, suite, output)
            client.assert_not_called()

    def test_simultaneous_players_use_one_complete_snapshot(self):
        with tempfile.TemporaryDirectory() as directory, patch("robot_game.Control_Client") as client:
            client.return_value.send.return_value = {"state": {}, "error": ""}
            game = Hollie(directory, directory)
            pads = [{"player": "Player_1", "axes": [0, 1]},
                    {"player": "Player_2", "axes": [0, 0.5]}]
            game.advance_ticks(30, gamepads=pads)
            client.return_value.send.assert_called_once_with({"op": "step", "frames": 30, "gamepads": pads})
            game.advance_ticks(1)
            self.assertEqual(client.return_value.send.call_args.args[0], {"op": "step", "frames": 1})

    def test_protocol_errors_are_checked_by_the_game(self):
        with tempfile.TemporaryDirectory() as directory, patch("robot_game.Control_Client") as client:
            client.return_value.send.return_value = {"state": {"frame": 0}, "error": "invalid input state"}
            game = Hollie(directory, directory)
            self.assertEqual(game.move_stick_for_ticks(1, 0, 2, expected_error="invalid input state"), {"frame": 0})
            self.assertEqual(client.return_value.send.call_args.args[0]["gamepads"][0]["axes"], [0, 2])
            with self.assertRaisesRegex(AssertionError, "invalid input state"):
                game.move_stick_for_ticks(1, 0, 2)

    def test_robot_failure_keeps_transcript_and_reports(self):
        with tempfile.TemporaryDirectory() as directory, patch("robot_game.Control_Client") as client:
            output = Path(directory)
            client.return_value.send.side_effect = TimeoutError("Game stopped responding")
            suite = output / "failure.robot"
            suite.write_text(
                "*** Settings ***\n"
                "Library    robot_game.Hollie    ${CONTROL_DIR}    ${ARTIFACT_DIR}\n"
                "Test Teardown    Save Journey Evidence\n"
                "*** Test Cases ***\n"
                "A failed command preserves evidence\n"
                "    Advance Ticks    30    S\n"
            )
            with self.assertRaisesRegex(AssertionError, "Journey failed"):
                run_journey(output, suite, output)
            trace = json.loads((output / "commands.json").read_text())
            self.assertEqual(trace[0]["command"], {"op": "step", "frames": 30, "keys": ["S"]})
            self.assertEqual(trace[0]["error"], "Game stopped responding")
            self.assertGreaterEqual(trace[0]["seconds"], 0)
            self.assertIn("Game stopped responding", (output / "output.xml").read_text())
            self.assertTrue((output / "log.html").is_file())
            self.assertTrue((output / "report.html").is_file())

    def test_pixel_mismatch_keeps_a_named_diff(self):
        with tempfile.TemporaryDirectory() as directory, patch("robot_game.Control_Client"):
            output = Path(directory)
            subprocess.run(["magick", "-size", "8x8", "xc:black", str(output / "before.png")], check=True)
            subprocess.run(["magick", "-size", "8x8", "xc:white", str(output / "after.png")], check=True)
            with self.assertRaisesRegex(AssertionError, "pixels differ"):
                Hollie(output, output).images_should_match("before.png", "after.png")
            self.assertTrue((output / "diff-before-after.png").is_file())
