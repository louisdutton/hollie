"""Control adapter invariants without starting a renderer or display."""

import json
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch
import robot

from robot_game import Hollie


class Robot_Journey_Tests(unittest.TestCase):
    def test_each_journey_has_fresh_control_and_no_implicit_reset(self):
        with tempfile.TemporaryDirectory() as directory, patch("robot_game.BuiltIn") as built_in, patch("robot_game.private_session") as session:
            built_in.return_value.get_variable_value.return_value = directory
            game = Hollie()
            game.start_private_game("unused")
            first_output = game.output
            game.client.send.assert_not_called()
            game.trace.append({"previous": "journey"})
            game.finish_journey()
            game.start_private_game("unused")
            self.assertNotEqual(game.output, first_output)
            self.assertEqual(game.trace, [])
            game.client.send.assert_not_called()
            game.finish_journey()
            self.assertEqual(session.return_value.__exit__.call_count, 2)

    def test_journey_teardown_closes_session_even_if_evidence_fails(self):
        with tempfile.TemporaryDirectory() as directory, patch("robot_game.Control_Client"), patch("robot_game.private_session") as session:
            game = Hollie(directory, directory)
            game.context = session()
            with patch.object(game, "save_journey_evidence", side_effect=OSError("Disk full")):
                with self.assertRaisesRegex(OSError, "Disk full"):
                    game.finish_journey()
            game_context = session.return_value
            self.assertEqual(game_context.__exit__.call_args.args[0], OSError)
            self.assertIsNone(game.context)

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
                "Test Teardown    Finish Journey\n"
                "*** Test Cases ***\n"
                "A failed command preserves evidence\n"
                "    Advance Ticks    30    S\n"
            )
            result = robot.run(str(suite), pythonpath=[str(Path(__file__).parent)],
                variable=[f"CONTROL_DIR:{output}", f"ARTIFACT_DIR:{output}"], outputdir=str(output), console="quiet")
            self.assertEqual(result, 1)
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
