"""Exercise boot deadlines with a fake simctl; no simulator services are used."""

from pathlib import Path
import os
import subprocess
import tempfile
import time
import unittest


ROOT = Path(__file__).resolve().parents[2]
HELPER = ROOT / "scripts/lib/simulator-boot.sh"


class SimulatorBootTests(unittest.TestCase):
    def test_stalled_bootstatus_cannot_restart_the_attempt_budget(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            fake = Path(directory) / "xcrun"
            fake.write_text("#!/bin/sh\ncase \"$2\" in\n"
                            "boot) exit 0 ;;\nbootstatus) exec sleep 20 ;;\n"
                            "list) echo 'fixture-device (Booted)' ;;\nesac\n")
            fake.chmod(0o755)
            started = time.monotonic()
            result = subprocess.run(
                ["bash", "-c", 'source "$1"; _try_boot fixture-device fixture 1',
                 "boot-test", str(HELPER)],
                env={**os.environ, "ROOT_DIR": str(ROOT),
                     "PATH": directory + os.pathsep + os.environ["PATH"]},
                capture_output=True, text=True, timeout=10,
            )
            self.assertEqual(result.returncode, 124, result.stderr)
            self.assertLess(time.monotonic() - started, 8)
            self.assertNotIn("simulator booted", result.stdout)


if __name__ == "__main__":
    unittest.main()
