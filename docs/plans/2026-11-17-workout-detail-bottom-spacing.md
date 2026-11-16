---
topic: workout-detail-bottom-spacing
date: 2026-11-17
status: approved
confidence: high
tags: [swiftui, workout-detail, spacing, tab-bar]
category: plan
related_solutions: [2026-11-04-watch-summary-bottom-spacing]
related_brainstorms: []
---

# 운동 상세 하단 여백

## Context

달리기 HealthKit 운동 상세(W28)를 끝까지 스크롤하면 마지막 심박수 구간 카드와 떠 있는 탭 바가 붙어 보인다. 현재 콘텐츠에는 가로 padding만 있고 하단 padding이 없다. 기존 Watch 해결책은 끝까지 스크롤한 실제 배치 검증의 참고이며 고정 버튼 inset 구현을 그대로 이식하지 않는다.

## Requirements / Approach

W28 콘텐츠 스택에 `DS.Spacing.xxl`(24pt) 하단 padding을 추가한다. 시스템 safe area와 탭 바 배치는 유지한다. 마지막 섹션이 날씨이거나 구간 데이터가 없어도 같은 끝 여백을 적용한다. 탭 바 높이를 하드코딩하거나 전역 TabView를 수정하는 대안은 영향 범위가 커 제외한다.

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| DUNE/Presentation/Exercise/HealthKitWorkoutDetailView.swift | 수정 | 스크롤 콘텐츠 끝 24pt 여백 |
| DUNEUITests/Full/WorkoutZoneDetailUITests.swift | 수정 | seeded 상세 끝의 카드·탭 간격 회귀 검사 |
| docs/design/layout-map/healthkit-workout-detail-w28.html | 수정 | 끝 여백 배치 계약 |
| docs/design/phone-design-map/actual/ | 추가·연결 | 새 W28 실제 캡처와 출처 |
| docs/solutions/general/2026-11-17-workout-detail-bottom-spacing.md | 추가 | 최종 해결 및 검증 범위 |

## Implementation Steps

1. W28 배치 맵에 24pt 콘텐츠 끝 여백을 기록하고 앱 modifier 한 줄을 적용한다.
2. 기존 imported-workout fixture로 맨 아래까지 스크롤하고 카드와 탭 바가 떨어져 있는지 검사한다. 스크린샷을 수집한다.
3. 화면 코드·HIG·테스트 관점 및 5개 코드 관점 리뷰 후 발견 사항을 해결한다. 문서화하고 PR을 머지한다.

## Testing Strategy

- UI 선택: `DUNEUITests/WorkoutZoneDetailUITests`의 구간 표시·끝 여백 검사. 일반 iPhone부터 실행하며 동일 target 컴파일 성공을 빌드 증거로 재사용한다.
- 영향: iOS W28을 쓰는 iPhone·iPad·Duo; Watch/visionOS 소비자는 없다. 기본 iPhone 실제 하단 간격과 iPad 상단 탭 형태를 확인하고, Duo는 전용 기기/CLI 사용 가능 여부에 따라 미검증 범위를 명시한다.
- 단위: 비즈니스 로직 변화가 없어 추가하지 않는다.
- 표준 `scripts/test-ui.sh`, 전용 소유 시뮬레이터, jobs 2, deadline 1200초, 실행 한 번에 하나. 같은 실패는 원인 해결 후 1회만 재시도한다.

## Edge Cases / Risks

| Case | Handling |
|------|----------|
| 심박 구간 없음 / 날씨가 마지막 | 특정 카드 대신 콘텐츠 스택에 padding |
| iPad 상단 탭 바 | 하단 탭 비교를 강제하지 않음 |
| 큰 글씨·짧은 화면 | 기존 스크롤과 자연스럽게 함께 이동하는 여백 |
| 탭 바 겹침이 단순 padding으로 해소되지 않음 | 실제 frame/PNG로 판단한 뒤 현재 변경 범위 내 수정 |

## Confidence Assessment

높음. 원인은 하단 padding 누락이며 스크롤 끝의 배치를 직접 검사한다. 실제 HealthKit 데이터는 fixture 검사와 별개다.

## 검증 보완

초기 AX에서 구간 카드 ID가 내부 라벨에 전파되고 검사가 제목 frame만 측정한 것을 확인했다. 카드에 children: .contain 그룹을 지정해 실제 카드 frame과 기존 출처/구간 ID를 보존한다. 이 변경 뒤 기존 출처 검사 통과(52.235초)를 확인했다.

Activity의 seeded recent 목록에는 advanced strength fixture가 없어 해당 진입 검사를 시작 직후 중단했다. 최종 계약은 이미 검증된 알림 workout route의 직접 push로 바꾸며, 이 fixture의 마지막 Weather 카드 전체를 측정한다. 동일 콘텐츠 끝 padding이 마지막 심박 구간/날씨에 적용되므로 고정 하단 탭 바와의 충돌을 이 fixture로 검증한다. 초기 sheet PNG는 최종 탭 바 증거에서 제외한다. 새로운 정확한 selector 2건만 실행하며 기존 class 실행의 실패/중단 기록을 보존한다.
