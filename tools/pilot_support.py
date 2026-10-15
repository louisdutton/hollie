"""Opt-in runner comparison; the normal JSON runner remains independent."""

from collections import Counter
import json
from pathlib import Path
import time

from game_control import Control_Client, run_scenario


class Recorded_Client:
    def __init__(self, source, output, process=None):
        self.output = Path(output)
        self.trace = []
        self.timings = []
        source = Path(source)
        self.replay = json.loads(source.read_text()) if source.is_file() else None
        self.client = None if self.replay is not None else Control_Client(source, process)

    def send(self, command):
        started = time.perf_counter()
        if self.replay is None:
            response = self.client.send(command)
        else:
            index = len(self.trace)
            if index >= len(self.replay) or command != self.replay[index]["command"]:
                raise AssertionError(f"Replay command {index}: unexpected {command!r}")
            response = self.replay[index]["response"]
        self.timings.append({"op": command["op"], "capture": bool(command.get("capture")),
                             "seconds": time.perf_counter() - started})
        self.trace.append({"command": command, "response": response})
        return response

    def save(self):
        (self.output / "commands.json").write_text(json.dumps(self.trace, indent=2) + "\n")
        (self.output / "command-timings.json").write_text(json.dumps(self.timings, indent=2) + "\n")


def run_pilot(runner, source, scenario, output, process=None):
    started = time.perf_counter()
    output = Path(output)
    scenario = Path(scenario).resolve()
    if runner == "json":
        client = Recorded_Client(source, output, process)
        try:
            run_scenario(client, scenario, output)
        finally:
            client.save()
        data = json.loads(scenario.read_text())
        checks = Counter(check["kind"] for check in data["assertions"])
        checks.update(check.get("kind", "pixels") for check in data.get("image_assertions", []))
        (output / "checks.json").write_text(json.dumps(checks, indent=2) + "\n")
        execution_finished = time.perf_counter()
        phases = {"execution_seconds": execution_finished - started, "report_seconds": 0.0}
    else:
        import robot
        imported = time.perf_counter()
        result = robot.run(
            str(Path(__file__).parent / "robot" / f"{scenario.stem}.robot"),
            pythonpath=[str(Path(__file__).parent)],
            variable=[f"CONTROL_SOURCE:{Path(source).resolve()}", f"ARTIFACT_DIR:{output.resolve()}"],
            outputdir=str(output), log="NONE", report="NONE", console="quiet",
        )
        executed = time.perf_counter()
        from robot import rebot
        rebot(str(output / "output.xml"), outputdir=str(output), output=None)
        phases = {"import_seconds": imported - started, "execution_seconds": executed - imported,
                  "report_seconds": time.perf_counter() - executed, "robot_version": robot.__version__}
        if result:
            raise AssertionError(f"Robot journey failed; inspect {output / 'log.html'}")
    phases["total_seconds"] = time.perf_counter() - started
    (output / "runner-timings.json").write_text(json.dumps(phases, indent=2) + "\n")


if __name__ == "__main__":
    import argparse
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("runner", choices=["json", "robot"])
    parser.add_argument("source", type=Path)
    parser.add_argument("scenario", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    args.output.mkdir(parents=True)
    run_pilot(args.runner, args.source, args.scenario, args.output)
