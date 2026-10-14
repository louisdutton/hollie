"""Cache invalidation and failed-build regression tests; never launches the game."""

import json
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

import build_debug


class Debug_Cache_Tests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.repo = Path(self.temporary.name)
        (self.repo / "hollie").mkdir()
        (self.repo / "hollie/main.odin").write_text("original")
        (self.repo / "tools").mkdir()
        self.script = self.repo / "tools/build_debug.py"
        self.script.write_text("builder")
        for name in ("devenv.nix", "devenv.yaml", "devenv.lock"):
            (self.repo / name).write_text(name)
        self.cache = self.repo / "cache"
        self.cache.mkdir()
        self.addCleanup(patch.stopall)
        patch.object(build_debug, "__file__", str(self.script)).start()

    def publish(self):
        executable = self.cache / "hollie"
        executable.write_bytes(b"previous executable")
        executable.chmod(0o755)
        (self.cache / "manifest.json").write_text(json.dumps({
            "source": build_debug.fingerprint(self.repo, "compiler:raylib"),
            "executable": build_debug.hashlib.sha256(executable.read_bytes()).hexdigest(),
        }))

    def current(self, toolchain="compiler:raylib"):
        return build_debug.is_current(self.cache, build_debug.fingerprint(self.repo, toolchain))

    def test_source_addition_deletion_and_rename_invalidate(self):
        self.publish()
        self.assertTrue(self.current())
        source = self.repo / "hollie/extra.odin"
        source.write_text("extra")
        self.assertFalse(self.current())
        self.publish()
        renamed = source.with_name("renamed.odin")
        source.rename(renamed)
        self.assertFalse(self.current())
        self.publish()
        renamed.unlink()
        self.assertFalse(self.current())

    def test_content_and_toolchain_changes_invalidate(self):
        self.publish()
        self.assertFalse(self.current("new compiler:raylib"))
        (self.repo / "hollie/main.odin").write_text("changed")
        self.assertFalse(self.current())

    def test_missing_corrupt_or_non_executable_output_invalidates(self):
        self.publish()
        executable = self.cache / "hollie"
        executable.chmod(0o644)
        self.assertFalse(self.current())
        executable.chmod(0o755)
        executable.write_bytes(b"corrupt")
        self.assertFalse(self.current())
        executable.unlink()
        self.assertFalse(self.current())
        (self.cache / "manifest.json").write_text("invalid json")
        self.assertFalse(self.current())

    def test_failed_build_keeps_previous_executable_and_manifest(self):
        self.publish()
        old_manifest = (self.cache / "manifest.json").read_bytes()
        (self.repo / "hollie/main.odin").write_text("changed")
        with patch("sys.argv", ["builder", "--cache", str(self.cache), "--toolchain", "compiler:raylib"]), patch.object(
            build_debug.subprocess, "run", return_value=subprocess.CompletedProcess([], 1, "", "compile error")
        ):
            with self.assertRaises(subprocess.CalledProcessError):
                build_debug.main()
        self.assertEqual((self.cache / "hollie").read_bytes(), b"previous executable")
        self.assertEqual((self.cache / "manifest.json").read_bytes(), old_manifest)
        self.assertFalse(self.current())


if __name__ == "__main__":
    unittest.main()
