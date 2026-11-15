#!/usr/bin/env python3
"""Resolve and validate a Watch destination without booting or repairing devices."""
import json
from pathlib import Path
import re
import subprocess
import sys


def validate(destination, devices, runtimes):
    fields = dict(part.strip().split('=', 1) for part in destination.split(',') if '=' in part)
    if fields.get('platform') != 'watchOS Simulator':
        raise ValueError('expected platform=watchOS Simulator')
    identifier = fields.get('id')
    if identifier is not None and not re.fullmatch(r'[0-9A-Fa-f]{8}(?:-[0-9A-Fa-f]{4}){3}-[0-9A-Fa-f]{12}', identifier):
        raise ValueError('empty or invalid destination ID')
    installed = {r['identifier']: r for r in runtimes.get('runtimes', [])}
    candidates = []
    for runtime_id, entries in devices.get('devices', {}).items():
        for device in entries:
            if identifier is not None:
                matches = device.get('udid', '').lower() == identifier.lower()
            else:
                matches = device.get('name') == fields.get('name') and fields.get('OS') in (None, 'latest', installed.get(runtime_id, {}).get('version'))
            if matches:
                candidates.append((runtime_id, device))
    if len(candidates) != 1:
        raise ValueError('destination must identify exactly one existing Watch simulator')
    runtime_id, device = candidates[0]
    runtime = installed.get(runtime_id)
    if not runtime_id.startswith('com.apple.CoreSimulator.SimRuntime.watchOS-') or not runtime or runtime.get('isAvailable') is not True:
        raise ValueError(f'Watch runtime is missing or unavailable: {runtime_id}')
    if device.get('isAvailable') is not True:
        raise ValueError('selected Watch simulator is unavailable')
    bundle = runtime.get('bundlePath')
    if not bundle or not Path(bundle).is_dir():
        raise ValueError(f'Watch runtime bundle is missing: {bundle!r}')
    udid = device.get('udid', '')
    if not re.fullmatch(r'[0-9A-Fa-f]{8}(?:-[0-9A-Fa-f]{4}){3}-[0-9A-Fa-f]{12}', udid):
        raise ValueError('selected device has an invalid destination ID')
    return f'platform=watchOS Simulator,id={udid}'


def main():
    try:
        def query(kind):
            result = subprocess.run(['xcrun', 'simctl', 'list', kind, '-j'],
                                    check=True, capture_output=True, text=True, timeout=30)
            return json.loads(result.stdout)
        print(validate(sys.argv[1], query('devices'), query('runtimes')))
    except (ValueError, KeyError, IndexError, OSError, subprocess.SubprocessError) as error:
        print(f'Watch simulator preflight failed: {error}. No boot/test retry attempted.', file=sys.stderr)
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())
