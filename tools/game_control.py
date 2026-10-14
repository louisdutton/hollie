"""Send commands to a debug game launched with HOLLIE_CONTROL_DIR."""

import argparse
import json
from pathlib import Path
import shutil
import subprocess
import time


class Control_Client:
    """Single-controller, sequential JSON mailbox with bounded waits."""

    def __init__(self, directory, process=None):
        self.directory = Path(directory)
        self.process = process
        self.response_path = self.directory / "response.json"

    def wait_for_response(self, request_id, timeout=30):
        deadline = time.monotonic() + timeout
        while time.monotonic() < deadline:
            try:
                response = json.loads(self.response_path.read_text())
                if response["id"] == request_id:
                    return response
            except FileNotFoundError:
                pass
            if self.process is not None and self.process.poll() is not None:
                raise RuntimeError(f"Game exited {self.process.returncode}; inspect game.log")
            time.sleep(0.02)
        raise TimeoutError(f"No response to command {request_id} in {self.directory}")

    def send(self, command):
        previous = json.loads(self.response_path.read_text())
        request_path = self.directory / "request.json"
        if request_path.exists():
            pending = json.loads(request_path.read_text())
            if pending["id"] > previous["id"]:
                raise RuntimeError("A command is still pending; wait for it before sending another")
        request_id = previous["id"] + 1
        temporary = self.directory / "request.json.tmp"
        temporary.write_text(json.dumps({**command, "id": request_id}, allow_nan=False))
        temporary.replace(request_path)
        return self.wait_for_response(request_id)


def run_scenario(client, path, output):
    scenario = json.loads(Path(path).read_text())
    saved = {}
    transcript = []
    try:
        for step in scenario["steps"]:
            # Waiting without a command must leave simulation state unchanged.
            if "wait_seconds" in step:
                time.sleep(step["wait_seconds"])
            command = step["command"]
            if "capture" in step:
                command = {**command, "capture": step["capture"]}
            response = client.send(command)
            transcript.append({"command": command, "response": response})
            if response["error"] != step.get("expect_error", ""):
                raise AssertionError(f"Unexpected command result: {response}")
            if "save_as" in step:
                saved[step["save_as"]] = response["state"]
            if "capture" in step:
                name = step["capture"]
                if Path(name).name != name:
                    raise ValueError("Scenario captures must be plain filenames")
                shutil.copyfile(response["capture"], output / name)
        for check in scenario["assertions"]:
            first = saved[check["first"]]
            second = saved.get(check.get("second"))
            kind = check["kind"]
            if kind == "positive_field":
                value = first
                for key in check["path"]:
                    value = value[key]
                if value <= 0:
                    raise AssertionError(f"Expected positive {check['path']}: {value!r}")
            elif kind == "field":
                value = first
                for key in check["path"]:
                    value = value[key]
                if value != check["value"]:
                    raise AssertionError(f"Unexpected {check['path']}: {value!r}")
            elif kind == "equal_field":
                left, right = first, second
                for key in check["path"]:
                    left, right = left[key], right[key]
                if left != right:
                    raise AssertionError(f"Field differs: {check['path']}")
            elif kind == "difference_field":
                left, right = first, second
                for key in check["path"]:
                    left = left[key]
                for key in check["second_path"]:
                    right = right[key]
                difference = left - right
                if abs(difference - check["value"]) > check.get("tolerance", 0.001):
                    raise AssertionError(f"Unexpected field difference: {difference!r}")
            elif kind == "range_field":
                value = first
                for key in check["path"]:
                    value = value[key]
                if not check["minimum"] <= value <= check["maximum"]:
                    raise AssertionError(f"Field outside expected range: {value!r}")
            elif kind == "equal_state":
                if first != second:
                    raise AssertionError(f"State differs: {check['first']} vs {check['second']}")
            elif kind == "player_moved":
                player = check.get("player", 0)
                before = first["players"][player]["body"]["position"]
                after = second["players"][player]["body"]["position"]
                if before == after:
                    raise AssertionError("Player did not move")
            elif kind == "frame_delta":
                if second["frame"] - first["frame"] != check["frames"]:
                    raise AssertionError("Incorrect simulation frame count")
            else:
                raise ValueError(f"Unknown assertion: {kind}")
        for check in scenario.get("image_assertions", []):
            result = subprocess.run(
                ["magick", "compare", "-metric", "AE", str(output / check["first"]),
                 str(output / check["second"]), str(output / "replay-diff.png")],
                capture_output=True, text=True, timeout=10,
            )
            if result.returncode != 0:
                raise AssertionError(f"Replay pixels differ: {result.stderr.strip()}")
        count = len(scenario["assertions"]) + len(scenario.get("image_assertions", []))
        print(f"Scenario passed: {scenario['name']} ({count} assertions)", flush=True)
    finally:
        (output / "scenario.json").write_text(json.dumps(transcript, indent=2) + "\n")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("directory", type=Path)
    parser.add_argument("command", help='JSON, e.g. {"op":"step","frames":30,"keys":["D"]}')
    args = parser.parse_args()
    response = Control_Client(args.directory).send(json.loads(args.command))
    print(json.dumps(response, indent=2))
    if response["error"]:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
