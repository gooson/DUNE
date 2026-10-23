---
topic: desert-horizon-final-implementation
date: 2026-10-24
status: blocked-ui-validation
confidence: high
related_solutions:
  - docs/solutions/general/2026-10-19-four-tab-hero-ring-parity.md
  - docs/solutions/general/2026-10-22-contextual-first-fold-hero.md
  - docs/solutions/general/2026-10-14-rest-live-activity-layouts.md
  - docs/solutions/general/2026-03-07-widget-density-improvement.md
---

# Implementation Plan: DESERT HORIZON 최종 방향 실제 구현

## Context

2026-10-24 대화에서 완성한 4탭 및 위젯·라이브 액티비티 시안을 실제 앱에 반영한다. 사용자가 `/run`으로 구현·검증·리뷰·문서화·Ship를 승인했다. 구현 중 캡처를 반복하지 않고 구현 완료 후 변경 범위만 최소 캡처한다.

## Requirements

- 비대칭 사구 곡선은 유지하면서 헤더에서 끊기는 채움·배경을 화면 전체 그라데이션으로 연결한다.
- 밝음·어두움의 카드 표면과 여백을 시안 방향으로 정돈한다. 기존 실제 데이터·링·근육 지도·기간 그래프·개인 기록·추천 운동·습관 입력·보고서 정보와 접근성을 보존한다. 시안의 임의 예시 데이터를 앱에 넣지 않는다.
- Today 상단은 알림·설정, 새 소식은 알림함 필터·읽음 상태·출시 상세로 통합한다. 별도 sparkles 진입과 자동 출시 시트의 중복 노출을 제거한다.
- Activity·Wellness·Life의 추가 경로는 상단 +를 사용하고 히어로·본문의 중복 기록 CTA를 정리한다.
- 운동 구성에 최근 4주 근력/유산소 건수, 주별 구성, 주요 부위별 완료 세트 환산 비율, 유산소 종류 및 기존 운동별 빈도를 추가한다. 요약/상세는 같은 데이터 소스와 분모를 사용한다.
- 라이브 액티비티의 실제 카운트다운·운동명·세트, Widget family와 구성 선택·누락 상태를 유지하며 테마 표면·색·여백을 적용한다.

## Approach

기존 feature 컴포넌트와 데이터 파이프라인을 재사용하고, 실제 앱에 없는 시안 데이터는 도입하지 않는다. 공통 배경·표면은 `.desertWarm`에 한정하고 타 테마는 기존 표현을 보존한다. 기록/알림 진입과 운동 구성은 실제 기능 개선으로 모든 테마에서 같은 행동을 제공한다.

| 대안 | 결정 |
|---|---|
| HTML 화면을 SwiftUI로 새로 재작성 | 기존 정보·동작 손실 위험으로 제외 |
| 현재 SwiftUI 구조의 계약 차이만 반영 | 채택: 기존 차트·입력·저장·내비게이션 재사용 |

## Affected Files

| 영역 | 파일 |
|---|---|
| 사구·카드 | `DUNE/Presentation/Shared/Components/DesertWaveBackground.swift`, `GlassCard.swift`, 관련 테마 asset/token |
| 루트 행동 | `ActivityView.swift`, `WellnessView.swift`, `LifeView.swift`, `DashboardView.swift` |
| 알림·새 소식 | `NotificationHubView.swift`, `DUNEApp.swift`, `SettingsView.swift`, WhatsNew store/manager와 관련 tests |
| 운동 구성 | `ActivityViewModel.swift`, `ExerciseMix/`, 기존 frequency summary, 필요 시 Domain composition model/service |
| Widget·Live Activity | `DUNEWidget/DesignSystem.swift`, `Views/`, `SingleMetricWidget.swift`, `WorkoutRestLiveActivity.swift` |
| 검증·문서 | 관련 DUNETests·DUNEUITests, Shared xcstrings, 테마·레이아웃·실제 화면맵 |

## Implementation Steps

1. 승인된 시안과 계획을 보존하고 공통 Desert 사구·전체 배경·불투명 카드 표면 및 여백을 반영한다.
2. 상단 기록 진입과 알림함의 새 소식을 통합한다. 출시 읽음과 건강 알림 읽음을 함께 관리하고 기존 목적지를 유지한다.
3. 운동 구성 집계와 요약/상세 차트, 목적이 맞는 부족한 보조 차트를 실제 데이터로 구현한다. 기존 세부 정보를 제거하지 않는다.
4. Widget·Live Activity에 테마 표면·상태색·안전한 세로 레이아웃과 크기별 가독성을 적용한다.
5. 각 논리 단위를 커밋하고 iOS/Widget 빌드, 관련 unit/UI 테스트를 실행한다. UI test expert가 기존 시나리오를 보강한다.
6. 구현 완료 후 전용 시뮬레이터의 영향받는 화면만 새로 캡처한다. 이미지는 디스크에서 합본으로 만들어 한 번에 검사하고 필요한 실패 영역만 추가 확인한다. 실제 화면맵과 시안의 차이를 같은 작업에서 해소한다.
7. 5관점 리뷰와 SwiftUI·Apple UX·종합 품질 검토, 발견사항 수정, Compound 문서, PR 생성·병합·정리.

## Edge Cases

| 경우 | 처리 |
|---|---|
| 점수/기록 일부·전체 누락 | 임의 링 값·추세 생성 없이 기존 빈 상태와 상단 추가 경로 유지 |
| 출시 카탈로그 없음/빌드 번호 없음 | 새 소식 필터의 실제 빈 상태, 건강 알림은 계속 사용 |
| 출시 미열람 + 건강 알림 미열람 | 배지 합산, 모두 읽음은 두 저장소를 함께 갱신 |
| 장문·접근성 글씨 | 카드 전체 폭 줄바꿈, 링과 문구의 세로 전환, 고정 높이로 잘림 금지 |
| 복수 주요 근육·미분류 운동 | 완료 세트를 균등 배분, 미분류 분모 명시, 중복 합산 방지 |
| 수동 + HealthKit 같은 운동 | 현재 merge/dedup 계약 재사용, 요약/상세 parity |
| Dynamic Island 제한 폭·Watch small | 기존 family 감지와 countdown interval 유지 |

## Testing Strategy

- Unit: 구성비·세트 분모·기간·중복·누락, 새 소식 읽음/배지/필터, Widget 상태의 기존 계약 회귀.
- Integration: `scripts/build-ios.sh`, Widget가 포함된 target 빌드, 문자열 포맷 check.
- UI: 최종 `scripts/plan-ui-tests.py --base main` 결과를 검토한다. 전역 테마 변경은 full 영향으로 기록하되 사용자 요청에 따라 영향받는 targeted suite만 실행하고 full 미실행을 명시한다. 테스트는 표준 runner와 worktree 소유 simulator를 사용한다.
- Capture: iPhone 4탭과 알림/운동 구성·Widget 대표 family, iPad·Duo 접힘/펼침의 영향 레이아웃, Live Activity 시스템 호스트의 실제 진입 가능한 대표 상태. 기본/밝음·어두움/큰 글씨는 기존 parameterized 테스트에 묶고 합본으로 육안 확인한다. 캡처 실패는 상태·기기와 원인을 기록하며 구 PNG를 새 증거로 재사용하지 않는다.
- 전체 회귀는 별도 요청이 없어 실행하지 않는다. 동일 실패는 원인 수정 후 최대 1회 재시도하며 무관한 실패로 범위를 확장하지 않는다.

## Risks

| 위험 | 대응 |
|---|---|
| material이 배경을 비쳐 글자 대비 저하 | Desert만 semantic asset 기반 안정된 표면·테두리 사용 |
| 화면별 기능이 시안 간결화로 누락 | 기존 component 유지, API·목적지 체크리스트로 대조 |
| 시스템 Widget/Live Activity 캡처 제약 | 앱 내 fixture를 실제 시스템 캡처로 표시하지 않고 시스템 증거는 별도 추적 |
| 공유 호스트 정체 | 표준 timeout·단일 시뮬레이터 실행, 실패 범위 명시 |

## Execution Notes

- 초기 상태: detached HEAD `06380d95`, 기존 디자인 문서/HTML 변경은 본 대화의 승인 시안으로서 이번 작업에 포함한다. 그 밖의 선행 변경은 자동 포함하지 않는다.
- 구현 브랜치: `codex/desert-horizon-final-implementation`; 검증·Ship 브랜치: `codex/desert-horizon-final-ship`. 원래 작업 트리에 다른 작업의 변경이 시작되어 `53fd5c2d`에서 독립 관리 워크트리를 만들었다. 다른 작업의 파일은 포함하거나 되돌리지 않는다.
- Plan 조사: docs/solutions, docs/brainstorms, todos, 실제 View/Widget 소스 및 기존 Apple Live Activities/Widgets 공식 문서를 대조했다. 초기 UI plan은 `.codex-checks`에 최종 plan과 함께 보존한다.
- Phase: Init·Plan·Work 완료. 최종 제품 빌드(c239a50d)·단위 테스트58개 통과. UI Test는 Duo 펼침 Today의 표시 회전/실제 가로 viewport 조건 실패로 차단됐다. Mac 잠금 해제 후 Device Hub 확인이 재개 조건이며 Review 이후 단계·PR·머지는 미실행이다.
- 통합 iOS/Widget 빌드 성공(`c4d07845` 앱 소스), 영향 단위 테스트 7개 suite 58/58 통과. 첫 iPhone targeted UI는 15개 중 10개 통과·5개 실패: 한국어 새 소식 필터 선택과 자식 접근성 식별자 덮어쓰기가 원인이었다. `1c4cdd88`에서 수정 후 실패 5개·관련 보강 2개만 재검증한다.
- 4탭 밝음·어두움 및 최대 접근성 크기 실제 캡처는 개별 통과한 ThemeMatrix 메서드에서 얻었다. 결과 번들 전체가 통과했다는 증거로 사용하지 않는다. 출처는 새 캡처 갤러리에 개별 기록한다.
