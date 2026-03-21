#!/usr/bin/env python3

from __future__ import annotations

import re
import sys
from pathlib import Path


REQUIRED_SKILLS = [
    "/run",
    "/plan",
    "/work",
    "/review",
    "/compound",
    "/ship",
    "/ui-testing",
]


def parse_agent_names(agent_dir: Path) -> list[str]:
    return sorted(path.stem for path in agent_dir.glob("*.md"))


def parse_markdown_headings(path: Path, pattern: str) -> list[str]:
    text = path.read_text(encoding="utf-8")
    return sorted(set(re.findall(pattern, text, re.MULTILINE)))


def main() -> int:
    repo_root = Path(__file__).resolve().parent.parent
    claude_agents_dir = repo_root / ".claude" / "agents"
    codex_agent_map = repo_root / ".codex" / "agent-map.md"
    codex_skill_compat = repo_root / ".codex" / "skill-compat.md"
    agents_md = repo_root / "AGENTS.md"

    issues: list[str] = []

    if not claude_agents_dir.is_dir():
        issues.append(f"Missing Claude agents directory: {claude_agents_dir}")
    if not codex_agent_map.is_file():
        issues.append(f"Missing Codex agent map: {codex_agent_map}")
    if not codex_skill_compat.is_file():
        issues.append(f"Missing Codex skill compatibility doc: {codex_skill_compat}")
    if not agents_md.is_file():
        issues.append(f"Missing AGENTS.md: {agents_md}")

    if issues:
        print("Parity check failed before content validation:")
        for issue in issues:
            print(f"- {issue}")
        return 1

    claude_agents = parse_agent_names(claude_agents_dir)
    mapped_agents = parse_markdown_headings(codex_agent_map, r"^### ([a-z0-9-]+)$")
    compat_skills = parse_markdown_headings(codex_skill_compat, r"^### (/[a-z-]+)$")
    agents_text = agents_md.read_text(encoding="utf-8")

    missing_agents = sorted(set(claude_agents) - set(mapped_agents))
    extra_agents = sorted(set(mapped_agents) - set(claude_agents))
    missing_skills = sorted(set(REQUIRED_SKILLS) - set(compat_skills))

    if missing_agents:
        issues.append(f"Unmapped Claude agents: {', '.join(missing_agents)}")
    if extra_agents:
        issues.append(f"Unknown Codex agent-map entries: {', '.join(extra_agents)}")
    if missing_skills:
        issues.append(f"Missing skill compatibility sections: {', '.join(missing_skills)}")

    required_agreements = [
        ".codex/agent-map.md",
        ".codex/skill-compat.md",
        ".codex/agent-memory/README.md",
        "TodoWrite",
        "spawn_agent",
    ]
    for token in required_agreements:
        if token not in agents_text:
            issues.append(f"AGENTS.md is missing adapter reference: {token}")

    if issues:
        print("Codex/Claude parity drift detected:")
        for issue in issues:
            print(f"- {issue}")
        return 1

    print("Codex/Claude parity check passed.")
    print(f"- Claude agents: {len(claude_agents)}")
    print(f"- Codex mapped agents: {len(mapped_agents)}")
    print(f"- Skill compatibility sections: {', '.join(REQUIRED_SKILLS)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
