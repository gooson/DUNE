"""Watch preflight fixture and runner-order tests; no simulator is launched."""
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest import mock

ROOT = Path(__file__).resolve().parents[2]
HELPER = ROOT / 'scripts/lib/watch-simulator-preflight.py'
spec = importlib.util.spec_from_file_location('preflight', HELPER)
preflight = importlib.util.module_from_spec(spec)
spec.loader.exec_module(preflight)
ID = 'AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE'
DEST = 'platform=watchOS Simulator,id=' + ID
RUNTIME = 'com.apple.CoreSimulator.SimRuntime.watchOS-27-0'
NEW_RUNTIME = 'com.apple.CoreSimulator.SimRuntime.watchOS-27-2'
OLD_RUNTIME = 'com.apple.CoreSimulator.SimRuntime.watchOS-26-2'
ARTIFACT_NAME = 'Apple Watch Series 12 (46mm)'
ARTIFACT_OLD_ID = 'CD8A490F-5B2C-485E-8F11-CD8596FA4AAE'
ARTIFACT_NEW_ID = 'BB504ECE-7BB3-43DB-A862-11699B1BC8B5'


class PreflightTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.devices = {'devices': {RUNTIME: [{'udid': ID, 'name': 'Watch', 'isAvailable': True}]}}
        self.runtimes = {'runtimes': [{'identifier': RUNTIME, 'version': '27.0', 'isAvailable': True, 'bundlePath': self.temp.name}]}

    def test_valid_id_and_name(self):
        for dest in (DEST, 'platform=watchOS Simulator,name=Watch,OS=27.0'):
            self.assertEqual(preflight.validate(dest, self.devices, self.runtimes), DEST)

    def test_invalid_ids_and_unknown_device(self):
        for value in ('', 'oops', ID.replace('A', 'B')):
            with self.subTest(value=value), self.assertRaises(ValueError):
                preflight.validate('platform=watchOS Simulator,id=' + value, self.devices, self.runtimes)

    def test_missing_and_unavailable_runtime(self):
        with self.assertRaisesRegex(ValueError, 'runtime is missing'):
            preflight.validate(DEST, self.devices, {'runtimes': []})
        self.runtimes['runtimes'][0]['isAvailable'] = False
        with self.assertRaisesRegex(ValueError, 'runtime is missing'):
            preflight.validate(DEST, self.devices, self.runtimes)

    def test_missing_bundle(self):
        self.runtimes['runtimes'][0]['bundlePath'] += '/missing'
        with self.assertRaisesRegex(ValueError, 'bundle is missing'):
            preflight.validate(DEST, self.devices, self.runtimes)

    def test_unavailable_device(self):
        self.devices['devices'][RUNTIME][0]['isAvailable'] = False
        with self.assertRaisesRegex(ValueError, 'simulator is unavailable'):
            preflight.validate(DEST, self.devices, self.runtimes)

    def test_query_failure_and_timeout_are_not_retried(self):
        for error in (subprocess.CalledProcessError(1, 'simctl'), subprocess.TimeoutExpired('simctl', 30)):
            with mock.patch.object(preflight.subprocess, 'run', side_effect=error) as run, mock.patch('sys.argv', ['helper', DEST]):
                self.assertEqual(preflight.main(), 1)
                self.assertEqual(run.call_count, 1)

    def test_cli_with_mock_simctl(self):
        bindir = Path(self.temp.name) / 'bin'
        bindir.mkdir()
        fake = bindir / 'xcrun'
        fake.write_text('#!/usr/bin/env python3\nimport os,sys\nprint(os.environ["DEVICES" if sys.argv[3] == "devices" else "RUNTIMES"])\n')
        fake.chmod(0o755)
        for missing in (False, True):
            result = subprocess.run([sys.executable, str(HELPER), DEST], capture_output=True, text=True,
                env={**os.environ, 'PATH': str(bindir) + ':' + os.environ['PATH'],
                     'DEVICES': json.dumps(self.devices), 'RUNTIMES': json.dumps({'runtimes': []} if missing else self.runtimes)})
            self.assertEqual(result.returncode, int(missing), result.stderr)
            self.assertEqual(result.stdout.strip(), '' if missing else DEST)

    def select_fixture(self):
        # Mirrors the device availability in Actions run 44808746479:
        # an unavailable 27.0 source and a same-name usable 27.2 source.
        devices = {'devices': {
            RUNTIME: [{'udid': ARTIFACT_OLD_ID, 'name': ARTIFACT_NAME, 'isAvailable': False}],
            NEW_RUNTIME: [{'udid': ARTIFACT_NEW_ID, 'name': ARTIFACT_NAME, 'isAvailable': True}],
        }}
        runtimes = {'runtimes': [
            {'identifier': RUNTIME, 'version': '27.0', 'isAvailable': False,
             'bundlePath': self.temp.name},
            {'identifier': NEW_RUNTIME, 'version': '27.2', 'isAvailable': True,
             'bundlePath': self.temp.name},
        ]}
        return devices, runtimes

    def run_select_cli(self, *arguments, devices=None, runtimes=None, devices_json=None,
                       runtimes_json=None):
        bindir = Path(self.temp.name) / 'select-bin'
        bindir.mkdir(exist_ok=True)
        fake = bindir / 'xcrun'
        fake.write_text('''#!/usr/bin/env python3
import os, sys
print(os.environ['DEVICES_JSON' if sys.argv[3] == 'devices' else 'RUNTIMES_JSON'])
''')
        fake.chmod(0o755)
        return subprocess.run([sys.executable, str(HELPER), *arguments],
                              capture_output=True, text=True, timeout=10,
                              env={**os.environ, 'PATH': str(bindir) + ':' + os.environ['PATH'],
                                   'DEVICES_JSON': devices_json if devices_json is not None else json.dumps(devices),
                                   'RUNTIMES_JSON': runtimes_json if runtimes_json is not None else json.dumps(runtimes)})

    def test_select_uses_available_27_2_when_same_name_27_0_is_unavailable(self):
        devices, runtimes = self.select_fixture()
        result = self.run_select_cli('--select', ARTIFACT_NAME, 'latest',
                                     devices=devices, runtimes=runtimes)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.strip(), 'platform=watchOS Simulator,id=' + ARTIFACT_NEW_ID)

    def test_explicit_unavailable_27_0_never_falls_forward(self):
        devices, runtimes = self.select_fixture()
        for arguments in (
            ('platform=watchOS Simulator,id=' + ARTIFACT_OLD_ID,),
            ('platform=watchOS Simulator,name=' + ARTIFACT_NAME + ',OS=27.0',),
        ):
            with self.subTest(arguments=arguments):
                result = self.run_select_cli(*arguments, devices=devices, runtimes=runtimes)
                self.assertNotEqual(result.returncode, 0)
                self.assertEqual(result.stdout.strip(), '')

        default_select = self.run_select_cli('--select', ARTIFACT_NAME, '27.0',
                                             devices=devices, runtimes=runtimes)
        self.assertEqual(default_select.returncode, 0, default_select.stderr)
        self.assertEqual(default_select.stdout.strip(),
                         'platform=watchOS Simulator,id=' + ARTIFACT_NEW_ID)

    def test_available_device_needs_an_installed_runtime_and_requested_version_wins(self):
        devices, runtimes = self.select_fixture()
        devices['devices'][RUNTIME][0]['isAvailable'] = True
        self.assertEqual(preflight.select(ARTIFACT_NAME, '27.0', devices, runtimes),
                         f'platform=watchOS Simulator,id={ARTIFACT_NEW_ID}')
        runtimes['runtimes'][0]['isAvailable'] = True
        self.assertEqual(preflight.select(ARTIFACT_NAME, '27.0', devices, runtimes),
                         f'platform=watchOS Simulator,id={ARTIFACT_OLD_ID}')

    def test_select_fails_when_no_valid_clone_or_compatible_runtime(self):
        devices, runtimes = self.select_fixture()
        fixtures = [
            ({'devices': {NEW_RUNTIME: []}}, runtimes),
            ({'devices': {RUNTIME: devices['devices'][RUNTIME]}}, runtimes),
            (devices, {'runtimes': [dict(runtimes['runtimes'][0]),
                                    {**runtimes['runtimes'][1], 'isAvailable': False}]}),
            ({'devices': {OLD_RUNTIME: [{'udid': ARTIFACT_NEW_ID,
                                        'name': ARTIFACT_NAME, 'isAvailable': True}]}},
             {'runtimes': [{'identifier': OLD_RUNTIME, 'version': '26.2',
                            'isAvailable': True, 'bundlePath': self.temp.name}]}),
        ]
        for candidate_devices, candidate_runtimes in fixtures:
            with self.subTest(devices=candidate_devices, runtimes=candidate_runtimes):
                result = self.run_select_cli('--select', ARTIFACT_NAME, 'latest',
                                             devices=candidate_devices, runtimes=candidate_runtimes)
                self.assertNotEqual(result.returncode, 0)
                self.assertEqual(result.stdout.strip(), '')

    def test_select_rejects_broken_simctl_json(self):
        devices, runtimes = self.select_fixture()
        for bad_devices, bad_runtimes in (('{', json.dumps(runtimes)),
                                          (json.dumps(devices), '{')):
            with self.subTest(bad_devices=bad_devices, bad_runtimes=bad_runtimes):
                result = self.run_select_cli('--select', ARTIFACT_NAME, 'latest',
                                             devices_json=bad_devices, runtimes_json=bad_runtimes)
                self.assertNotEqual(result.returncode, 0)
                self.assertEqual(result.stdout.strip(), '')

    def test_watch_runner_stops_before_clone_or_boot_and_preserves_success(self):
        source = (ROOT / 'scripts/test-unit.sh').read_text()
        block = source[source.rindex('if [[ "$RUN_WATCH" -eq 1 ]]'):]
        for fail_at, build_first, expected in ((1, False, ''), (2, False, 'clone\n'),
                                               (0, False, 'clone\nboot\nsuite\n'),
                                               (0, True, 'clone\nsuite\n')):
            with self.subTest(fail_at=fail_at, build_first=build_first):
                bindir = Path(self.temp.name) / f'case-{fail_at}-{build_first}'
                bindir.mkdir()
                script = bindir / 'python3'
                script.write_text('''#!/bin/bash
count=0
[[ ! -f "$TRACE.count" ]] || count=$(cat "$TRACE.count")
count=$((count + 1))
echo "$count" > "$TRACE.count"
if [[ "$count" -eq "$FAIL_AT" ]]; then echo "preflight failure" >&2; exit 1; fi
echo "$2"
''')
                script.chmod(0o755)
                trace = bindir / 'trace'
                shell = '''set -euo pipefail
RUN_WATCH=1; DRY_RUN=0; ROOT_DIR=.; ONLY_TESTING=(); WATCH_ONLY_TESTING=()
WATCH_SIM_NAME=Watch; WATCH_SIM_OS=27.0; WATCH_SCHEME=Test; WATCH_LOG_FILE=log
DAILVE_WATCH_DESTINATION="$1"; WATCH_DESTINATION="$1"
WATCH_BUILD_BEFORE_BOOT="$BUILD_FIRST"
apply_worktree_destination() { echo clone >> "$TRACE"; echo "$1"; }
preboot_from_destination() { echo boot >> "$TRACE"; }
run_suite() { echo suite >> "$TRACE"; }
''' + block
                result = subprocess.run(['bash', '-c', shell, 'test', DEST], capture_output=True, text=True,
                                        env={**os.environ, 'PATH': str(bindir) + ':' + os.environ['PATH'],
                                             'TRACE': str(trace), 'FAIL_AT': str(fail_at), 'BUILD_FIRST': str(int(build_first))}, timeout=10)
                self.assertEqual(result.returncode, 1 if fail_at else 0, result.stderr)
                self.assertEqual(trace.read_text() if trace.exists() else '', expected)

    def test_default_watch_runner_selects_source_and_revalidates_clone(self):
        source = (ROOT / 'scripts/test-unit.sh').read_text()
        block = source[source.rindex('if [[ "$RUN_WATCH" -eq 1 ]]'):]
        bindir = Path(self.temp.name) / 'default-runner-bin'
        bindir.mkdir()
        fake_python = bindir / 'python3'
        fake_python.write_text('''#!/bin/bash
if [[ "$2" == "--select" ]]; then echo select >> "$TRACE"; else echo validate >> "$TRACE"; fi
echo "$EXPECTED_DEST"
''')
        fake_python.chmod(0o755)
        trace = bindir / 'trace'
        shell = '''set -euo pipefail
RUN_WATCH=1; DRY_RUN=0; ROOT_DIR=.; ONLY_TESTING=(); WATCH_ONLY_TESTING=()
WATCH_SIM_NAME='Apple Watch Series 12 (46mm)'; WATCH_SIM_OS=27.0; WATCH_SCHEME=Test; WATCH_LOG_FILE=log
DAILVE_WATCH_DESTINATION=''; WATCH_DESTINATION=''; WATCH_BUILD_BEFORE_BOOT=0
apply_worktree_destination() { echo clone >> "$TRACE"; echo "$1"; }
preboot_from_destination() { echo boot >> "$TRACE"; }
run_suite() { echo suite >> "$TRACE"; }
''' + block
        result = subprocess.run(['bash', '-c', shell], capture_output=True, text=True,
                                env={**os.environ, 'PATH': str(bindir) + ':' + os.environ['PATH'],
                                     'TRACE': str(trace), 'EXPECTED_DEST': DEST}, timeout=10)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(trace.read_text().splitlines(),
                         ['select', 'clone', 'validate', 'boot', 'suite'])


if __name__ == '__main__':
    unittest.main()
