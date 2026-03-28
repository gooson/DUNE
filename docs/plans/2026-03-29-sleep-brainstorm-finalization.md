---
topic: sleep-brainstorm-finalization
date: 2026-03-29
status: approved
confidence: high
related_solutions: [architecture/2026-03-28-sleep-analysis-5axis-enhancement]
related_brainstorms: [2026-03-28-sleep-analysis-enhancement]
---

# Implementation Plan: 수면 고도화 브레인스톰 마무리

## Context

수면 분석 고도화 브레인스톰(2026-03-28)의 MVP 4개 Phase가 모두 구현 완료됨.
남은 작업은 문서 관리(status 업데이트, Open Questions 결정 반영)와 Nice-to-have 항목의 TODO 등록.

## Requirements

### Functional

- 브레인스톰 문서의 status를 `draft` → `implemented`로 업데이트
- Open Questions 4개에 대해 실제 구현 기반으로 결정사항 기록
- Nice-to-have 6개 항목을 각각 TODO 파일로 생성
- 관련 Plan 문서의 status도 `implemented`로 업데이트

### Non-functional

- TODO 번호는 전역 고유 (현재 최고 번호: 144)
- TODO 카테고리: general (수면 전용 폴더 기준 미충족 — 5개 미만)
- 문서 변경만, 코드 변경 없음

## Approach

문서 일괄 업데이트 + TODO 파일 생성. 코드 변경이 없으므로 빌드/테스트 불필요.

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `docs/brainstorms/2026-03-28-sleep-analysis-enhancement.md` | Modify | status → implemented, Open Questions 결정 반영 |
| `docs/plans/2026-03-28-sleep-analysis-enhancement.md` | Modify | status → implemented |
| `docs/plans/2026-03-28-sleep-cards-integration.md` | Modify | status → implemented |
| `todos/active/general/145-pending-p3-sleep-environment-analysis.md` | Create | 수면 환경 분석 |
| `todos/active/general/146-pending-p3-sleep-regularity-index.md` | Create | Sleep Regularity Index |
| `todos/active/general/147-pending-p3-sleep-nap-detection.md` | Create | 낮잠 감지/분리 |
| `todos/active/general/148-pending-p3-sleep-debt-recovery-prediction.md` | Create | 수면 부채 회복 예측 |
| `todos/active/general/149-pending-p3-sleep-vitals-unified-view.md` | Create | Apple Health 스타일 Vitals 통합 뷰 |
| `todos/active/general/150-pending-p3-sleep-apple-score-comparison.md` | Create | Apple Sleep Score 비교 |

## Implementation Steps

### Step 1: 브레인스톰 + Plan 문서 status 업데이트

- **Files**: brainstorm, 2 plan docs
- **Changes**: YAML frontmatter `status: draft/approved` → `status: implemented`
- **Verification**: grep으로 status 확인

### Step 2: Open Questions 결정사항 반영

- **Files**: `docs/brainstorms/2026-03-28-sleep-analysis-enhancement.md`
- **Changes**: 각 질문 옆에 결정사항과 근거 추가
- **Verification**: Read로 내용 확인

### Step 3: Nice-to-have 6개 TODO 생성

- **Files**: 6개 신규 TODO 파일 (145~150)
- **Changes**: 각 TODO에 source, priority, status frontmatter 포함
- **Verification**: ls로 파일 존재 확인

## Edge Cases

| Case | Handling |
|------|----------|
| TODO 번호 충돌 | 145부터 순차 사용, 기존 최고 144 확인 완료 |
| Nice-to-have 중 외부 의존 (Apple Sleep Score API) | TODO 설명에 "API 공개 시" 조건 명시 |

## Testing Strategy

- Unit tests: 해당 없음 (문서 변경만)
- Build: 해당 없음 (코드 변경 없음)
- Manual verification: 파일 존재 및 내용 확인

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| 없음 | - | - | 문서 변경만으로 리스크 최소 |

## Confidence Assessment

- **Overall**: High
- **Reasoning**: 코드 변경 없이 문서 관리만 수행. 모든 결정은 이미 구현된 코드를 근거로 함.
