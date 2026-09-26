#!/usr/bin/env python3
"""Recommend a conservative UI gate; print evidence and argv, never execute tests."""

import argparse
import json
from pathlib import Path
import re
import subprocess
import sys


FEATURE_SUITES = {
    "Activity": ["ActivitySmokeTests", "ActivityExerciseRegressionTests",
                 "ActivityExercisePickerRegressionTests", "ActivityMuscleMapRegressionTests",
                 "FatigueCalculationRegressionTests", "PRSparklineTapTests",
                 "ChartInteractionRegressionUITests"],
    "Exercise": ["ActivitySmokeTests", "ActivityExerciseRegressionTests",
                 "ActivityExercisePickerRegressionTests", "ActivityMuscleMapRegressionTests"],
    "Dashboard": ["DashboardSmokeTests", "TodaySettingsRegressionTests",
                  "TodaySettingsEmptyStateRegressionTests", "CloudSyncConsentRegressionTests",
                  "LaunchExperienceSmokeTests", "ChartInteractionRegressionUITests"],
    "Settings": ["SettingsSmokeTests", "TodaySettingsRegressionTests",
                 "CloudSyncConsentRegressionTests", "LaunchExperienceSmokeTests"],
    "Life": ["LifeSmokeTests", "LifeSeededSmokeTests", "HabitManagementSmokeTests",
             "LifeRegressionTests"],
    "Wellness": ["WellnessSmokeTests", "WellnessRegressionTests",
                 "ChartInteractionRegressionUITests"],
    "Sleep": ["SleepDetailSmokeTests", "WellnessSmokeTests", "WellnessRegressionTests",
              "TodaySettingsRegressionTests", "ChartInteractionRegressionUITests"],
}
IOS_INFRA = {"scripts/test-ui.sh", "scripts/lib/ui-test-selection.sh",
             "scripts/lib/verify-ui-test-log.py", "scripts/tests/test_ui_test_runner.py"}
WATCH_INFRA = {"scripts/test-watch-ui.sh"}
DOC_FILES = {"AGENTS.md", "CLAUDE.md", "README.md", "CHANGELOG.md"}
LEVEL = {"skip": 0, "targeted": 1, "full": 2}


def git(root: Path, *args: str) -> bytes:
    return subprocess.check_output(["git", "-C", str(root), *args], stderr=subprocess.PIPE)


def changed_files(root: Path, base: str) -> tuple[str, list[str]]:
    # Disable rename detection so both the deleted and added paths participate.
    merge_base = git(root, "merge-base", base, "HEAD").decode().strip()
    tracked = git(root, "diff", "--name-only", "--no-renames", "-z", merge_base, "--")
    untracked = git(root, "ls-files", "--others", "--exclude-standard", "-z")
    return merge_base, sorted({p.decode("utf-8") for p in (tracked + untracked).split(b"\0") if p})


def is_document(path: str) -> bool:
    return path in DOC_FILES or (
        path.endswith(".md") and path.startswith(("docs/", "todos/", ".codex/", ".claude/"))
    )


def known_classes(root: Path) -> set[str]:
    classes = set()
    for source in (root / "DUNEUITests").rglob("*.swift"):
        classes.update(re.findall(r"\bclass\s+(\w+)\s*:", source.read_text()))
    return classes


def make_plan(paths: list[str], root: Path) -> dict:
    platforms = {name: {"mode": "skip", "selectors": []} for name in ("ios", "watch")}
    reasons = []
    additional = set()
    classes = known_classes(root)

    def require(platform: str, mode: str, selectors: list[str] = ()) -> None:
        entry = platforms[platform]
        if LEVEL[mode] > LEVEL[entry["mode"]]:
            entry["mode"] = mode
        entry["selectors"] = sorted(set(entry["selectors"]) | set(selectors))

    for path in sorted(set(paths)):
        reason = ""
        if is_document(path):
            reason = "documentation: no app runtime change"
        elif path.startswith(("DUNETests/", "DUNEWatchTests/")) and path.endswith(".swift"):
            reason = "unit test source only: run the affected unit tests"
        elif path in IOS_INFRA:
            require("ios", "full")
            reason = "iOS UI runner infrastructure"
        elif path in WATCH_INFRA or path.startswith(("DUNEWatch/", "DUNEWatchUITests/")):
            require("watch", "full")
            reason = "watch app/test change: separate watch full gate"
            if path.startswith("DUNEWatch/"):
                require("ios", "full")
                reason += "; verify companion app integration"
        elif path.startswith("DUNEUITests/"):
            require("ios", "full")
            reason = "UI tests/helpers/plans changed: validate the complete iOS test contract"
        elif path.startswith("DUNE/Presentation/"):
            feature = path.split("/")[2]
            suites = FEATURE_SUITES.get(feature, [])
            if path.endswith(".swift") and suites and all(s in classes for s in suites):
                require("ios", "targeted", [f"DUNEUITests/{s}" for s in suites])
                reason = f"{feature} feature: related suites plus smoke; consumer review required"
            else:
                require("ios", "full")
                require("watch", "full")
                reason = "shared/unmapped presentation or missing suite: conservative full fallback"
                if feature in ("Vision", "Immersive"):
                    additional.add("visionOS: inspect target membership and run its build/tests")
        else:
            require("ios", "full")
            require("watch", "full")
            reason = "shared, configuration, data/domain, tooling or unknown change: full fallback"
            if path.startswith(("DUNEVision/", "DUNEWidget/", "Shared/", "DUNE/Domain/")):
                additional.add("widget/visionOS: inspect target membership and validate affected targets")
        reasons.append({"path": path, "reason": reason})

    commands = []
    for platform, entry in platforms.items():
        if entry["mode"] == "full":
            entry["selectors"] = []
        if entry["mode"] == "skip":
            continue
        command = ["scripts/test-ui.sh" if platform == "ios" else "scripts/test-watch-ui.sh"]
        if entry["mode"] == "targeted":
            command += ["--smoke"]
            for selector in entry["selectors"]:
                command += ["--only-testing", selector]
        commands.append({"platform": platform, "argv": command})
    return {
        "schema_version": 1,
        "status": "planned-not-executed",
        "platforms": platforms,
        "changes": reasons,
        "commands": commands,
        "additional_validation": sorted(additional),
        "review_required": [
            "Confirm changed symbols have no consumers outside the selected features; otherwise use full.",
            "Confirm new behavior has tests; selection does not establish coverage.",
            "Preserve seeded gesture/layout and device-specific validation requirements.",
            "Full plans exclude manual HealthKit permission tests; permission changes need device evidence.",
            "Record passed tests and skipped tests; no execution or zero tests is not a passed gate.",
        ],
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--base", default="main", help="Base ref used to compute merge-base with HEAD")
    args = parser.parse_args()
    root = Path(__file__).resolve().parent.parent
    try:
        merge_base, paths = changed_files(root, args.base)
        plan = make_plan(paths, root)
    except (OSError, UnicodeError, subprocess.CalledProcessError) as error:
        print(f"UI gate planning failed: {error}", file=sys.stderr)
        return 1
    plan.update({"base": args.base, "merge_base": merge_base,
                 "head": git(root, "rev-parse", "HEAD").decode().strip()})
    print(json.dumps(plan, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    sys.exit(main())
