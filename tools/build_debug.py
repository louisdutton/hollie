"""Content-checked debug build cache for the devenv task status protocol."""

import argparse
import fcntl
import hashlib
import json
import os
from pathlib import Path
import subprocess
import tempfile


def fingerprint(repo, toolchain):
    digest = hashlib.sha256(toolchain.encode())
    # Include names as well as bytes so additions, deletions and renames invalidate.
    sources = list((repo / "hollie").rglob("*")) + [
        repo / "devenv.nix", repo / "devenv.yaml", repo / "devenv.lock",
        Path(__file__).resolve(),
    ]
    for source in sorted(path for path in sources if path.is_file()):
        digest.update(str(source.relative_to(repo)).encode() + b"\0")
        digest.update(hashlib.sha256(source.read_bytes()).digest())
    return digest.hexdigest()


def is_current(cache, source_hash):
    try:
        manifest = json.loads((cache / "manifest.json").read_text())
        executable = cache / "hollie"
        return (
            manifest["source"] == source_hash
            and os.access(executable, os.X_OK)
            and manifest["executable"] == hashlib.sha256(executable.read_bytes()).hexdigest()
        )
    except (OSError, ValueError, KeyError, TypeError):
        return False


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--cache", type=Path, required=True)
    parser.add_argument("--toolchain", required=True)
    parser.add_argument("--status", action="store_true")
    args = parser.parse_args()
    repo = Path(__file__).resolve().parent.parent
    if args.status:
        return 0 if is_current(args.cache, fingerprint(repo, args.toolchain)) else 1
    args.cache.mkdir(parents=True, exist_ok=True)
    # Separate devenv invocations can request the same build concurrently.
    with (args.cache / "build.lock").open("w") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        source_hash = fingerprint(repo, args.toolchain)
        if is_current(args.cache, source_hash):
            return 0
        with tempfile.TemporaryDirectory(dir=args.cache) as temporary:
            executable = Path(temporary) / "hollie"
            build = subprocess.run(
                ["odin", "build", "hollie", "-debug", f"-out:{executable}"],
                cwd=repo, capture_output=True, text=True, timeout=180,
            )
            log = build.stdout + build.stderr
            (args.cache / "build.log").write_text(log)
            print(log, end="", flush=True)
            build.check_returncode()
            if fingerprint(repo, args.toolchain) != source_hash:
                raise RuntimeError("Sources changed during debug build; retry the task")
            manifest = Path(temporary) / "manifest.json"
            manifest.write_text(json.dumps({
                "source": source_hash,
                "executable": hashlib.sha256(executable.read_bytes()).hexdigest(),
            }))
            executable.replace(args.cache / "hollie")
            manifest.replace(args.cache / "manifest.json")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
