---
topic: ui-test-max-hardening
date: 2026-03-04
status: implemented
confidence: high
related_solutions:
  - docs/solutions/testing/2026-03-02-nightly-full-ui-test-hardening.md
  - docs/solutions/testing/2026-03-03-ipad-activity-tab-ui-test-navigation-stability.md
  - docs/solutions/testing/ui-test-infrastructure-design.md
  - docs/solutions/architecture/2026-02-23-activity-detail-navigation-pattern.md
related_brainstorms:
  - docs/brainstorms/2026-03-04-ui-test-max-hardening.md
---

# Implementation Plan: UI Test Max Hardening

## Context
UI 테스트가 탭별 스모크 중심으로 제한되어 있고, Activity 상세 화면군 ViewModel 테스트 일부가 누락되어 회귀 탐지 범위가 불충분했다. 목표는 전 화면/전 절차에 가깝게 단위 테스트와 UI 테스트를 동시에 확장해 릴리즈 리스크를 낮추는 것이다.

## Requirements

### Functional
- 누락 ViewModel 테스트 9종 추가
- 기존 탭별 smoke 테스트에 주요 사용자 절차(진입/취소/유효성/탐색) 확장
- Life habit form Save/Cancel 접근성 식별자 보강

### Non-functional
- 기존 UI 테스트 인프라(`UITestBaseCase`, `AXID`)와 일관성 유지
- 로케일 의존 문자열 selector 최소화
- 시뮬레이터 불안정 시에도 최소 컴파일 검증(build-for-testing) 확보

## Approach
기존 테스트 구조를 재사용하여 변경 범위를 테스트 파일과 최소 UI 식별자 추가에 한정한다. 상세 비즈니스 로직은 Swift Testing 단위 테스트로 보강하고, UI는 brittle한 좌표/문자열 탭을 피하고 AXID 기반으로 절차를 확장한다.

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| 전면 E2E 확장(모든 상세 플로우 UI 테스트) | 사용자 시나리오 커버 최대화 | 실행 시간 증가, flaky 리스크 증가 | 보류 |
| ViewModel 테스트만 확장 | 빠른 안정화 | 실제 네비게이션 회귀 탐지 한계 | 부분 채택 |
| ViewModel + 핵심 절차 smoke 확장 | 비용 대비 커버리지 균형 | 일부 상세 절차는 후속 필요 | 채택 |

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| DUNE/Presentation/Life/HabitFormSheet.swift | modify | Save/Cancel AXID 추가 |
| DUNEUITests/Smoke/ActivitySmokeTests.swift | modify | picker 검색 절차 검증 추가 |
| DUNEUITests/Smoke/DashboardSmokeTests.swift | modify | notifications 진입 절차 검증 추가 |
| DUNEUITests/Smoke/LifeSmokeTests.swift | modify | 빈 저장/weekly stepper 절차 검증 추가 |
| DUNEUITests/Smoke/SettingsSmokeTests.swift | modify | Exercise Defaults 진입 검증 추가 |
| DUNEUITests/Smoke/WellnessSmokeTests.swift | modify | body save 활성화/recovered end date 절차 검증 추가 |
| DUNETests/*Detail*ViewModelTests.swift 외 9개 | add | 누락 ViewModel 단위 테스트 추가 |
| docs/brainstorms/2026-03-04-ui-test-max-hardening.md | add | 요구사항/범위 정리 문서 |

## Implementation Steps

### Step 1: UI 식별자/Smoke 절차 보강
- **Files**: HabitFormSheet + 5개 Smoke 테스트 파일
- **Changes**: 기존 AXID 체계 준수한 식별자 추가, 탭별 주요 절차 assert 확장
- **Verification**: DUNEUITests build-for-testing 성공

### Step 2: 누락 ViewModel 테스트 추가
- **Files**: 9개 신규 DUNETests 파일
- **Changes**: 데이터 변환, 정렬, fallback, 상태 전환, guard 경로 테스트
- **Verification**: 신규 Suite only-testing 통과

### Step 3: 파이프라인 품질 검증 및 문서화
- **Files**: docs/solutions/testing/* (신규)
- **Changes**: 적용한 패턴/제약/재발 방지 체크리스트 문서화
- **Verification**: 문서 frontmatter + 관련 파일 링크 점검

## Edge Cases

| Case | Handling |
|------|----------|
| UI 런타임 테스트 장시간 정체 | build-for-testing로 컴파일 게이트 유지 |
| 날짜 경계 의존 테스트 | `Calendar.startOfDay` 기반 fixture로 고정 |
| 빈 입력 저장 동작 | 폼이 dismiss되지 않는지 검증 |
| 중복/누락 데이터 | fallback/empty-state 테스트로 고정 |

## Testing Strategy
- Unit tests: 신규 9개 ViewModel test suite 실행
- Integration tests: 없음 (범위 외)
- Manual verification: iPhone/iPad 실기 UI 런타임 smoke는 후속 권장

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| UI runtime flaky | high | medium | build-for-testing + AXID 기반 selector 유지 |
| 상세 절차 미커버리지 잔존 | medium | medium | 2차 라운드에서 상세 flow 전용 suite 분리 |
| 테스트 데이터 fixture drift | low | medium | 모델 init/enum 변경 시 테스트 동기화 체크리스트 적용 |

## Confidence Assessment
- **Overall**: High
- **Reasoning**: 기존 패턴을 그대로 사용해 리스크가 낮고, 누락 공백(ViewModel 9종 + 핵심 smoke 절차)을 직접 채웠다. UI runtime만 환경 의존성이 남아 있어 컴파일 게이트로 보완했다.
