---
tags: [watchos, workout, ux, design-system, rest-timer, controls]
date: 2026-10-12
category: plan
status: implemented
confidence: medium
related_plans:
  - docs/plans/2026-02-18-watch-design-overhaul.md
related_solutions:
  - docs/solutions/general/2026-10-06-watch-workout-density-and-autosave.md
  - docs/solutions/architecture/2026-02-27-watch-equipment-icon-patterns.md
---

# Implementation Plan: Watch 운동 화면 재설계

## Context

기존 DUNE Watch 운동 화면의 휴식 타이머, 시작 오류, 근력 제어에서 정보 밀도와 버튼 위계 문제가 확인되었다. 이 문서는 Apple Watch 운동 화면의 **단일 디자인 기준안**과 전체 상태 목록을 보존해 후속 구현과 리뷰에 재사용한다.

산출물: [한 장짜리 디자인 보드](../design/watch-workout/watch-workout-design.png) · [편집용 SVG](../design/watch-workout/watch-workout-design.svg) · [재생성 스크립트](../design/watch-workout/build-watch-workout-design.py)

## 범위와 상태

보드에는 홈 → 운동 미리보기/시작 오류 → 현재 세트/휴식/RPE → 유산소 지표 → 근력·유산소 제어 → 완료/저장 오류의 **대표 12개 상태**를 넣었다. 아래에는 실제 `DUNEWatch/` 코드에서 확인한 **62개 상태·구현 분기**를 남겼다. S06 시간 입력은 구현 분기만 있고 현행 운동 흐름에서 열리지 않는다. 대표 12개 밖의 상태는 기존 조건 분기와 화면군 규칙을 따라 적용했다. 개별 상태별 PNG 62장은 제작하지 않았으며, 실제 동작 검증 범위는 하단에 별도 기록한다.

## 공통 디자인 규칙

| 구간 | 정보와 조작 규칙 |
|---|---|
| 홈·탐색·자세 H/D/G | 운동명과 장비/활동 아이콘을 함께 표시한다. 빈 목록·연결 실패는 해당 화면 안의 짧은 상태 문구와 다음 행동으로 처리한다. |
| 미리보기·시작 P | 운동 종류 → 구성 → 시작 순서로 읽힌다. P05 오류는 미리보기 맥락을 유지하고 짧은 오류 문구와 다시 시도를 둔다. |
| 운동 제어 X | 일시정지/재개와 종료를 위 행의 큰 버튼으로, 건너뛰기·순서 변경을 아래 행으로 배치한다. 유산소에는 위 두 버튼만 세로로 확장한다. 종료 확인은 유지한다. |
| 근력 세트·입력 S | 장비 아이콘/운동명 → 현재 수치 → 완료 행동 순서다. 중량·반복·시간·라운드 유형을 분리하고 입력 값은 Digital Crown으로 조절한다. |
| 휴식 S09–S11/S16 | 남은 시간 → 심박 → RPE 순서다. RPE 편집은 별도 상태로 이동한다. `+30초`·건너뛰기, 10분 상한, 심박 없음, AOD를 유지한다. |
| 유산소 C | 현재 핵심 지표 하나를 가장 크게, 보조 지표 둘을 아래에 표시한다. 심박 구간·상세·제어는 인접 페이지다. |
| 완료·저장 F | 총 시간 → 완료 수치 → 강도·완료 순서다. 저장 오류는 결과 수치를 가리지 않고 다시 시도를 제공한다. |

장비가 있는 운동은 `DUNEWatch/Views/Components/EquipmentIcon.swift`의 실제 asset/fallback 매핑을 따른다. 유산소 활동 아이콘은 현행 활동 종류의 SF Symbol 매핑을 재사용한다. 보드의 활동 그림은 방향을 보여주는 벡터다. 일곱 테마는 같은 화면 구조를 공유하고 색 토큰으로 바꾼다.

## 치수와 색

보드는 실제 시뮬레이터 캡처와 같은 **374×446px 시각 캔버스**로 그렸다. 이는 watchOS의 pt가 아니다. 2배율 화면에서 X01 제목 32px은 약 16pt, 주요 버튼 문구 29px은 약 14.5pt이다. X01은 가로 바깥 여백 22px, 두 열 사이 24px, 행 사이 23px을 사용한다. 상단 버튼은 153×150px, 하단 버튼은 153×105px이다. 구현 시 44×44pt 이상의 실제 터치 영역, 작은 워치의 안전 영역, Dynamic Type, 긴 운동명을 확인해야 한다.

| 역할 | 기준색 |
|---|---|
| 배경 / 보조 표면 | `#030606` / `#142025`, `#223137` |
| 기본 / 보조 글자 | `#F4F8F7` / `#A9BBBE` |
| 진행·주 행동 | `#23D4CA` |
| 심박 / 종료 / 장비 | `#FF6F88` / `#FA5B62` / `#DBA881` |

숫자는 시안값이다. 앱 구현에서는 `DUNEWatch/DesignSystem.swift`의 `DS.Color`, `DS.Spacing`, `DS.Typography`와 `AppTheme+WatchView.swift`의 테마 환경값에 연결한다. 현재 `DS.Color.positive`는 시안의 청록색 `#23D4CA`와 별도 토큰이다. 화면 색을 바꿀 때 기존 의미색의 용도를 확인하고 워치 운동 전용 토큰이 필요한지 결정한다. 상태는 색에만 의존하지 않고 문구와 기호로도 알려준다.

## Affected Files

아래는 적용 화면군과 검증 경계다. 운동 기록·HealthKit 저장 로직은 유지하고 SwiftUI 표시 및 접근성만 수정했다.

| File | Change Type | Description |
|---|---|---|
| `DUNEWatch/DesignSystem.swift`, `DUNEWatch/Views/Extensions/AppTheme+WatchView.swift` | 기존 토큰 재사용 | 전역 테마 구조와 간격 값은 변경하지 않음 |
| `DUNEWatch/Views/CarouselHomeView.swift`, `QuickStartAllExercisesView.swift`, `PostureMonitorSettingsView.swift`, `Components/` | 수정 | H/D/G 아이콘, 선택 위계, 빈 상태·동기화 상태 적용 |
| `DUNEWatch/Views/WorkoutPreviewView.swift` | 수정 | P01–P05 구성, 44pt 레벨 제어, 시작 오류의 화면 내 재시도 |
| `DUNEWatch/Views/ControlsView.swift`, `WatchExerciseReorderView.swift` | 수정 | X01–X06 버튼 위계, 44pt 이동 제어, 종료 확인 유지 |
| `DUNEWatch/Views/MetricsView.swift`, `SetInputSheet.swift`, `RestTimerView.swift` | 수정 | S01–S17 수치·입력·휴식 위계, 장비 아이콘, AOD |
| `DUNEWatch/Views/Cardio/` | 수정 | C01–C12 지표 카드 밀도와 기계 레벨 44pt 제어. `SessionPagingView`의 내비게이션·자동 종료 경로는 유지 |
| `DUNEWatch/Views/SessionSummaryView.swift` | 수정 | F01–F07 시간 중심 요약과 화면 내 저장 재시도. 자동 저장 동작은 유지 |
| `DUNEWatch/Resources/Localizable.xcstrings`, `DUNEWatchUITests/` | 수정 | 추가 접근성 문구의 한국어·일본어 번역과 터치·viewport 회귀 테스트 |

## Implementation Steps

1. **공통 기준을 고정한다.** 시안 픽셀을 SwiftUI pt로 그대로 복사하지 않는다. 실제 워치 크기의 안전 영역, Dynamic Type, `DS`와 테마 색 대비를 확인하고 숫자·행동·상태 컴포넌트의 공통 규칙을 정한다.
2. **화면군별로 적용한다.** 아래 62개 상태 코드를 체크리스트로 사용해 H/D/G → P → X/S/C → F 순서로 구현한다. 보드에 없는 상태도 해당 화면군의 규칙과 실제 조건 분기를 따른다.
3. **기존 동작을 보존한다.** 장비별 asset/fallback, 유산소 활동 기호, 휴식 10분 상한, 종료 확인, RPE 저장, 요약 진입 시 자동 저장과 저장 재시도를 유지한다. 관련 기존 구현 설명은 [운동 밀도·자동 저장](../solutions/general/2026-10-06-watch-workout-density-and-autosave.md), [장비 아이콘](../solutions/architecture/2026-02-27-watch-equipment-icon-patterns.md)을 따른다.
4. **화면을 검증한다.** 작은 워치와 큰 워치에서 44×44pt 이상 hit region, 긴 한국어/영어 이름, VoiceOver 순서, Digital Crown 포커스, 심박 미측정, AOD, 시작·저장 오류, 색 대비와 상태 문구를 확인한다. 실제 UI 테스트와 스크린샷을 시안과 대조한다.
5. **구현 결과를 문서화한다.** 화면별 차이를 이 계획에 반영하고, 병합된 동작만 `docs/solutions/`에 Problem / Solution / Prevention 형식으로 남긴다. 시안 파일은 기존 파일명을 갱신해 버전별 복제본이 다시 쌓이지 않게 한다.

## 구현 검증 계약

- **기능**: 상태표의 현행 진입·전환·저장 경로를 유지하면서, 시작/운동/휴식/유산소/완료 화면에 공통 타이포그래피, 의미색, 행동 우선순위를 적용한다. 아이콘은 `EquipmentIcon`과 기존 활동 SF Symbol 매핑을 실제 화면에 사용한다.
- **비기능**: 40 mm급 작은 화면과 큰 화면, 한국어·영어 긴 문구, Dynamic Type, AOD, VoiceOver, 터치 영역을 확인한다. 개인정보·운동 기록·HealthKit 저장 로직은 디자인 범위 밖에서 유지한다.
- **선택한 접근**: 기존 상태별 SwiftUI View와 조건 분기를 보존하고 공통 토큰/작은 컴포넌트를 재사용한다. 62개 View를 새로 만들면 내비게이션과 저장 경로의 회귀 위험이 커진다. 전역 간격 일괄 확대는 작은 워치에서 잘림을 만들 수 있어 화면별 기하를 조정한다.
- **단계별 확인**: (1) 토큰과 컴포넌트는 Watch 빌드, (2) 시작·제어·세트·휴식·유산소·요약은 해당 seeded UI selector와 접근성 ID, (3) 최종 통합은 `scripts/build-ios.sh`와 `scripts/plan-ui-tests.py --base main`의 코드 영향 범위에 있는 Watch 테스트로 확인한다. 문서·시안 이미지가 테스트 판정기의 전체 fallback을 유발해도 실제 Swift 소비자 검색으로 iOS 영향 여부를 별도 판정한다.
- **엣지 케이스**: 심박 없음은 `--`와 접근성 문구, 휴식 +30초는 600초 상한, 종료 확인 취소는 타이머 지속, 시작/저장 오류는 기존 맥락과 재시도, 마지막 세트/운동은 가능한 행동만 노출, AOD는 과도한 장식·애니메이션 제거.
- **주요 위험**: (높음) 화면 밀도 변경으로 작은 워치 overflow → `ViewThatFits`/스크롤 fallback과 viewport 검증. (중간) 테마별 대비 저하 → 의미색의 테마 변형 확인. (중간) UI selector 회귀 → 기존 AXID 유지. (높음) 결과 저장 중복/손실 → 요약의 상태 로직 보존, UI/단위 검증.
- **확신도**: 중간. 현재 코드와 12개 시안 및 62개 상태 맵은 확보했지만, 최종 크기·Crown·AOD는 시뮬레이터와 실기기에서 확인해야 한다.

## 전체 62개 상태 대조표

| 코드 | 상태 | 코드 영역 |
|---|---|---|
| H01 | 루틴 카드 | `CarouselHomeView` |
| H02 | 최근 카드 | `CarouselHomeView` |
| H03 | 선호·인기 카드 | `CarouselHomeView` |
| H04 | 전체 운동 카드 | `CarouselHomeView` |
| H05 | 홈 빈 상태 | `CarouselHomeView` |
| D01 | 운동 목록 | `QuickStartAllExercisesView` |
| D02 | 검색 | `QuickStartAllExercisesView` |
| D03 | 분류 필터 | `QuickStartAllExercisesView` |
| D04 | 검색 결과 없음 | `QuickStartAllExercisesView` |
| D05 | 동기화 빈 상태 | `WatchSyncStatusView` |
| D06 | 연결 실패 | `WatchSyncStatusView` |
| G01 | 자세 모니터 꺼짐 | `PostureMonitorSettingsView` |
| G02 | 자세 모니터 켜짐 | `PostureMonitorSettingsView` |
| G03 | 자세 통계 하단 | `PostureMonitorSettingsView` |
| P01 | 근력 시작 전 | `WorkoutPreviewView` |
| P02 | 시작 전 순서 변경 | `WorkoutPreviewView` |
| P03 | 유산소 실내·실외 | `WorkoutPreviewView` |
| P04 | 기계 레벨 | `WorkoutPreviewView` |
| P05 | 시작 오류 | `WorkoutPreviewView` |
| X01 | 근력 제어 | `ControlsView` |
| X02 | 일시정지·재개 | `ControlsView` |
| X03 | 유산소 제어 | `ControlsView` |
| X04 | 운동 중 순서 변경 | `WatchExerciseReorderView` |
| X05 | 운동 종료 확인 | `ControlsView` |
| X06 | 세트 없는 종료 | `ControlsView` |
| X07 | 지금 재생 중 | 시스템 `NowPlayingView` 연결 |
| S01 | 중량 + 반복 | `MetricsView` |
| S02 | 반복만 | `MetricsView` |
| S03 | 시간 운동 | `MetricsView` |
| S04 | 중량 입력 | `SetInputSheet` |
| S05 | 반복 입력 | `SetInputSheet` |
| S06 | 시간 입력 구현 분기(현행 흐름 미노출; S03은 실시간 타이머) | `SetInputSheet` |
| S07 | 중량 제안 | `SetInputSheet` |
| S08 | 이전 세트 | `SetInputSheet` |
| S09 | 휴식 타이머 | `RestTimerView` |
| S10 | 휴식 중 RPE | `RestTimerView` / RPE 입력 |
| S11 | 휴식 AOD | `RestTimerView` |
| S12 | 마지막 세트 선택 | `MetricsView` |
| S13 | 마지막 세트 RPE | `MetricsView` / RPE 입력 |
| S14 | 다음 운동 | `MetricsView` |
| S15 | 맨몸 + 추가 중량 | `SetInputSheet` |
| S16 | 심박 미측정 | `RestTimerView` |
| S17 | 라운드형 운동 | `MetricsView` |
| C01 | 달리기 메인 | `CardioMainMetricsPage` |
| C02 | 기계 운동 메인 | `CardioMainMetricsPage` |
| C03 | 심박 구간 | `CardioHRZonePage` |
| C04 | 달리기 상세 | `CardioSecondaryPage` |
| C05 | 사이클 상세 | `CardioSecondaryPage` |
| C06 | 수영 상세 | `CardioSecondaryPage` |
| C07 | 일반 상세 | `CardioSecondaryPage` |
| C08 | 움직임 없음 | `SessionPagingView` |
| C09 | 자동 종료 예고 | `SessionPagingView` |
| C10 | 계단 운동 진행 중 (종료 추정 알림 없음) | `CardioMainMetricsPage` |
| C11 | 기계 운동 상세 | `CardioSecondaryPage` |
| C12 | 유산소 AOD | `CardioSecondaryPage` |
| F01 | 근력 요약 | `SessionSummaryView` |
| F02 | 유산소 요약 | `SessionSummaryView` |
| F03 | 운동별 세트 내역 | `SessionSummaryView` |
| F04 | 전체 강도 입력 | `SessionSummaryView` |
| F05 | 저장 중 | `SessionSummaryView` |
| F06 | 저장 오류 | `SessionSummaryView` |
| F07 | 계단 운동 요약 | `SessionSummaryView` |

운동명과 데이터 값만 다른 같은 템플릿은 상태 수를 늘리지 않았다. 워치용 운동 기록 목록·상세 라우트와 일반 운동 설정 라우트는 현행 앱에 없다. S06은 `SetInputSheet` 코드 분기지만 `MetricsView`에서 시간 운동을 실시간 타이머로 처리하므로 사용자 진입 경로가 없다. 세트 입력·RPE·강도 입력·순서 변경은 시트 또는 상태이며, Now Playing은 시스템 화면이다.

## 조사 근거와 검증

Apple [Designing for watchOS](https://developer.apple.com/design/human-interface-guidelines/designing-for-watchos), [Workouts](https://developer.apple.com/design/human-interface-guidelines/workouts), [Buttons](https://developer.apple.com/design/human-interface-guidelines/buttons), [Alerts](https://developer.apple.com/design/human-interface-guidelines/alerts)를 기준으로 조작 밀도와 오류 표현을 검토했다. Athlytic의 [운동 화면](https://athlyticapp.com/assets/watch/workout-1.png)에서는 링이 이미지 가로의 약 66.4%, Gentler Streak의 [운동·제어 화면](https://docs.gentler.app/using-gentler-streak-on-your-apple-watch/overview-of-the-apple-watch-app-interface)에서는 주요 제어 높이가 약 24.7%였다. 이 수치는 공개 이미지 픽셀의 수동 측정이며 앱의 pt 규격이 아니다. 원본과 DUNE 시뮬레이터 캡처는 [자료 폴더](../design/watch-workout/)에 보관했다.

Apple의 [디자인 원칙](https://developer.apple.com/design/human-interface-guidelines/design-principles)을 구현 판단에 다음처럼 적용했다.

| 원칙 | 이번 화면에서 확인한 기준 |
|---|---|
| Purpose | 현재 세트나 남은 시간처럼 운동 중 즉시 필요한 숫자를 가장 먼저 읽는다. |
| Agency | 휴식 연장·건너뛰기, 시작 실패 뒤 실내·실외 재선택과 재시도를 제공한다. |
| Responsibility | 운동 종료를 확인하고 저장 실패를 숨기지 않으며 명시적인 재시도와 저장하지 않고 나가기 경로를 둔다. |
| Familiarity | Digital Crown 입력, 워치 페이지 전환, 시스템 종료 확인을 유지한다. |
| Flexibility | 작은 화면과 큰 글씨에서 세로 스크롤로 아래 지표에 접근하고 주요 버튼은 최소 44pt를 목표로 한다. |
| Simplicity | 가능한 행동만 보여주고 보조 행동이 없는 제어 화면은 두 주요 버튼으로 구성한다. |
| Craft | 시안의 픽셀값과 실제 워치 pt를 구분하고 시뮬레이터 프레임과 캡처를 대조한다. |
| Delight | 완료·실패 햅틱과 수치 변화만 사용하고 AOD·동작 줄이기에서는 장식을 억제한다. |

SVG를 PNG로 렌더링하고 12개 대표 화면의 배치를 시각 확인했다. 실제 SwiftUI 구현 후 `scripts/build-ios.sh` 빌드를 통과했다. [최종 휴식 화면 캡처](../design/watch-workout/simulator-evidence/watch-rest-timer-final.png), [근력 제어](../design/watch-workout/simulator-evidence/watch-controls-final.png), [저장 오류](../design/watch-workout/simulator-evidence/watch-save-error-final.png)는 40mm Apple Watch SE 3 시뮬레이터에서 캡처했고 시안과 실제 정보 순서를 대조했다.

선택한 Watch UI 검증은 42mm에서 8/8과 2/2, 40mm에서 5/5가 통과했다. 최종 링 크기 변경 뒤의 40mm 휴식·정상 완료 테스트도 각각 통과했으나, 같은 배치의 첫 유산소 테스트는 시뮬레이터 앱 실행 대기 시간 초과로 중단됐다. 재부팅과 앱 직접 실행 확인 후 해당 유산소 지표·한국어 제목 테스트를 단독 재실행해 1/1 통과했다. 이 범위는 대표 화면의 viewport, 버튼 접근, 시작·저장 오류 복구, 세트·휴식·완료 흐름을 검증한다. 전체 상태 각각의 시각 렌더링과 실제 기기의 터치·Crown·AOD·VoiceOver 검증은 별도 수동 검증 항목이다.

## 후속 재사용 방법

새 워치 운동 화면을 수정할 때 먼저 위 상태 코드와 화면군 규칙을 찾고, 기존 `DS` 토큰과 아이콘 매핑에 연결한다. 시안 자체를 고치면 저장소 루트에서 `python3 docs/design/watch-workout/build-watch-workout-design.py`를 실행해 동일한 PNG·SVG를 갱신한다. 스크립트는 현재 저장소의 장비 asset을 자동으로 찾으며 PNG 렌더링에는 `rsvg-convert`가 필요하다. 화면 구현이 달라지면 본 문서의 상태 목록·규칙·검증 결과를 같은 변경에서 갱신한다.
