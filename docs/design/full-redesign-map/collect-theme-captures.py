#!/usr/bin/env python3
"""Collect named four-tab theme screenshots without changing the default actual map."""

from __future__ import annotations

import argparse
from collections.abc import Iterable
from datetime import datetime
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile


HERE = Path(__file__).resolve().parent
DESTINATION = HERE / "actual"
DEVICES = ("regular", "ipad", "duo", "duo-open")
THEMES = {
    "Desert": "dune",
    "Ocean": "ocean",
    "Forest": "forest",
    "Sakura": "sakura",
    "Arctic": "arctic",
    "Solar": "solar",
    "Contour": "contour",
    "Water Lilies": "water-lilies",
}
SCREENS = {"Today": "T03", "Activity": "A01", "Wellness": "H01", "Life": "L01"}
EXPORT_SUFFIX = re.compile(r"_\d+_[0-9a-fA-F-]{36}$")
THEME_MATRIX_NAME = re.compile(r"^(Desert|Ocean|Forest|Sakura|Arctic|Solar|Contour|Water Lilies) (Light|Dark) (Today|Activity|Wellness|Life)$")
WATER_LILIES_NAME = re.compile(r"^Water Lilies (Today|Activity|Wellness|Life) (Light|Dark)$")


class CaptureError(Exception):
    """An input result bundle or destination cannot be collected safely."""


def normalized_attachment_name(value: str) -> str:
    name = Path(value).name
    if name.lower().endswith(".png"):
        name = name[:-4]
    return EXPORT_SUFFIX.sub("", name).strip()


def classify_attachment(value: str) -> tuple[str, str, str] | None:
    """Return theme, appearance, screen ID for the named root screenshots."""
    name = normalized_attachment_name(value)
    match = THEME_MATRIX_NAME.fullmatch(name)
    if match:
        theme_name, appearance, screen_name = match.groups()
    else:
        match = WATER_LILIES_NAME.fullmatch(name)
        if not match:
            return None
        screen_name, appearance = match.groups()
        theme_name = "Water Lilies"
    return THEMES[theme_name], appearance.lower(), SCREENS[screen_name]


def run_json(command: list[str]) -> dict | list:
    try:
        result = subprocess.run(command, check=True, capture_output=True, text=True)
    except FileNotFoundError as error:
        raise CaptureError(f"Required command not found: {command[0]}") from error
    except subprocess.CalledProcessError as error:
        detail = error.stderr.strip() or error.stdout.strip() or str(error)
        raise CaptureError(f"Command failed: {' '.join(command)}\n{detail}") from error
    try:
        return json.loads(result.stdout)
    except json.JSONDecodeError as error:
        raise CaptureError(f"Command returned invalid JSON: {' '.join(command)}") from error


def device_metadata(result_path: Path, device_kind: str) -> dict:
    try:
        summary = run_json([
            "xcrun", "xcresulttool", "get", "test-results", "summary",
            "--path", str(result_path), "--format", "json",
        ])
        candidates = [
            item.get("device", {})
            for item in summary.get("devicesAndConfigurations", [])
            if isinstance(item, dict)
            and item.get("device", {}).get("platform") in {"iOS Simulator", "watchOS Simulator"}
        ]
        selected = candidates[0] if candidates else {}
    except CaptureError:
        selected = {}
    if not selected.get("identifier"):
        # Some Xcode installations cannot write xcresulttool's temporary
        # TestReport, or omit the destination in the summary. The legacy
        # invocation record still carries the simulator identifier.
        invocation = run_json([
            "xcrun", "xcresulttool", "get", "object", "--legacy",
            "--path", str(result_path), "--format", "json",
        ])
        actions = invocation.get("actions", {}).get("_values", [])
        destination = actions[0].get("runDestination", {}) if actions else {}
        device = destination.get("targetDeviceRecord", {})
        platform = device.get("platformRecord", {}).get("userDescription", {}).get("_value")
        selected = {
            "platform": platform,
            "modelName": device.get("modelName", {}).get("_value"),
            "identifier": device.get("identifier", {}).get("_value"),
        }
    if not selected.get("identifier"):
        raise CaptureError(f"Could not determine simulator identifier from {result_path}")
    return {
        "kind": device_kind,
        "platform": selected.get("platform"),
        "model_name": selected.get("modelName"),
        "identifier": selected.get("identifier") or selected.get("udid"),
    }


def export_result(result_path: Path, export_dir: Path, preexported: Path | None = None) -> list[dict]:
    if preexported is not None:
        export_dir = preexported
    else:
        try:
            subprocess.run(
                ["xcrun", "xcresulttool", "export", "attachments", "--path", str(result_path),
                 "--output-path", str(export_dir), "--filter", "*.png"],
                check=True, capture_output=True, text=True,
            )
        except subprocess.CalledProcessError:
            # Xcode 27 can fail while creating its internal TestReport. The
            # legacy object tree exposes each attachment without that service.
            shutil.rmtree(export_dir, ignore_errors=True)
            export_legacy_attachments(result_path, export_dir)
    manifest_path = export_dir / "manifest.json"
    try:
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        raise CaptureError(f"Missing or invalid attachment manifest: {manifest_path}") from error
    if not isinstance(manifest, list):
        raise CaptureError(f"Expected a list in attachment manifest: {manifest_path}")
    return manifest


def export_legacy_attachments(result_path: Path, export_dir: Path) -> None:
    def get_object(identifier: str | None = None) -> dict:
        command = ["xcrun", "xcresulttool", "get", "object", "--legacy", "--path", str(result_path), "--format", "json"]
        if identifier is not None:
            command += ["--id", identifier]
        return run_json(command)

    def value(item: dict, key: str) -> str | None:
        return item.get(key, {}).get("_value")

    root = get_object()
    actions = root.get("actions", {}).get("_values", [])
    if not actions:
        raise CaptureError("Legacy result bundle has no test action")
    tests_id = actions[0].get("actionResult", {}).get("testsRef", {}).get("id", {}).get("_value")
    if not tests_id:
        raise CaptureError("Legacy result bundle has no tests reference")
    plan = get_object(tests_id)
    metadata: list[dict] = []

    def find_metadata(node: object) -> None:
        if isinstance(node, dict):
            if node.get("_type", {}).get("_name") == "ActionTestMetadata":
                metadata.append(node)
            else:
                for child in node.values():
                    find_metadata(child)
        elif isinstance(node, list):
            for child in node:
                find_metadata(child)

    find_metadata(plan)
    export_dir.mkdir(parents=True)
    manifest = []
    for test in metadata:
        summary_id = test.get("summaryRef", {}).get("id", {}).get("_value")
        if not summary_id:
            continue
        summary = get_object(summary_id)
        attachments: list[dict] = []

        def find_attachments(node: object) -> None:
            if isinstance(node, dict):
                if node.get("_type", {}).get("_name") == "ActionTestAttachment":
                    if value(node, "uniformTypeIdentifier") != "public.png":
                        return
                    payload_id = node.get("payloadRef", {}).get("id", {}).get("_value")
                    filename = value(node, "filename")
                    if not payload_id or not filename:
                        return
                    exported_name = f'{value(node, "uuid") or len(attachments)}.png'
                    subprocess.run(
                        ["xcrun", "xcresulttool", "export", "object", "--legacy", "--path", str(result_path),
                         "--id", payload_id, "--type", "file", "--output-path", str(export_dir / exported_name)],
                        check=True, capture_output=True, text=True,
                    )
                    stamp = value(node, "timestamp")
                    attachments.append({
                        "suggestedHumanReadableName": filename,
                        "exportedFileName": exported_name,
                        "timestamp": datetime.fromisoformat(stamp).timestamp() if stamp else None,
                        "isAssociatedWithFailure": False,
                    })
                else:
                    for child in node.values():
                        find_attachments(child)
            elif isinstance(node, list):
                for child in node:
                    find_attachments(child)

        find_attachments(summary)
        manifest.append({"testIdentifier": value(test, "identifier"), "attachments": attachments})
    (export_dir / "manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def git_source_metadata(revision_override: str | None, dirty_override: str | None) -> tuple[str, bool]:
    try:
        revision = subprocess.run(
            ["git", "rev-parse", "HEAD"], cwd=HERE.parents[2], check=True,
            capture_output=True, text=True,
        ).stdout.strip()
        dirty = bool(subprocess.run(
            ["git", "status", "--porcelain", "--untracked-files=normal"], cwd=HERE.parents[2],
            check=True, capture_output=True, text=True,
        ).stdout.strip())
    except (OSError, subprocess.CalledProcessError) as error:
        raise CaptureError(f"Could not read source revision from Git: {error}") from error
    if revision_override:
        revision = revision_override
    if dirty_override is not None:
        dirty = dirty_override == "dirty"
    return revision, dirty


def timestamp_order(value: object) -> float | str:
    try:
        return float(value or 0)
    except (TypeError, ValueError):
        return str(value or "")


def gather_captures(result_paths: Iterable[Path], device_kind: str,
                    attachments_dir: Path | None = None) -> tuple[dict, dict, Path]:
    """Export result bundles into temporary folders and return captures/device data."""
    selected: dict[str, dict] = {}
    device = None
    result_paths = list(result_paths)
    if attachments_dir is not None and len(result_paths) != 1:
        raise CaptureError("--attachments-dir requires exactly one result bundle")
    staging = Path(tempfile.mkdtemp(prefix="dune-theme-captures-", dir="/private/tmp"))
    staging.chmod(0o755)  # xcresulttool's helper must be able to traverse this directory.
    try:
        for result_index, result_path in enumerate(result_paths):
            if not result_path.exists():
                raise CaptureError(f"Result bundle does not exist: {result_path}")
            if result_path.suffix != ".xcresult":
                raise CaptureError(f"Expected an .xcresult bundle: {result_path}")
            result_device = device_metadata(result_path, device_kind)
            if device is None:
                device = result_device
            elif result_device.get("identifier") and device.get("identifier") and result_device["identifier"] != device["identifier"]:
                raise CaptureError("All result bundles must come from the same simulator/device identifier")

            export_dir = attachments_dir if attachments_dir is not None else staging / str(result_index)
            manifest = export_result(result_path, export_dir, attachments_dir)
            for test in manifest:
                if not isinstance(test, dict):
                    continue
                for attachment in test.get("attachments", []):
                    if not isinstance(attachment, dict):
                        continue
                    attachment_name = attachment.get("suggestedHumanReadableName", "")
                    classified = classify_attachment(attachment_name)
                    if classified is None or attachment.get("isAssociatedWithFailure", False):
                        continue
                    theme, appearance, screen_id = classified
                    exported_name = attachment.get("exportedFileName")
                    exported_path = export_dir / str(exported_name)
                    if not exported_name or not exported_path.is_file():
                        raise CaptureError(f"Manifest export missing for attachment: {attachment_name}")
                    key = f"{theme}/{appearance}/{screen_id}"
                    record = {
                        "theme": theme,
                        "appearance": appearance,
                        "screen_id": screen_id,
                        "file": f"{theme}/{appearance}/{screen_id}.png",
                        "attachment_name": attachment_name,
                        "test_identifier": test.get("testIdentifier"),
                        "timestamp": attachment.get("timestamp"),
                        "result_bundle": str(result_path.resolve()),
                        "_exported_path": exported_path,
                    }
                    current = selected.get(key)
                    if current is None or timestamp_order(record["timestamp"]) > timestamp_order(current["timestamp"]):
                        selected[key] = record
        if not selected:
            raise CaptureError("No successful named 4-tab theme root screenshots were found")
        assert device is not None
        return selected, device, staging
    except BaseException:
        shutil.rmtree(staging, ignore_errors=True)
        raise


def read_existing_index(index_path: Path, device: dict) -> dict:
    if not index_path.exists():
        return {"schema_version": 1, "device": device, "captures": {}}
    try:
        index = json.loads(index_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        raise CaptureError(f"Existing capture index is invalid: {index_path}") from error
    if not isinstance(index, dict) or not isinstance(index.get("captures"), dict):
        raise CaptureError(f"Existing capture index has an unsupported schema: {index_path}")
    existing_device = index.get("device", {})
    if existing_device.get("identifier") and device.get("identifier") and existing_device["identifier"] != device["identifier"]:
        raise CaptureError("Existing device index belongs to a different simulator/device identifier")
    return index


def collect(args: argparse.Namespace) -> int:
    try:
        captures, device, staging = gather_captures(args.xcresults, args.device, args.attachments_dir)
        revision, dirty = git_source_metadata(args.source_revision, args.source_worktree)
        device_root = DESTINATION / args.device
        index_path = device_root / "capture-index.json"
        index = read_existing_index(index_path, device)
        entries = index["captures"]

        conflicts = []
        for key, record in captures.items():
            target = device_root / record["file"]
            existing = entries.get(key)
            if existing is None and not target.exists():
                continue
            if not args.replace_existing or existing is None or not target.is_file():
                conflicts.append(str(target))
                continue
            if float(record["timestamp"] or 0) <= float(existing.get("timestamp") or 0):
                conflicts.append(str(target))
        if conflicts:
            raise CaptureError(
                "Refusing to overwrite existing captures or index entries:\n  " + "\n  ".join(conflicts)
                + "\nRemove the intended prior capture and its index entry before recollecting."
            )

        png_sources = {}
        for key, record in captures.items():
            png_sources[key] = record.pop("_exported_path")
            record["device"] = device
            record["source_revision"] = revision
            record["source_worktree_dirty"] = dirty
        print(f"Device: {args.device} ({device.get('model_name') or 'model unknown'})")
        print(f"Source: {revision} (dirty={str(dirty).lower()})")
        for key, record in sorted(captures.items()):
            print(f"{key} -> {device_root / record['file']}")
        print(f"Index: {index_path}")
        if args.dry_run:
            print("Dry run: no files written.")
            return 0

        device_root.mkdir(parents=True, exist_ok=True)
        for key, record in sorted(captures.items()):
            target = device_root / record["file"]
            target.parent.mkdir(parents=True, exist_ok=True)
            temporary_target = target.with_suffix(".png.tmp") if target.exists() else target
            with temporary_target.open("wb" if target.exists() else "xb") as output, png_sources[key].open("rb") as source:
                shutil.copyfileobj(source, output)
            if temporary_target != target:
                os.replace(temporary_target, target)

        index["device"] = device
        entries.update(captures)
        payload = json.dumps(index, ensure_ascii=False, indent=2) + "\n"
        temporary_index = index_path.with_suffix(".json.tmp")
        temporary_index.write_text(payload, encoding="utf-8")
        os.replace(temporary_index, index_path)
        print(f"Collected {len(captures)} captures.")
        return 0
    finally:
        if "staging" in locals():
            shutil.rmtree(staging, ignore_errors=True)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("device", choices=DEVICES, help="actual-map device directory")
    parser.add_argument("xcresults", nargs="+", type=Path, help="XCTest result bundles")
    parser.add_argument("--dry-run", action="store_true", help="validate and list captures without writing")
    parser.add_argument("--replace-existing", action="store_true", help="replace only older indexed captures from the same simulator")
    parser.add_argument("--attachments-dir", type=Path, help="directory already exported by xcresulttool")
    parser.add_argument("--source-revision", help="override the current Git revision in provenance")
    parser.add_argument("--source-worktree", choices=("clean", "dirty"), help="override inferred dirty state")
    args = parser.parse_args()
    try:
        return collect(args)
    except (CaptureError, OSError, subprocess.CalledProcessError) as error:
        print(f"error: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
