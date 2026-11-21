#!/usr/bin/env python3
"""Resolve and validate a Watch destination without booting or repairing devices."""
import json
from pathlib import Path
import re
import subprocess
import sys


WATCH_RUNTIME_PREFIX = 'com.apple.CoreSimulator.SimRuntime.watchOS-'
UDID_PATTERN = r'[0-9A-Fa-f]{8}(?:-[0-9A-Fa-f]{4}){3}-[0-9A-Fa-f]{12}'


def validated_id(runtime_id, device, installed):
    runtime = installed.get(runtime_id)
    if not runtime_id.startswith(WATCH_RUNTIME_PREFIX) or not runtime or runtime.get('isAvailable') is not True:
        raise ValueError(f'Watch runtime is missing or unavailable: {runtime_id}')
    if device.get('isAvailable') is not True:
        raise ValueError('selected Watch simulator is unavailable')
    bundle = runtime.get('bundlePath')
    if not bundle or not Path(bundle).is_dir():
        raise ValueError(f'Watch runtime bundle is missing: {bundle!r}')
    udid = device.get('udid', '')
    if not re.fullmatch(UDID_PATTERN, udid):
        raise ValueError('selected device has an invalid destination ID')
    return udid


def validate(destination, devices, runtimes):
    fields = dict(part.strip().split('=', 1) for part in destination.split(',') if '=' in part)
    if fields.get('platform') != 'watchOS Simulator':
        raise ValueError('expected platform=watchOS Simulator')
    identifier = fields.get('id')
    if identifier is not None and not re.fullmatch(UDID_PATTERN, identifier):
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
    udid = validated_id(runtime_id, device, installed)
    return f'platform=watchOS Simulator,id={udid}'


def select(name, requested_os, devices, runtimes):
    installed = {r['identifier']: r for r in runtimes.get('runtimes', [])}
    candidates = []
    rejected = {}
    for runtime_id, entries in devices.get('devices', {}).items():
        if not runtime_id.startswith(WATCH_RUNTIME_PREFIX):
            continue
        runtime = installed.get(runtime_id, {})
        version_text = runtime.get('version') or ''
        if not re.fullmatch(r'\d+(?:\.\d+)*', version_text):
            rejected[runtime_id] = 'missing runtime or invalid version'
            continue
        version = tuple(map(int, version_text.split('.')))
        if version[0] < 27:
            continue
        for device in entries:
            device_name = device.get('name', '')
            if '-wt-' in device_name:
                continue
            try:
                udid = validated_id(runtime_id, device, installed)
            except ValueError as error:
                rejected[runtime_id] = device.get('availabilityError') or str(error)
                continue
            preferred_model = device_name == name
            preferred_version = preferred_model and version_text == requested_os
            candidates.append((preferred_version, preferred_model, version, device_name, udid))

    if not candidates:
        details = ', '.join(f'{key}: {value}' for key, value in sorted(rejected.items()))
        reason = f' ({details})' if details else ''
        raise ValueError(f'no available Watch simulator for {name}, watchOS {requested_os} '
                         f'or a compatible watchOS 27+ runtime{reason}')
    *_, selected_id = max(candidates)
    return f'platform=watchOS Simulator,id={selected_id}'


def main():
    try:
        def query(kind):
            result = subprocess.run(['xcrun', 'simctl', 'list', kind, '-j'],
                                    check=True, capture_output=True, text=True, timeout=30)
            return json.loads(result.stdout)
        args = sys.argv[1:]
        automatic = len(args) == 3 and args[0] == '--select'
        if not automatic and (len(args) != 1 or args[0] == '--select'):
            raise ValueError('usage: watch-simulator-preflight.py <destination> | --select <name> <OS>')
        devices = query('devices')
        runtimes = query('runtimes')
        if automatic:
            print(select(args[1], args[2], devices, runtimes))
        else:
            print(validate(args[0], devices, runtimes))
    except (ValueError, KeyError, IndexError, OSError, subprocess.SubprocessError) as error:
        print(f'Watch simulator preflight failed: {error}. No boot/test retry attempted.', file=sys.stderr)
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())
