"""Serial, opt-in JSON/Robot comparison on the existing private display launcher."""

from collections import Counter
import argparse
import hashlib
import json
from pathlib import Path
import platform
import re
import statistics
import subprocess
import sys
import tempfile
import time


def read(directory, name):
    return json.loads((directory / name).read_text())


def compare(first, second, scenario, check_pixels=True):
    data = json.loads(scenario.read_text())
    expected = [{**step["command"], **({"capture": step["capture"]} if "capture" in step else {})}
                for step in data["steps"]]
    traces = [read(directory, "commands.json") for directory in (first, second)]
    checks = Counter(check["kind"] for check in data["assertions"])
    checks.update(check.get("kind", "pixels") for check in data.get("image_assertions", []))
    for directory, trace in zip((first, second), traces):
        if [item["command"] for item in trace] != expected:
            raise AssertionError(f"Command trace differs from {scenario}: {directory}")
        if read(directory, "checks.json") != checks:
            raise AssertionError(f"Assertion coverage differs from {scenario}: {directory}")
    for index, (left, right) in enumerate(zip(*traces)):
        for field in ("state", "error"):
            if left["response"][field] != right["response"][field]:
                raise AssertionError(f"Response {index} {field} differs: {first}, {second}")
    if check_pixels:
        for command in expected:
            if "capture" in command:
                name = command["capture"]
                result = subprocess.run(["magick", "compare", "-metric", "AE", str(first / name),
                                         str(second / name), str(second / f"cross-runner-{name}")],
                                        capture_output=True, text=True, timeout=30)
                if result.returncode:
                    raise AssertionError(f"Cross-runner pixels differ: {name}: {result.stderr}")
    return {"commands": len(expected), "checks": dict(checks), "states_equal": True,
            "pixels_equal": check_pixels}


def verify_failures(source, scenario, output):
    """Prove that trace, state and pixel mismatches fail with retained evidence."""
    output.mkdir(parents=True, exist_ok=True)
    results = []
    for fault, message in (("command", "Replay command"), ("state", r"States? differ"),
                           ("pixels", "Replay pixels differ")):
        trace = json.loads(source.read_text())
        if fault == "command":
            trace[0]["command"]["seed"] = 43
        elif fault == "state":
            trace[0]["response"]["state"]["frame"] += 1
        else:
            moved = next(item for item in trace if item["command"].get("capture") == "moved.png")
            moved["response"]["capture"] = trace[0]["response"]["capture"]
        fixture = output / f"{fault}.json"
        fixture.write_text(json.dumps(trace))
        for runner in ("json", "robot"):
            directory = output / f"{fault}-{runner}"
            log = output / f"{fault}-{runner}.log"
            with log.open("w") as stream:
                completed = subprocess.run([sys.executable, str(Path(__file__).with_name("pilot_support.py")),
                                            runner, str(fixture), str(scenario), str(directory)],
                                           stdout=stream, stderr=subprocess.STDOUT, timeout=60)
            messages = log.read_text()
            if runner == "robot" and (directory / "output.xml").is_file():
                messages += (directory / "output.xml").read_text()
            if completed.returncode == 0 or not re.search(message, messages):
                raise AssertionError(f"Fault {fault} was not diagnosed by {runner}; inspect {log}")
            if not (directory / "commands.json").is_file():
                raise AssertionError(f"Missing failure transcript: {directory}")
            results.append({"fault": fault, "runner": runner, "diagnosed": True, "artifacts": str(directory)})
    (output / "results.json").write_text(json.dumps(results, indent=2) + "\n")
    return results


def compare_speed(run, args, repo, result):
    scenario = repo / "tools/scenarios/riding.json"
    profiles = ["realtime-720p", "uncapped-720p", "uncapped-360p"]
    for iteration in range(args.warmups + args.runs):
        pair = {}
        order = profiles[iteration % 3:] + profiles[:iteration % 3]
        for profile in order:
            command = [sys.executable, "tools/render_probe.py", "--executable", str(args.executable.resolve()),
                       "--gpu", "--scenario", str(scenario), "--pilot-runner", "json",
                       "--render-size", "640x360" if profile == "uncapped-360p" else "1280x720"]
            if profile == "realtime-720p":
                command.append("--realtime")
            pair[profile] = run(command, f"speed-{iteration}-{profile}", True)
            result["runs"][-1].update(mode="speed", scenario="riding", runner=profile,
                                       warmup=iteration < args.warmups)
        proof = compare(pair[profiles[0]], pair[profiles[1]], scenario)
        result["equivalence"].append({"comparison": "uncapping", "iteration": iteration, **proof})
        proof = compare(pair[profiles[1]], pair[profiles[2]], scenario, check_pixels=False)
        for command in read(pair[profiles[2]], "commands.json"):
            if "capture" in command["command"]:
                image = pair[profiles[2]] / command["command"]["capture"]
                size = subprocess.check_output(["magick", "identify", "-format", "%wx%h", str(image)],
                                               text=True, timeout=10).strip()
                if size != "640x360":
                    raise AssertionError(f"Incorrect reduced capture extent: {image}: {size}")
        result["equivalence"].append({"comparison": "resolution", "iteration": iteration, **proof})


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--executable", type=Path, required=True)
    parser.add_argument("--runs", type=int, default=3)
    parser.add_argument("--warmups", type=int, default=1)
    parser.add_argument("--replay-runs", type=int, default=7)
    parser.add_argument("--render-size", default="640x360")
    parser.add_argument("--speed-comparison", action="store_true", help="Compare riding at 60 Hz, uncapped 720p, and uncapped 360p")
    args = parser.parse_args()
    if args.runs < 1 or args.warmups < 1 or args.replay_runs < 1:
        parser.error("Runs and warmups must be positive")
    repo = Path(__file__).resolve().parent.parent
    output = Path(tempfile.mkdtemp(prefix="hollie-robot-benchmark-"))
    print(f"Benchmark artifacts: {output}", flush=True)
    executable = args.executable.resolve()
    result = {"environment": {"platform": platform.platform(), "python": sys.version,
                              "executable": str(executable), "build_mode": "debug",
                              "binary_sha256": hashlib.file_digest(executable.open("rb"), "sha256").hexdigest(),
                              "revision": subprocess.check_output(["git", "rev-parse", "HEAD"], text=True).strip()},
              "settings": vars(args) | {"executable": str(executable)}, "runs": [], "equivalence": []}
    sources = [repo / "devenv.lock", repo / "nix/automation.nix", repo / "tools/game_control.py",
               repo / "tools/render_probe.py", Path(__file__), repo / "tools/pilot_support.py",
               repo / "tools/robot_game.py", *sorted((repo / "tools/robot").glob("*.robot")),
               *sorted((repo / "tools/robot").glob("*.resource")),
               *(repo / "tools/scenarios" / f"{name}.json" for name in ("movement", "riding", "display"))]
    result["environment"]["source_sha256"] = {
        str(path.relative_to(repo)): hashlib.sha256(path.read_bytes()).hexdigest() for path in sources}
    (output / "pilot.patch").write_text(subprocess.check_output(["git", "diff", "HEAD"], text=True))

    def run(command, label, live):
        log = output / f"{label}.log"
        started = time.perf_counter()
        with log.open("w") as stream:
            completed = subprocess.run(command, cwd=repo, stdout=stream, stderr=subprocess.STDOUT, timeout=300)
        elapsed = time.perf_counter() - started
        if completed.returncode:
            raise RuntimeError(f"{label} failed ({completed.returncode}); inspect {log}")
        directory = (Path(next(line.removeprefix("Probe artifacts: ") for line in log.read_text().splitlines()
                               if line.startswith("Probe artifacts: "))) if live else Path(command[-1]))
        timings = read(directory, "command-timings.json")
        phases = read(directory, "runner-timings.json")
        row = {"label": label, "artifacts": str(directory), "wall_seconds": elapsed, **phases,
               "commands_seconds": sum(item["seconds"] for item in timings),
               "command_median_seconds": statistics.median(item["seconds"] for item in timings),
               "capture_commands_seconds": sum(item["seconds"] for item in timings if item["capture"]),
               "other_commands_seconds": sum(item["seconds"] for item in timings if not item["capture"])}
        if live:
            row.update(read(directory, "session-timings.json"))
            row["renderer"] = read(directory, "renderer.json")
        result["runs"].append(row)
        print(f"{label}: wall={elapsed:.3f}s runner={phases['total_seconds']:.3f}s commands={row['commands_seconds']:.3f}s", flush=True)
        return directory

    try:
        if args.speed_comparison:
            compare_speed(run, args, repo, result)
        for name in (() if args.speed_comparison else ("movement", "riding", "display")):
            scenario = repo / "tools" / "scenarios" / f"{name}.json"
            source = None
            for iteration in range(args.warmups + args.runs):
                pair = {}
                # Alternate order to reduce systematic cache/thermal bias.
                for runner in (("json", "robot") if iteration % 2 == 0 else ("robot", "json")):
                    command = [sys.executable, "tools/render_probe.py", "--executable", str(executable), "--gpu",
                               "--scenario", str(scenario), "--pilot-runner", runner]
                    if name == "display":
                        command += ["--windowed", "--gamescope", "--display-size", "3840x2160"]
                    else:
                        command += ["--render-size", args.render_size]
                    label = f"live-{name}-{iteration}-{runner}"
                    pair[runner] = run(command, label, True)
                    result["runs"][-1].update(mode="live", scenario=name, runner=runner,
                                               warmup=iteration < args.warmups)
                proof = compare(pair["json"], pair["robot"], scenario)
                result["equivalence"].append({"scenario": name, "iteration": iteration, **proof})
                source = source or pair["json"] / "commands.json"
            for iteration in range(args.warmups + args.replay_runs):
                pair = {}
                for runner in (("json", "robot") if iteration % 2 == 0 else ("robot", "json")):
                    label = f"recorded-{name}-{iteration}-{runner}"
                    pair[runner] = run([sys.executable, "tools/pilot_support.py", runner, str(source),
                                        str(scenario), str(output / label)], label, False)
                    result["runs"][-1].update(mode="recorded", scenario=name, runner=runner,
                                               warmup=iteration < args.warmups)
                compare(pair["json"], pair["robot"], scenario, check_pixels=False)
            if name == "movement":
                result["failure_checks"] = verify_failures(source, scenario, output / "failures")
        groups = {}
        for row in result["runs"]:
            if not row["warmup"]:
                groups.setdefault(f"{row['mode']}/{row['scenario']}/{row['runner']}", []).append(row)
        result["summary"] = {key: {metric: {"median": statistics.median(row[metric] for row in rows),
                                             "min": min(row[metric] for row in rows),
                                             "max": max(row[metric] for row in rows)}
                                    for metric in ("wall_seconds", "total_seconds", "commands_seconds",
                                                   "capture_commands_seconds", "other_commands_seconds",
                                                   "report_seconds", "command_median_seconds")}
                             for key, rows in groups.items()}
    finally:
        (output / "results.json").write_text(json.dumps(result, indent=2) + "\n")
    print(f"Results and equivalence evidence: {output / 'results.json'}", flush=True)


if __name__ == "__main__":
    main()
