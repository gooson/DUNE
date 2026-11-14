"""Reject false-positive bootstatus and Xcode's null-runtime destinations."""

import copy
import importlib.util
from pathlib import Path
import unittest

SPEC = importlib.util.spec_from_file_location(
    "simulator_readiness", Path(__file__).resolve().parents[1] / "lib/verify-simulator-ready.py")
READY = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(READY)


class SimulatorReadinessTests(unittest.TestCase):
    def setUp(self):
        self.runtime = "com.apple.CoreSimulator.SimRuntime.watchOS-27-0"
        self.devices = {"devices": {self.runtime: [
            {"udid": "owned-watch", "state": "Booted", "isAvailable": True}]}}
        self.runtimes = {"runtimes": [
            {"identifier": self.runtime, "version": "27.0", "isAvailable": True}]}
        self.destinations = "Available destinations:\n{ platform:watchOS Simulator, arch:arm64, id:owned-watch, OS:27.0, name:Owned Watch }"

    def validate(self, **changes):
        args = dict(devices=self.devices, runtimes=self.runtimes, destinations=self.destinations,
                    udid="owned-watch", platform="watchOS")
        return READY.validate(**(args | changes))

    def test_booted_device_requires_matching_xcode_os_and_architecture(self):
        self.assertEqual(self.validate()["architecture"], "arm64")

    def test_shutdown_after_successful_bootstatus_is_rejected(self):
        self.devices["devices"][self.runtime][0]["state"] = "Shutdown"
        with self.assertRaisesRegex(ValueError, "not booted"):
            self.validate()

    def test_missing_or_unavailable_runtime_is_rejected(self):
        for runtime in ([], [{"identifier": self.runtime, "version": "27.0", "isAvailable": False}]):
            with self.subTest(runtime=runtime), self.assertRaisesRegex(ValueError, "runtime is unavailable"):
                self.validate(runtimes={"runtimes": runtime})

    def test_null_or_mismatched_xcode_version_is_rejected(self):
        for version in ("(null)", "N/A", "27.2"):
            with self.subTest(version=version), self.assertRaisesRegex(ValueError, "usable"):
                self.validate(destinations=self.destinations.replace("OS:27.0", "OS:" + version))

    def test_missing_architecture_is_rejected(self):
        with self.assertRaisesRegex(ValueError, "usable"):
            self.validate(destinations=self.destinations.replace("arch:arm64, ", ""))

    def test_ineligible_destination_cannot_satisfy_readiness(self):
        with self.assertRaisesRegex(ValueError, "usable"):
            self.validate(destinations="Available destinations:\nIneligible destinations:\n" + self.destinations)

    def test_duplicate_id_or_wrong_platform_cannot_satisfy_readiness(self):
        duplicate = copy.deepcopy(self.devices)
        duplicate["devices"][self.runtime] *= 2
        with self.assertRaisesRegex(ValueError, "exactly one"):
            self.validate(devices=duplicate)
        with self.assertRaisesRegex(ValueError, "not for iOS"):
            self.validate(platform="iOS")


if __name__ == "__main__":
    unittest.main()
