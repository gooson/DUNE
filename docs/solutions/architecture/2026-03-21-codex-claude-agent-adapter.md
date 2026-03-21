---
tags: [codex, claude, agents, adapter, workflow, parity]
category: architecture
date: 2026-03-21
status: implemented
severity: important
related_files:
  - AGENTS.md
  - .codex/agent-map.md
  - .codex/skill-compat.md
  - .codex/agent-memory/README.md
  - scripts/check-codex-claude-parity.py
related_solutions:
  - docs/solutions/architecture/2026-02-16-agent-pipeline-integration.md
  - docs/solutions/general/2026-03-07-run-skill-non-skip-and-settings-inheritance.md
---

# Solution: Codex Claude Agent Adapter Layer

## Problem

이 워크스페이스는 `.claude/` 하위의 skill/agent/rule 문서를 source of truth로 유지하고 있었지만, Codex 런타임에서 그 문서를 **어떻게 실행 semantics로 번역할지**는 암묵 처리에 가까웠다. 그 결과 Claude 전용 개념(`Task tool`, `TodoWrite`, persistent agent memory, review 중 즉시 수정 허용)이 Codex에서 일관되게 해석되지 않을 위험이 있었다.

### Symptoms

- `AGENTS.md`는 parity를 선언했지만 Codex 전용 실행 규칙이 구체적으로 정리되어 있지 않았다.
- `.claude/agents/*.md`의 `model`, `tools`, `memory` 정보가 Codex에서 어디까지 advisory인지 명확하지 않았다.
- review/findings와 fix/resolve 경계가 흐려져, Codex에서 리뷰 단계 중 수정이 섞일 가능성이 있었다.
- `.claude`와 Codex adapter 문서가 분리되면 drift가 생기기 쉬운데, 이를 확인하는 검사기가 없었다.

### Root Cause

문제의 본질은 **문서 parity와 런타임 parity를 같은 것으로 취급한 것**이다. Claude 문서를 그대로 읽는 것만으로는 충분하지 않고, Codex 고유 도구/제약(`update_plan`, `spawn_agent` 정책, sandbox/approval, shadow memory)에 맞춘 별도 adapter contract가 필요했다.

## Solution

`.claude/**` 는 그대로 두고, Codex 전용 adapter 레이어를 `.codex/**` 와 `AGENTS.md`에 추가했다. 또한 `.claude`와 `.codex` 사이의 최소 parity를 자동 검사하는 `scripts/check-codex-claude-parity.py` 를 도입했다.

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `AGENTS.md` | `Codex Adapter Layer` 섹션 추가 및 canonical source 포인터 정의 | `.claude` 불변 원칙과 Codex adapter 위치를 명시 |
| `.codex/skill-compat.md` | Claude skill concept → Codex tool mapping 정의 | `Task tool`, `TodoWrite`, read-only review, ship fallback 규칙을 Codex semantics로 번역 |
| `.codex/agent-map.md` | 14개 agent의 Codex model/reasoning/edit policy/memory source 문서화 | agent별 차이점을 한 곳에 정리 |
| `.codex/agent-memory/README.md` | `.claude` memory read + `.codex` shadow write 정책 정의 | repo 밖 Claude memory 가정을 Codex에 안전하게 흡수 |
| `scripts/check-codex-claude-parity.py` | agent/skill 목록과 adapter 경로 존재 여부 검사 추가 | `.claude` 변경 후 Codex adapter drift를 조기 탐지 |

### Key Code

```md
## Codex Adapter Layer

- `.claude/**` 는 수정하지 않는 source of truth
- 공통 실행 규칙은 `.codex/skill-compat.md` 를 canonical source로 사용
- agent별 모델/추론/edit policy/memory source는 `.codex/agent-map.md` 를 canonical source로 사용
```

```python
def validate_agent_map_paths(repo_root: Path, agent_map_text: str, issues: list[str]) -> None:
    for line_no, line in enumerate(agent_map_text.splitlines(), start=1):
        for label in ("Source", "Memory read", "Memory write"):
            ...
            for ref in refs:
                validate_reference(repo_root, label, ref, issues, line_no)
```

## Prevention

Codex adapter는 source 복제본이 아니라 **delta-only layer** 여야 한다. 공통 규칙은 한 canonical 문서에 모으고, 다른 파일은 포인터나 agent별 차이만 담아야 drift surface가 줄어든다. 그리고 `.claude` 구조가 바뀌는 순간 즉시 checker를 돌려 문서 parity가 깨졌는지 확인해야 한다.

### Checklist Addition

- [ ] `.claude/**` 변경 시 `.codex/agent-map.md`, `.codex/skill-compat.md`, `scripts/check-codex-claude-parity.py` 를 함께 점검한다.
- [ ] 공통 실행 규칙은 한 canonical 문서에만 두고, 나머지 문서는 포인터 또는 role-specific delta만 담는다.
- [ ] review 단계와 resolve 단계의 edit policy가 분리되어 있는지 확인한다.
- [ ] path 기반 adapter 문서는 checker가 실제 경로 존재 여부까지 검증하는지 확인한다.

### Rule Addition (if applicable)

새 `.claude/rules/` 추가는 하지 않았다. 이번 변경은 Claude source 문서가 아니라 Codex runtime adapter 계층에 대한 것이므로 `.codex/**` 와 `AGENTS.md` 범위에서 해결하는 것이 맞다.

## Lessons Learned

- `.claude` parity를 선언하는 것과 Codex가 그 문서를 올바르게 실행하는 것은 다른 문제다.
- adapter 문서가 여러 개일수록 "무엇이 canonical source인지"를 먼저 못 박아야 나중에 drift를 줄일 수 있다.
- checker는 heading 개수만 세는 수준이면 부족하고, 실제 경로/reference 존재 여부까지 확인해야 런타임 실패를 줄일 수 있다.
