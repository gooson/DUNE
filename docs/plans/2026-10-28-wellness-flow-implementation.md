---
topic: wellness-flow-implementation
tags: [wellness, flow, swiftui, body-comparison, design]
date: 2026-10-28
category: plan
status: approved
confidence: high
related_solutions:
  - ../solutions/performance/2026-02-28-wellness-scrollview-infinite-bounce.md
  - ../solutions/general/2026-10-22-contextual-first-fold-hero.md
  - ../solutions/general/2026-10-22-wellness-hero-separate-destinations.md
---

# Implementation Plan: Wellness Flow

## Context

사용자의 `/run`은 최신 [웰니스 개편 시안](../design/layout-map/wellness-redesign-proposal.md)과 네 카드 시각 보완을 앱에 적용하는 승인이다. 권장 Flow를 구현하고 Compact 비교본은 제안 이력으로 보존한다. 기존 미커밋 시안 자료도 이번 작업에 포함한다.

## Requirements

- 상태→관측 수면→예측→건강 지표→신체→Watch/사진 자세→부상 흐름. 활성 부상은 예측 다음으로 올리고 중복하지 않는다.
- WELLNESS·104pt 링·수면/컨디션/신체/자세의 실제100점 막대·현재 해석. 점수 계산식은 변경하지 않는다.
- 최근 수면의 실제 날짜·시간·유효 표본 평균, 결측일·한 표본 상태를 보존하고 점수/수면 상세 진입을 분리한다.
- 건강 지표는 범주별 표면·큰 수치·낮은 실제 추세로 강조한다. 단위/최근 시각/오래됨/기준선을 유지하며 정상 범위를 만들지 않는다.
- 신체 네 항목은 실제 값·실제 비교일·변화량을 보여 준다. 각 최신 측정일 기준7일 이전의 관측을 사용하고 비교가 없으면 최신값/날짜만 유지한다. 체지방률 차이는%p, 나머지는 각 단위를 유지한다. 새 BMI/제지방 값을 유도하지 않는다.
- 사진 자세는 중립적인 촬영 안내와 실제 최신 점수/날짜·100점 막대·사진/실시간 행동. Watch 기록과 혼합하지 않는다.
- 한국어/영어/일본어, 큰 글씨의 한 열/외부 점수, 넓은 화면의 관련 카드 두 열. 추가 메뉴·비교·수동 기록·이력을 유지한다.

## Approach

기존 `CompactConditionRing`, `CardNavigationHeader`, DS/AppTheme/Desert 표면·차트 패턴을 재사용한다. feature 전용 새 카드로 표현을 분리해 공유 VitalCard 소비자에 영향을 주지 않는다. SwiftData Query는 독립 child에서 유지하고 eager 배치와 스크롤 바운스 정책을 지킨다. 신체 비교 DTO/조회는 Wellness presentation 범위에 가두고 기존 범위 query API를 사용한다.

### Alternatives

| 접근 | 장점 | 단점 | 결정 |
|---|---|---|---|
| 기존 카드의 표면만 변경 | 작은 변경 | 정보 흐름·비교 원천을 해결 못함 | 제외 |
| 시안 고정값 연결 | 빠름 | 실제 기록과 다름 | 제외 |
| 실제 데이터+feature 전용 카드 | 의미/접근성·공유 영향 제어 | 조회/테스트 보강 필요 | 선택 |

## Affected Files

| File | Change Type | Description |
|---|---|---|
| `DUNE/Presentation/Wellness/WellnessView.swift` | modify | Flow 순서·eager responsive 배치·격리된 부상/자세/이력 연결 |
| `DUNE/Presentation/Wellness/Components/WellnessHeroCard.swift` | modify | 104pt 링·실제 네 항목·시각 보완 |
| `DUNE/Presentation/Wellness/Components/WellnessSleepSummaryCard.swift` | add | 관측 수면 독립 카드 |
| `DUNE/Presentation/Wellness/Components/WellnessMetricCard.swift` | add | 건강/신체 항목 강조·단위·실제 비교 |
| `DUNE/Presentation/Wellness/WellnessViewModel.swift` | modify | 신체 실제 비교·지표 순서/중복 제거 계약 |
| `DUNE/Presentation/Wellness/WellnessBodyComparison.swift` | add | 날짜·단위·비교 표본 선택 모델 |
| `DUNETests/Wellness*Tests.swift` | modify/add | 비교·결측·원천/날짜·동등성·정렬 회귀 |
| `DUNEUITests/Visual/WellnessFlowUITests.swift` | add | Flow·상세·상태·큰 글씨·캡처 |
| `Shared/Resources/Localizable.xcstrings` | modify | en/ko/ja 새 문구·형식 |
| `docs/design/**`, `docs/solutions/**` | modify/add | 구현 기준·실제 H01 새 캡처·학습 기록 |

## Implementation Steps

1. 시안 자료·계획을 체크포인트 커밋한다.
2. 실제 신체 비교 데이터/정렬/테스트를 구현한다. 과거 기록은 서비스의 범위 조회로 받고 latest measurement date를 보존한다. 잘못된 값·미래/같은 샘플·오래된 비교를 배제한다.
3. 히어로/수면/예측 및 건강/신체 카드를 구현하고 Root·자세·부상을 Flow로 연결한다. 논리 단위별 커밋한다.
4. UI 전문가로 변경 동작에 대한 seeded 테스트를 작성하고 번역을 함께 반영한다.
5. 표준 빌드·관련 단위/UI 검증·영향 기기 실제 캡처, 전문가 리뷰/해결, Compound·PR 머지·정리를 수행한다.

## Edge Cases

| Case | Handling |
|---|---|
| 데이터 없음/초기 조회/동기화 대기 | 가짜 점수·그래프 없음, 수동 입력 접근 유지 |
| 일부 query 오류 | 오류를 누락과 구분, 확인된 최신값 유지 |
| 한 표본/결측 수면 | 평균/추세를 만들지 않음 |
| 비교 없음/0 변화/NaN·Infinity | nil과 유효0을 구분, 유효성 검사 |
| 최신 측정이3일 전 | 오늘로 바꾸지 않고 실제 날짜 표시 |
| 여러 활성 부상 | 상단 목록/기존 전체 이력 보존, 중복 없음 |
| 사진 평가 없음/관측 불가 | 안내·촬영 행동, 임의 점수/관절 그림 없음 |
| 접근성 글씨/좁은 폭/iPad·Duo | 고정 링 기하·외부 점수/한 열·라벨 자연 확장 |

## Testing Strategy

- Unit: WellnessViewModel 및 새 비교 모델. 실제7일 기준 선택·단위·날짜·누락·0·비정상값·부분조회·기존 수면/점수 상태.
- UI: 영향 화면의 `WellnessSeededSmokeTests`, `WellnessRegressionTests`와 새 `WellnessFlowUITests`; 공통 smoke는 adapter 판정/실제 소비자를 검토해 합집합. 전체 테스트는 별도 요청이 없어 자동 실행하지 않는다. 자동 full 판정은 실행하지 않은 범위로 명시한다.
- UI 판정: `python3 scripts/plan-ui-tests.py --base main`을 계획/최종 변경 상태에서 저장한다. iOS presentation/data assembler 소비자만 수정하며 Watch/Widget 점수·payload 변경은 피한다.
- 빌드: `scripts/build-ios.sh`; 번역은 format-xcstrings `--check` 전/후/빌드 후.
- 실제 화면: H01 iPhone/iPad/Duo 접힘·펼침, 밝음/어두움/큰 글씨 중 영향 상태. 표준 runner·전용 기기·순차 실행·deadline. CaptureTest/receipt와 새로운 PNG만 actual 디자인맵에 연결한다. 불가능한 상태는 이유/재개조건을 명시한다.
- 테스트/리뷰는 저장된 증거를 재사용하고 원인 변화가 있는 동일 실패만1회 재시도한다.

## Risks

| Risk | Mitigation |
|---|---|
| native가 시안 예시를 실측으로 오인 | 고정 fixture를 운영 코드에 넣지 않고 실제 model만 연결 |
| Query/scroll 피드백 | eager 배치·child Query 유지 |
| 비교 날짜 합성/단위 혼동 | 범위 query actual date·%p·DTO tests |
| 큰 글씨 값 축소 | 명시적 접근성 한 열·자연 높이 |
| 시뮬레이터 실행권/환경 장애 | registry·runner·receipt·재시도 한도, 독립 리뷰/문서 계속 진행 |

## Research / API Evidence

Repo/Solution/Best Practices 리서치를 병렬 실행했다. 관련 기존 brainstorm은2026-02-17/20/21 Wellness이며 현재 active TODO 중 Apple 수면 점수 비교는 미공개 API로 보류된 별개 범위다. BodyCompositionQuerying의 기존 범위 API를 사용한다. 공식 [Charts](https://developer.apple.com/design/human-interface-guidelines/charts), [Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility), [Tab bars](https://developer.apple.com/design/human-interface-guidelines/tab-bars)의 데이터 맥락·큰 글씨·상세 계층 원칙을 적용한다. 새 외부 API/스키마 도입은 없다.
