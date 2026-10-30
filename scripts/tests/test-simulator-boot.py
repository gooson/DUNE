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
    def run_with_large_device_list(self, device_id: str = "fixture-device") -> subprocess.CompletedProcess[str]:
        with tempfile.TemporaryDirectory() as directory:
            fake = Path(directory) / "xcrun"
            fake.write_text(
                "#!/usr/bin/env python3\n"
                "import os, sys\n"
                "command = sys.argv[2]\n"
                "if command == 'list' and sys.argv[3] == 'devices':\n"
                f"    print({device_id!r} + ' (Booted)', flush=True)\n"
                "    for _ in range(32):\n"
                "        os.write(1, b'other-device (Shutdown)\\n' * 4096)\n"
                "elif command == 'bootstatus':\n"
                "    sys.exit(0)\n"
            )
            fake.chmod(0o755)
            return subprocess.run(
                ["bash", "-c", 'set -euo pipefail; source "$1"; wait_for_simulator_boot fixture-device fixture',
                 "boot-test", str(HELPER)],
                env={**os.environ, "ROOT_DIR": str(ROOT),
                     "SIMULATOR_BOOT_TIMEOUT": "3", "SIMULATOR_BOOT_RETRIES": "0",
                     "PATH": directory + os.pathsep + os.environ["PATH"]},
                capture_output=True, text=True, timeout=10,
            )

    def test_present_device_is_not_rejected_when_listing_exceeds_pipe_buffer(self) -> None:
        result = self.run_with_large_device_list()
        self.assertEqual(result.returncode, 0, result.stdout[:800] + result.stderr[-800:])
        self.assertIn("bootstatus confirmed", result.stdout)

    def test_missing_device_is_still_rejected_for_large_listing(self) -> None:
        result = self.run_with_large_device_list(device_id="other-device")
        self.assertEqual(result.returncode, 1, result.stderr[-800:])
        self.assertIn("not found in device list", result.stdout)
        self.assertNotIn("bootstatus confirmed", result.stdout)

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
