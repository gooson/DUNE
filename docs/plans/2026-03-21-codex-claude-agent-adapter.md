---
topic: codex-claude-agent-adapter
date: 2026-03-21
status: approved
confidence: high
related_solutions:
  - docs/solutions/architecture/2026-02-16-agent-pipeline-integration.md
  - docs/solutions/general/2026-03-07-run-skill-non-skip-and-settings-inheritance.md
  - docs/solutions/architecture/2026-03-07-claude-md-restructure-and-progress-markers.md
related_brainstorms:
  - docs/brainstorms/2026-02-28-skill-agent-system-audit.md
---

# Implementation Plan: Codex Claude Agent Adapter

## Context

현재 워크스페이스는 `.claude` 하위 문서를 Codex에서도 그대로 참조하도록 맞춰져 있지만, 실제 실행 계층은 아직 Claude 전용 가정과 Codex 런타임 사이의 차이를 명시적으로 번역하지 못한다. 특히 `Task tool`, `TodoWrite`, review 중 수정 허용 범위, persistent agent memory, model/tool frontmatter 해석이 Codex 쪽에서 암묵 처리되고 있어 `/run` 기반 자동화가 불안정하다.

이번 변경의 목표는 **`.claude/**`를 source of truth로 유지한 채**, Codex 전용 adapter 레이어를 추가해 실행 semantics를 안정화하는 것이다.

## Requirements

### Functional

- `.claude/**` 파일은 수정하지 않는다.
- Codex가 `.claude/agents/*.md`와 `.claude/skills/*/SKILL.md`를 어떻게 해석하는지 문서화한다.
- agent별 Codex 실행 정책(model/reasoning/edit policy/memory source)을 매핑 파일로 정리한다.
- `/run`, `/work`, `/review`, `/ship`에서 Claude 전용 개념(`Task tool`, `TodoWrite`)을 Codex 도구로 번역하는 규칙을 만든다.
- `.claude`와 Codex adapter 간 drift를 확인하는 로컬 checker를 추가한다.

### Non-functional

- `.claude` 내용 복제는 최소화한다.
- Codex adapter가 Claude 문서와 쉽게 동기화되도록 유지 비용을 낮춘다.
- review 요청 시 read-only 기본값을 분명히 해 실수로 수정이 섞이지 않게 한다.
- detached HEAD, sandbox/approval, sub-agent spawning 제약 등 Codex 런타임 특성을 반영한다.

## Approach

Claude 문서를 복제하지 않고, **Codex-only thin adapter**를 추가한다.

1. `AGENTS.md`에 Codex adapter 계약을 명시한다.
2. `.codex/` 아래에 agent/skill compatibility 문서를 생성한다.
3. `.claude`에 있는 agent 목록과 Codex adapter 목록을 비교하는 checker를 추가한다.
4. checker를 통해 future drift를 조기에 발견할 수 있게 한다.

이 접근은 source of truth를 유지하면서도 Codex 실행 규칙을 독립적으로 발전시킬 수 있다.

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| `.claude` 문서를 직접 Codex 친화적으로 수정 | 한 군데만 보면 됨 | Claude parity 훼손, upstream drift 위험 | Rejected |
| `.claude` 문서를 `.codex/agents/*.md`로 전량 복제 | Codex 전용 최적화 가능 | 중복/드리프트 비용 큼 | Rejected |
| Codex thin adapter + parity checker | source 유지, drift 감지 가능, 변경 범위 작음 | adapter 문서를 별도로 관리해야 함 | Selected |

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `AGENTS.md` | modify | Codex adapter 계약, 실행 우선순위, memory/spawn 규칙 추가 |
| `.codex/agent-map.md` | create | agent별 Codex 실행 매핑 정의 |
| `.codex/skill-compat.md` | create | skill별 Claude→Codex 번역 규칙 정의 |
| `.codex/agent-memory/README.md` | create | Codex shadow memory 정책 설명 |
| `scripts/check-codex-claude-parity.py` | create | `.claude`와 Codex adapter drift 검사 |
| `docs/plans/2026-03-21-codex-claude-agent-adapter.md` | create | 구현 계획서 |
| `docs/solutions/architecture/2026-03-21-codex-claude-agent-adapter.md` | create | 작업 완료 후 solution 문서 |

## Implementation Steps

### Step 1: Adapter Contract 문서화

- **Files**: `AGENTS.md`
- **Changes**:
  - `.claude` 불변 원칙 명시
  - Codex adapter 파일 위치와 우선순위 명시
  - `Task tool`, `TodoWrite`, `model`, `tools`, `memory`, `agent` 해석 규칙 보강
  - sub-agent spawning 허용 조건과 inline fallback 정의
- **Verification**:
  - `rg -n "Codex adapter|Task tool|TodoWrite|spawn_agent|shadow memory" AGENTS.md`

### Step 2: Codex Mapping Assets 생성

- **Files**: `.codex/agent-map.md`, `.codex/skill-compat.md`, `.codex/agent-memory/README.md`
- **Changes**:
  - 14개 agent별 role, reasoning, edit policy, memory source, output contract 정의
  - `/run`, `/review`, `/work`, `/ship`, `ui-testing`의 compatibility 규칙 정리
  - review-only vs fix-capable agent의 경계 명시
  - repo 내부 memory와 Codex shadow memory의 사용 원칙 정리
- **Verification**:
  - `rg -n "review-only|fix-capable|TodoWrite|update_plan|Task tool|shadow memory" .codex/agent-map.md .codex/skill-compat.md .codex/agent-memory/README.md`

### Step 3: Drift Checker 추가

- **Files**: `scripts/check-codex-claude-parity.py`
- **Changes**:
  - `.claude/agents/*.md`와 `.codex/agent-map.md`의 agent 목록 비교
  - `.claude/skills/*/SKILL.md` 중 adapter 문서에서 다루는 핵심 skill 존재 여부 확인
  - 누락/불일치 발견 시 non-zero exit로 실패하게 구현
- **Verification**:
  - `python3 scripts/check-codex-claude-parity.py`

### Step 4: Run Workflow 검증 및 정리

- **Files**: 위 변경 파일 전체
- **Changes**:
  - detached HEAD 환경에서는 `codex/` prefix 작업 브랜치 생성
  - checker 실행
  - `scripts/build-ios.sh` 실행으로 Phase gate 충족
  - 최종 review/compound 준비
- **Verification**:
  - `git status --short`
  - `python3 scripts/check-codex-claude-parity.py`
  - `scripts/build-ios.sh`

## Edge Cases

| Case | Handling |
|------|----------|
| 현재 detached HEAD 상태 | Work Setup에서 `codex/` 브랜치 생성 후 작업 |
| review agent가 수정/테스트 작성을 요구 | Codex mapping에서 review 요청 시 read-only 기본값 명시 |
| `.claude`에 신규 agent가 추가됨 | parity checker가 누락을 즉시 보고 |
| repo 밖 persistent memory 경로 요구 | `.claude` memory는 read source, `.codex/agent-memory/`는 Codex write target으로 분리 |
| 사용자가 명시적으로 병렬 sub-agent를 요청하지 않음 | inline role emulation 기본값, 명시 요청 시에만 spawn 허용 |

## Testing Strategy

- Unit tests: 별도 앱 테스트 추가는 없음. drift checker 자체를 실행해 검증
- Integration tests:
  - `python3 scripts/check-codex-claude-parity.py`
  - `scripts/build-ios.sh`
- Manual verification:
  - `AGENTS.md`가 `.claude` 불변 원칙과 Codex adapter 경로를 명시하는지 확인
  - `.codex` 문서가 실제 agent/skill 목록을 모두 커버하는지 확인

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| `.claude` 변경 후 `.codex` 매핑이 stale 됨 | medium | high | parity checker 추가 |
| adapter 문서가 과도하게 장황해짐 | medium | medium | source 복제 금지, delta만 기록 |
| review/edit 경계가 모호해져 잘못된 자동 수정 발생 | medium | high | agent-map에 edit policy 명시 |
| detached HEAD에서 커밋/ship 손실 | medium | high | Work Setup에서 즉시 `codex/` 브랜치 생성 |
| `scripts/build-ios.sh`가 환경 이슈로 실패 | medium | medium | 실패 로그를 기록하고 필요 시 재시도/원인 명시 |

## Confidence Assessment

- **Overall**: High
- **Reasoning**: 필요한 source 문서와 기존 solution/brainstorm를 확인했고, 변경 범위가 `.claude` 외부의 문서/스크립트 레이어로 제한되어 있어 구현 리스크가 낮다. 주요 불확실성은 build 환경과 이후 ship 단계의 네트워크/권한뿐이다.
