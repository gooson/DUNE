#!/usr/bin/env python3
"""Check simulator isolation without booting or deleting any simulator."""

import importlib.util
import json
import os
import pathlib
import shutil
import subprocess
import tempfile
import threading
import time
import unittest
from concurrent.futures import ThreadPoolExecutor
from unittest import mock


SCRIPT = pathlib.Path(__file__).resolve().parents[1] / "lib/simulator-worktree.sh"
REGISTRY_SCRIPT = pathlib.Path(__file__).resolve().parents[1] / "lib/worktree-simulator-registry.py"
spec = importlib.util.spec_from_file_location("worktree_simulator_registry", REGISTRY_SCRIPT)
registry = importlib.util.module_from_spec(spec)
spec.loader.exec_module(registry)


class SimulatorWorktreeTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = pathlib.Path(self.temp.name)
        self.repo = self.root / "main"
        self.repo.mkdir()
        self.git(self.repo, "init", "-q")
        self.git(self.repo, "-c", "user.name=Test", "-c", "user.email=test@example.com",
                 "commit", "--allow-empty", "-qm", "initial")
        self.worktrees = [self.root / name / "Health" for name in ("first", "second")]
        for path in self.worktrees:
            self.git(self.repo, "worktree", "add", "--detach", str(path), "HEAD")
            helper = path / "scripts/lib/worktree-simulator-registry.py"
            helper.parent.mkdir(parents=True)
            shutil.copy2(REGISTRY_SCRIPT, helper)

    def git(self, cwd, *args):
        return subprocess.run(["git", *args], cwd=cwd, check=True, capture_output=True)

    def shell(self, cwd, command, check=True, env=None):
        return subprocess.run(
            ["bash", "-c", 'source "$1"; ' + command, "test", str(SCRIPT)],
            cwd=cwd, check=check, capture_output=True, text=True, env=env,
        )

    def test_same_basename_has_distinct_stable_device_names(self):
        command = '''
        _find_simulator_by_name() { printf '%s\\n' "$1"; }
        ensure_worktree_simulator AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE 'iPhone Test'
        '''
        first = self.shell(self.worktrees[0], command).stdout.strip()
        second = self.shell(self.worktrees[1], command).stdout.strip()
        self.assertNotEqual(first, second)
        self.assertEqual(first, self.shell(self.worktrees[0], command).stdout.strip())
        self.assertRegex(first, r"^iPhone Test-wt-Health-first-[0-9a-f]{12}$")

    def test_current_and_default_cleanup_never_use_name_pattern(self):
        root = self.worktrees[0]
        for mode in ("", "--current"):
            command = f'''
            _find_simulators_matching() {{ echo unsafe >&2; return 1; }}
            cleanup_worktree_simulators {mode}
            '''
            result = self.shell(root, command)
            self.assertIn("No recorded worktree simulators", result.stdout)
            self.assertNotIn("unsafe", result.stderr)

    def test_main_checkout_preserves_source_device(self):
        result = self.shell(self.repo,
                            "ensure_worktree_simulator AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE 'iPhone Test'")
        self.assertEqual(result.stdout.strip(), "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")

    def test_hash_failure_does_not_fall_back_to_shared_device(self):
        commands = [
            "ensure_worktree_simulator AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE 'iPhone Test'",
            "apply_worktree_destination 'id=AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE' 'iPhone Test' iOS",
            "cleanup_worktree_simulators --current",
        ]
        for command in commands:
            with self.subTest(command=command):
                result = self.shell(self.worktrees[0], "shasum() { return 1; }; " + command,
                                    check=False)
                self.assertNotEqual(result.returncode, 0)
                self.assertEqual(result.stdout, "")
                self.assertIn("Cannot compute worktree identity", result.stderr)

    def test_registry_deletes_only_recorded_matching_device(self):
        root = self.worktrees[0]
        udid = "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE"
        name = "iPhone Test" + registry.worktree_suffix(root)
        other = "11111111-2222-3333-4444-555555555555"
        state = {
            udid: {"udid": udid, "name": name, "state": "Booted"},
            other: {"udid": other, "name": "iPhone Default", "state": "Booted"},
        }

        def simctl(command, **_kwargs):
            action, target = command[2:4]
            if action == "shutdown":
                state[target]["state"] = "Shutdown"
            elif action == "delete":
                state.pop(target)
            return subprocess.CompletedProcess(command, 0)

        with mock.patch.object(registry, "devices", side_effect=lambda: state.copy()), \
                mock.patch.object(registry.subprocess, "run", side_effect=simctl) as run:
            registry.record(root, udid, name, set())
            self.assertEqual(registry.cleanup(root), 0)
        self.assertEqual(registry.read_registry(root), [])
        self.assertIn(other, state)
        self.assertEqual([call.args[0][2] for call in run.call_args_list],
                         ["shutdown", "delete"])

    def test_registry_preserves_name_mismatch(self):
        root = self.worktrees[0]
        udid = "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE"
        name = "iPhone Test" + registry.worktree_suffix(root)
        with mock.patch.object(registry, "devices", return_value={
                udid: {"udid": udid, "name": name, "state": "Shutdown"}}):
            registry.record(root, udid, name, set())
        with mock.patch.object(registry, "devices", return_value={
                udid: {"udid": udid, "name": "Reassigned", "state": "Shutdown"}}), \
                mock.patch.object(registry.subprocess, "run") as run:
            self.assertEqual(registry.cleanup(root), 1)
        run.assert_not_called()
        self.assertEqual(len(registry.read_registry(root)), 1)

    def test_preexisting_or_unverified_device_is_never_deleted(self):
        root = self.worktrees[0]
        udid = "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE"
        name = "iPhone Test" + registry.worktree_suffix(root)
        current = {udid: {"udid": udid, "name": name, "state": "Shutdown"}}
        with self.assertRaises(ValueError):
            registry.record(root, udid, name, {udid})
        registry.write_registry(root, [
            {"udid": udid, "name": name, "worktree": str(root.resolve())}])
        with mock.patch.object(registry, "devices", return_value=current), \
                mock.patch.object(registry.subprocess, "run") as run:
            self.assertEqual(registry.cleanup(root), 1)
        run.assert_not_called()
        self.assertEqual(len(registry.read_registry(root)), 1)

    def test_clone_records_ownership_and_owned_cleanup_removes_it(self):
        root = self.worktrees[0]
        bin_dir = self.root / "bin"
        bin_dir.mkdir()
        xcrun = bin_dir / "xcrun"
        xcrun.write_text('''#!/usr/bin/env python3
import json, os, pathlib, sys
path = pathlib.Path(os.environ["MOCK_SIMULATORS"])
state = json.loads(path.read_text())
args = sys.argv[2:]
if args[:2] == ["list", "devices"]:
    print(json.dumps({"devices": {"mock": list(state.values())}}))
elif args[0] == "clone":
    udid = "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE"
    state[udid] = {"udid": udid, "name": args[2], "state": "Shutdown"}
    print(udid)
elif args[0] == "delete":
    state.pop(args[1], None)
elif args[0] == "shutdown" and args[1] in state:
    state[args[1]]["state"] = "Shutdown"
path.write_text(json.dumps(state))
''')
        xcrun.chmod(0o755)
        state_path = self.root / "devices.json"
        source_udid = "11111111-2222-3333-4444-555555555555"
        state_path.write_text(json.dumps({source_udid: {
            "udid": source_udid, "name": "iPhone Source", "state": "Shutdown"}}))
        env = os.environ.copy()
        env["PATH"] = str(bin_dir) + os.pathsep + env["PATH"]
        env["MOCK_SIMULATORS"] = str(state_path)

        created = self.shell(root,
                             f"ensure_worktree_simulator {source_udid} 'iPhone Test'",
                             env=env).stdout.strip()
        self.assertEqual(created, "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")
        self.assertEqual(len(registry.read_registry(root)), 1)
        self.shell(root, "cleanup_worktree_simulators --owned", env=env)
        remaining = json.loads(state_path.read_text())
        self.assertEqual(set(remaining), {source_udid})

    def test_cleanup_keeps_failed_record_and_continues_to_next_device(self):
        root = self.worktrees[0]
        first = "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE"
        second = "11111111-2222-3333-4444-555555555555"
        suffix = registry.worktree_suffix(root)
        state = {
            first: {"udid": first, "name": "iPhone" + suffix, "state": "Shutdown"},
            second: {"udid": second, "name": "Watch" + suffix, "state": "Shutdown"},
        }
        with mock.patch.object(registry, "devices", side_effect=lambda: state.copy()):
            registry.record(root, first, state[first]["name"], set())
            registry.record(root, second, state[second]["name"], set())

        def simctl(command, **_kwargs):
            udid = command[3]
            if udid == first:
                raise subprocess.CalledProcessError(1, command)
            state.pop(udid)
            return subprocess.CompletedProcess(command, 0)

        with mock.patch.object(registry, "devices", side_effect=lambda: state.copy()), \
                mock.patch.object(registry.subprocess, "run", side_effect=simctl):
            self.assertEqual(registry.cleanup(root), 1)
        self.assertEqual([item["udid"] for item in registry.read_registry(root)], [first])
        self.assertEqual(set(state), {first})

    def test_cleanup_preserves_registry_when_device_listing_fails(self):
        root = self.worktrees[0]
        udid = "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE"
        name = "iPhone" + registry.worktree_suffix(root)
        with mock.patch.object(registry, "devices", return_value={
                udid: {"udid": udid, "name": name, "state": "Shutdown"}}):
            registry.record(root, udid, name, set())
        with mock.patch.object(registry, "devices", side_effect=OSError("simctl unavailable")):
            with self.assertRaises(OSError):
                registry.cleanup(root)
        self.assertEqual(len(registry.read_registry(root)), 1)

    def test_concurrent_clone_records_are_both_retained(self):
        root = self.worktrees[0]
        suffix = registry.worktree_suffix(root)
        records = [
            ("AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE", "iPhone" + suffix),
            ("11111111-2222-3333-4444-555555555555", "Watch" + suffix),
        ]
        state = {udid: {"udid": udid, "name": name, "state": "Shutdown"}
                 for udid, name in records}
        start = threading.Barrier(2)

        def write(item):
            start.wait()
            registry.record(root, item[0], item[1], set())

        def slow_devices():
            time.sleep(0.05)
            return state.copy()

        with mock.patch.object(registry, "devices", side_effect=slow_devices):
            with ThreadPoolExecutor(max_workers=2) as pool:
                list(pool.map(write, records))
        self.assertEqual({item["udid"] for item in registry.read_registry(root)},
                         {udid for udid, _ in records})

    def test_cleanup_keeps_record_when_delete_is_not_confirmed(self):
        root = self.worktrees[0]
        udid = "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE"
        name = "iPhone" + registry.worktree_suffix(root)
        current = {udid: {"udid": udid, "name": name, "state": "Shutdown"}}
        with mock.patch.object(registry, "devices", return_value=current):
            registry.record(root, udid, name, set())
        with mock.patch.object(registry, "devices", return_value=current), \
                mock.patch.object(registry.subprocess, "run", return_value=subprocess.CompletedProcess([], 0)):
            self.assertEqual(registry.cleanup(root), 1)
        self.assertEqual(len(registry.read_registry(root)), 1)

    def test_orphan_marker_falls_back_when_worktree_marker_path_is_blocked(self):
        root = self.worktrees[0]
        udid = "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE"
        name = "iPhone" + registry.worktree_suffix(root)
        local_dir, fallback_dir = registry.orphan_directories(root)
        local_dir.parent.mkdir(parents=True, exist_ok=True)
        local_dir.write_text("blocked")
        self.addCleanup(shutil.rmtree, fallback_dir, ignore_errors=True)
        registry.mark_orphan(root, udid, name)
        self.assertTrue((fallback_dir / f"{udid}.json").is_file())
        self.assertTrue(registry.is_orphan(root, udid))

    def test_failed_registration_reports_untracked_clone_when_rollback_fails(self):
        source = "11111111-2222-3333-4444-555555555555"
        created = "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE"
        command = f'''
        xcrun() {{
            case "$2" in
                list) printf '{{"devices":{{"mock":[{{"udid":"{source}","name":"Source","state":"Shutdown"}}]}}}}\\n' ;;
                shutdown) return 0 ;;
                clone) echo {created} ;;
                delete) return 1 ;;
            esac
        }}
        python3() {{
            if [[ "$1" == */worktree-simulator-registry.py &&
                  ( "$2" == record || "$2" == rollback-safe || "$2" == absent ) ]]; then
                return 1
            fi
            command python3 "$@"
        }}
        ensure_worktree_simulator {source} 'iPhone Test'
        '''
        result = self.shell(self.worktrees[0], command, check=False)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Untracked simulator", result.stderr)
        self.assertIn(created, result.stderr)
        self.assertTrue(registry.is_orphan(self.worktrees[0], created), result.stderr)
        with mock.patch.object(registry, "devices", return_value={created: {
                "udid": created, "name": "iPhone Test" + registry.worktree_suffix(self.worktrees[0]),
                "state": "Shutdown"}}):
            self.assertEqual(registry.cleanup(self.worktrees[0]), 1)
        reuse = self.shell(self.worktrees[0], f'''
        _find_simulator_by_name() {{ echo {created}; }}
        ensure_worktree_simulator {source} 'iPhone Test'
        ''', check=False)
        self.assertNotEqual(reuse.returncode, 0)
        self.assertIn("unresolved orphan marker", reuse.stderr)


if __name__ == "__main__":
    unittest.main()
