"""Send commands to a debug game launched with HOLLIE_CONTROL_DIR."""

import argparse
import json
from pathlib import Path
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
