---
topic: workout-achievement-board
tags: [life, achievements, swiftui, design]
date: 2026-10-29
category: plan
status: implemented
confidence: high
related_solutions:
  - ../solutions/architecture/2026-03-22-auto-linked-habit-section-routing.md
  - ../solutions/general/2026-03-29-life-auto-achievement-healthkit-filter-bug.md
---

# Implementation Plan: 주간 운동 업적 성과 보드

## Context / Requirements

사용자가 [성과 보드 시안](../design/theme-map/themes/dune-workout-achievements.html)을 선택해 `/run` 적용을 요청했다. 기존 카드/막대 중첩을 큰 완료 수, 골드 메달·능선, 운동 횟수 분절, 근력 6항목 타일, 러닝 거리 곡선으로 바꾼다. 내 목표의 수정·이력·보관과 주간 도전 접기/펼치기를 보존한다. 날짜·단위·출처를 표시하고 오늘 자동 연동과 주간 도전의 기간을 구분한다.

## Approach

기존 LifeView의 자동 업적 표시를 feature 전용 컴포넌트로 추출한다. 기존 Domain service·dedup·ViewModel·SwiftData·HealthKit·집계는 변경하지 않는다. 기존 앱 테마 토큰을 사용하고 다른 테마에서는 해당 테마 accent/surface를 따른다. 실제 총 목표 수는 가변이며 시안의 10개를 하드코딩하지 않는다. 모든 근력 항목을 표시하고 새 모델의 그룹/안전 표시 계산만 단위 테스트한다.

### Alternatives

| 접근 | 판단 |
|---|---|
| 기존 카드에 색/간격만 변경 | 변화가 적다는 피드백을 해결하지 못해 제외 |
| 공유 디자인 시스템 전역 변경 | 다른 탭 영향이 크므로 제외 |
| feature 전용 성과 보드 | 선택, 앱 전체 테마와 데이터 계약 유지 |

## Affected Files

| File | Change | Description |
|---|---|---|
| `DUNE/Presentation/Life/LifeView.swift` | edit | 보드 연결, 기존 action 소유권 유지, 이전 표시 helper 제거 |
| `DUNE/Presentation/Life/WorkoutAchievementBoard.swift` | add | 선택 시안 네이티브 구현·접근성·반응형 |
| `DUNETests/WorkoutAchievementBoardTests.swift` | add | 표시 모델·가변 분모·빈 값·안전 비율 |
| `DUNEUITests/Visual/LifeFlowUITests.swift` | edit | seeded 요소·접기/펼치기·메뉴·기본/어두움/큰 글씨 캡처 |
| `Shared/Resources/Localizable.xcstrings` | edit | 필요한 en/ko/ja 문구 |
| `docs/design/layout-map/*` | edit | 선택한 배치의 실제 적용 상태 |
| `docs/design/phone-design-map/actual/*` 및 관련 갤러리 | edit | 영향 L01 새 캡처·출처·미검증 상태 |
| 시안 보존본·theme map·solution/review 문서 | edit | 선택/적용/검증 범위 기록 |

## Implementation Steps

1. 시안 산출물과 계획을 보존하고 `codex/workout-achievement-board` 브랜치 생성. 최신 origin/main의 문자열 변경을 기반으로 작업한다.
2. 단일 보드·동적 총계·내 목표 행·횟수 분절·근력 타일·거리 곡선을 구현한다. 메뉴는 기존 부모 소유권을 유지한다. 각 목표 상태·최고 연속 주 표시를 보존한다.
3. en/ko/ja와 표시 계산 테스트, 관련 UI 테스트를 갱신한다. 새 SF Symbol은 해상도 검증에 포함한다.
4. 표준 빌드/단위/UI 실행기로 관련 범위만 검증한다. iPhone 기본/어두움/최대 글씨, iPad, Duo 접힘/펼침은 L01 해당 영역만 새로 캡처한다. Watch는 소비자가 없어 제외한다. 한 번에 한 전용 기기만 실행한다.
5. diff 기반 5개 리뷰 관점과 SwiftUI/Apple UX/UI test 품질 검토, 발견사항 해결, Compound 문서, PR 생성·머지·소유 시뮬레이터 정리를 수행한다.

## Edge Cases

| Case | Handling |
|---|---|
| 사용자 목표 0개/여러 개 | 실제 총계 반영, 내 목표 영역 조건부 표시 |
| 0회·일부 완료·전체 완료 | 숫자/표식/텍스트 일치, 완료 목표 수만 채움 |
| 가슴/하체 0회 | 6개 근력 항목을 명시적으로 표시 |
| 7회 초과·15 km 초과 | 실제 수치 유지, 시각적 진행만 상한 제한 |
| 근력/러닝 그룹 데이터 없음 | 가짜 그룹/수치 생성 안 함 |
| 큰 글씨·regular 반폭 | 2열 또는 1열 전환·줄바꿈·장식 숨김 |
| 빈 DTO·0 분모·NaN | 안전한 표시와 빈 상태, 잘못된 숫자 변환 방지 |

## Testing Strategy

- `swift scripts/format-xcstrings.swift --check` 변경 전후·빌드 후.
- `scripts/build-ios.sh` Simulator 빌드; 관련 unit selector만 `scripts/test-unit.sh`로 실행.
- `scripts/plan-ui-tests.py --base main` 초기/최종 계획 저장. feature Life UI와 필요한 공통 smoke만 수행; 전체 회귀는 명시 요청이 없으므로 실행하지 않는다.
- 시뮬레이터 소유권/잠금/deadline 및 동일 원인 조건부 1회 재시도를 유지한다. 환경 실패는 미검증으로 기록하고 새 실행 증거 없이 반복하지 않는다.
- 실제 PNG는 시안 PNG와 구분하고 최신 실행 출처로 갤러리/포털을 갱신한다. 미수집 기기는 이유를 기록한다.

## Risks

| Risk | Mitigation |
|---|---|
| prototype의 10개/fixture를 운영 하드코딩 | 서비스 출력 기반 집계·단위 테스트 |
| 요일과 운동 횟수 혼동 | 분절은 회차, 월–일 기간 별도 표시 |
| 새 메달이 새로운 보상처럼 보임 | 장식 AX 제외, 완료 목표 수만 시각화 |
| 넓은 폭/큰 글씨 잘림 | feature 내 container 폭·Dynamic Type 대응 및 실제 캡처 |
| 기존 메뉴·연속 기록 기능 손실 | 부모 action 재사용, streak 노출 보존, UI 확인 |

## Confidence

높음. 표시 계층에 한정되며 기존 Domain/저장/운동 기록 경로를 바꾸지 않는다. 관련 기존 Life 설계·자동 연동 해결책을 실제 검색·검토했다. 새 API가 필요 없는 SwiftUI 기본 구성은 저장소의 Life 히어로·카드 패턴을 재사용한다.

## Execution

선택한 성과 보드를 적용했다. 새 표시 모델·52개 관련 단위 테스트·기존 목표 이력/접기 동작·기기별 캡처를 [실행 보고](../reviews/2026-10-29-workout-achievement-board/README.md)와 [실제 화면](../design/full-redesign-map/review/workout-achievement-board-2026-10-29/index.html)에 연결한다. 표준 unit 실행기가 selector를 지원하지 않아 기존 simulator lock/boot helper를 사용하는 bounded targeted xcodebuild fallback을 기록했다. 전체 회귀는 요청 범위가 아니므로 미실행이다.
