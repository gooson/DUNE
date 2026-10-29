#!/usr/bin/env python3
"""Reject unit selectors that do not name a test type or method in its target."""

import re
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
SOURCES = {
    "DUNETests": (ROOT / "DUNETests", ROOT / "DUNE" / "DUNETests"),
    "DUNEWatchTests": (ROOT / "DUNEWatchTests",),
}


TOP_LEVEL_TYPE = re.compile(
    r"^(?:(?:private|fileprivate|internal|public|open|final|indirect)\s+)*"
    r"(?:class|struct|enum|extension)\s+([A-Za-z_][A-Za-z_0-9]*)\b", re.MULTILINE
)


def validate(selector: str) -> None:
    parts = selector.split("/")
    target, suite = parts[:2]
    method = parts[2] if len(parts) == 3 else None
    suite_found = False
    method_found = False
    for directory in SOURCES[target]:
        for path in directory.rglob("*.swift"):
            source = path.read_text(encoding="utf-8", errors="replace")
            declarations = list(TOP_LEVEL_TYPE.finditer(source))
            for index, declaration in enumerate(declarations):
                if declaration.group(1) != suite:
                    continue
                suite_found = True
                if method is None:
                    continue
                end = declarations[index + 1].start() if index + 1 < len(declarations) else len(source)
                section = source[declaration.end():end]
                if re.search(r"\bfunc\s+" + re.escape(method) + r"\s*\(", section):
                    method_found = True
    if not suite_found:
        raise ValueError(f"unknown unit test suite: {selector}")
    if method and not method_found:
        raise ValueError(f"unknown unit test method: {selector}")


def main() -> int:
    try:
        for selector in sys.argv[1:]:
            validate(selector)
    except (KeyError, IndexError, ValueError) as error:
        print(error, file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main())
