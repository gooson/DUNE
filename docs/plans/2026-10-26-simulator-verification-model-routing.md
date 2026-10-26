---
tags: [codex, model-routing, simulator, screenshots, tokens]
topic: simulator-verification-model-routing
date: 2026-10-26
category: plan
status: implemented
confidence: high
related_solutions:
  - docs/solutions/architecture/2026-09-26-codex-token-efficiency.md
related_brainstorms: []
---

# 실행 검증 모델 분담

## Context

시뮬레이터 조작과 스크린샷 수집에 상위 모델의 긴 문맥을 반복 사용하면 비용이 늘어난다. 기존 셸 우선 정책을 유지하면서, 판단이 필요한 수집 작업과 품질 검토의 담당 모델을 구분한다.

## Requirements

- 정해진 명령 실행·대기는 표준 스크립트로 처리한다.
- 여러 화면 진입·상태 확인·캡처 수집이 필요한 독립 작업은 Luna low에 최소 문맥으로 맡긴다.
- 검증 범위·시각적 품질·테스트 설계는 Sol medium, 복잡한 원인 분석은 Astra high로 배정한다.
- `.claude/**`, 앱 소스, 실행기와 기존 검증 의무는 변경하지 않는다.
- 문서 배정만으로 실제 모델이 전환됐다고 보고하지 않는다.

## Approach

기존 역할을 추가하지 않고 `ui-test-expert`에 실행 수집용 하위 모드를 둔다. 모델 배정은 agent-map, 위임 계약은 skill-compat, 결과 전달은 token-efficiency에 각각 한 번 기록한다.

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| 모든 실행을 Luna agent로 위임 | 단순한 배정 | 단일 셸 명령에도 생성·문맥 비용 발생 | 제외 |
| ui-test-expert 전체를 Luna로 변경 | 배정 수정이 작음 | 테스트 설계·시각적 판단까지 강등 | 제외 |
| 스크립트 우선 + 수집 모드 분리 | 기존 실행기와 품질 기준 재사용 | 모드 경계를 명시해야 함 | 채택 |

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `.codex/agent-map.md` | 수정 | 수집 모드의 실제 모델·추론·편집 제한 |
| `.codex/skill-compat.md` | 수정 | 수집 위임 조건·최소 입력·상향 경계 |
| `.codex/token-efficiency.md` | 수정 | 제한된 로그·캡처·결과 전달 계약 |
| `docs/plans/2026-10-26-simulator-verification-model-routing.md` | 추가 | 계획과 검증 범위 |
| `docs/solutions/architecture/2026-10-26-simulator-verification-model-routing.md` | 추가 | 구현 결과와 재사용 지침 |

## Implementation Steps

### Step 1: 모델과 책임 경계

- **Files**: agent-map, skill-compat
- **Changes**: 셸 실행, Luna 수집, Sol 품질 판단, Astra 원인 분석을 구분한다. 기존 parent 독립 작업 조건, 전용 기기·잠금·deadline·재시도 제한을 유지한다.
- **Verification**: diff 검토와 Claude parity 검사.

### Step 2: 결과와 증거 전달

- **Files**: token-efficiency
- **Changes**: 기기·selector·환경·결과 receipt·새 PNG 출처·미완료 상태만 요약하고, parent의 동일 명령 재실행을 막는다.
- **Verification**: Agent-Native 리뷰, 표준 UI 범위 판정기.

### Step 3: 문서화와 Ship

- **Files**: 계획서, 해결책 문서
- **Changes**: 확인된 정책과 미측정 비용을 기록하고 PR 생성·머지한다.
- **Verification**: 최종 parity, diff 공백 검사, PR 상태 확인.

## Edge Cases

| Case | Handling |
|------|----------|
| parent가 할 독립 작업 없음 / 단일 명령 | inline 셸, 모델 전환 주장 금지 |
| 지정 모델·이미지 입력 도구 없음 | 이용 가능한 대안과 이유를 기록하고 적절한 담당에게 전달 |
| 기기 소유 불명 / 잠금·deadline 실패 | 기존 실행 한도로 중단, 환경 복구 조건 기록 |
| 0건·unknown·필수 selector 누락 | 성공 처리 금지 |
| 화면 상태 불일치 / 원인 불명 실패 | 추가 시도 없이 현재 증거를 Sol/Astra에 전달 |

## Testing Strategy

- Unit tests: 실행 코드 변경이 없으므로 신규 테스트 없음.
- Integration tests: `python3 scripts/check-codex-claude-parity.py`와 `git diff --check`.
- UI: `python3 scripts/plan-ui-tests.py --base main`으로 문서 변경 면제 확인. 앱 빌드·UI 실행·디자인맵 캡처는 변경 영향이 없어 skipped.
- Manual verification: Agent-Native와 최종 PR 리뷰에서 문서 간 충돌·중복 실행·성공 오인 여부 확인.

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| 작은 작업의 위임 비용 증가 | 중 | 중 | 셸 우선과 독립 작업 조건 유지 |
| 수집 성공을 UI 품질 통과로 오인 | 중 | 높음 | 품질 판단을 Sol에 유지 |
| 모델 상향을 재시도로 사용 | 낮음 | 높음 | 모델 변경에도 동일 원인의 횟수 유지 |

## Confidence Assessment

- **Overall**: High
- **Reasoning**: 기존 adapter와 실행기를 재사용한다. 실제 절감률과 Luna 수집 품질은 다음 실제 검증 작업에서 측정하며 이번 변경에서 주장하지 않는다.
