---
topic: multilingual-mandatory-rule
date: 2026-03-04
status: implemented
confidence: high
related_solutions:
  - docs/solutions/general/localization-gap-audit.md
  - docs/solutions/general/2026-03-01-localization-completion-audit.md
related_brainstorms: []
---

# Implementation Plan: 다국어 처리 필수 규칙화

## Context

프로젝트에는 `.claude/rules/localization.md`가 존재하지만, `AGENTS.md`의 Always-On `Mandatory rules` 목록에는 포함되어 있지 않다. 이 상태에서는 세션마다 다국어 규칙이 누락될 가능성이 남아 있고, 동일한 localization leak 회귀가 반복될 수 있다.

## Requirements

### Functional

- `AGENTS.md`의 `Mandatory rules` 목록에 `localization.md`를 추가한다.
- 문자열/다국어 관련 변경 시 localization 규칙을 반드시 참조하도록 `Trigger Rules`를 강화한다.
- 기존 규칙 목록 및 다른 트리거 동작을 깨지 않는다.

### Non-functional

- 문서 스타일은 기존 규칙(`documentation-standards.md`)을 따른다.
- 변경 범위를 규칙 문서(AGENTS) 중심으로 최소화한다.
- 중복 규칙 추가 없이 단일 소스(`localization.md`)를 재사용한다.

## Approach

- 신규 규칙 파일을 만들지 않고, 이미 운영 중인 `.claude/rules/localization.md`를 Always-On 필수 규칙으로 승격한다.
- `Trigger Rules`에 localization 관련 명시 규칙을 추가해, 문자열 변경 작업에서 자동 참조가 보장되도록 한다.

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| `localization.md` 신규 작성/분리 | 강한 독립성 | 기존 규칙 중복, 관리 비용 증가 | Rejected |
| Correction Log에만 교정 추가 | 변경량 최소 | Always-On 강제력이 없음 | Rejected |
| AGENTS Mandatory + Trigger 동시 강화 | 기존 체계 재사용, 강제력 명확 | 문서 1파일 수정 필요 | Selected |

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `AGENTS.md` | Modify | Mandatory rules에 localization 추가 + Trigger Rules 강화 |
| `docs/plans/2026-03-04-multilingual-mandatory-rule.md` | Add | 본 구현 계획 기록 |

## Implementation Steps

### Step 1: Mandatory rules 승격

- **Files**: `AGENTS.md`
- **Changes**: `### Mandatory rules` 목록에 `/Users/shanks/work/Health/.claude/rules/localization.md` 추가
- **Verification**: `rg "Mandatory rules|localization.md" AGENTS.md` 결과에서 필수 목록 포함 여부 확인

### Step 2: Trigger rules 강화

- **Files**: `AGENTS.md`
- **Changes**: UI/사용자 문자열 변경 및 다국어 요청 시 `localization` 규칙 필수 참조 규칙 추가
- **Verification**: `rg "다국어|localization" AGENTS.md`로 트리거 문구 존재 확인

### Step 3: 문서 일관성 검증

- **Files**: `AGENTS.md`
- **Changes**: 없음(검증 단계)
- **Verification**: 항목 중복 여부 및 절대 경로 포맷 일치 확인

## Edge Cases

| Case | Handling |
|------|----------|
| `localization.md`가 이미 다른 섹션에서만 언급됨 | Mandatory 섹션에 명시적으로 1회 추가 |
| Trigger 문구가 과도해 기존 트리거와 충돌 | 기존 트리거 유지, localization 관련 조건만 1줄 추가 |
| 규칙 경로 표기 불일치 | 기존 Mandatory 목록과 동일한 절대 경로 형식 사용 |

## Testing Strategy

- Unit tests: 없음 (문서 규칙 변경)
- Integration tests: 없음
- Manual verification: `AGENTS.md`에서 Mandatory/Trigger 섹션 diff 확인

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| 규칙 중복으로 가독성 저하 | Low | Low | 최소 문구 추가, 기존 섹션 구조 유지 |
| 필수화 후 누락 인지 과신 | Low | Medium | Trigger와 Mandatory를 함께 보강해 실행 시점 강제 |

## Confidence Assessment

- **Overall**: High
- **Reasoning**: 기존 localization 규칙 자산을 그대로 사용하고, 강제 지점(Always-On + Trigger)을 동시에 보강하는 문서 변경이라 리스크가 낮다.
