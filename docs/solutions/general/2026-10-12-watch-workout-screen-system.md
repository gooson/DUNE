---
tags: [watchos, swiftui, workout, design-system, dynamic-type, accessibility, ui-test]
category: general
date: 2026-10-12
status: implemented
severity: important
related_files:
  - DUNEWatch/Views/RestTimerView.swift
  - DUNEWatch/Views/ControlsView.swift
  - DUNEWatch/Views/Cardio/CardioMainMetricsPage.swift
  - DUNEWatch/Views/WorkoutPreviewView.swift
  - DUNEWatch/Views/SessionSummaryView.swift
  - docs/plans/2026-10-12-watch-workout-redesign.md
related_solutions:
  - docs/solutions/general/2026-10-06-watch-workout-density-and-autosave.md
---

# Solution: Watch 운동 화면의 공통 위계와 작은 화면 대응

## Problem

### Symptoms

- 휴식 타이머의 시간과 심박이 작은 링 안에 몰리고, 조작 버튼이 화면 아래에서 잘릴 수 있었다.
- 운동 제어는 보조 행동이 없는 경우에도 버튼 두 개를 한 행에만 두어 넓은 빈 공간이 생겼다.
- 유산소 화면은 고정 높이 지표 행이 작은 워치와 큰 글씨에서 아래쪽 지표를 가릴 수 있었다.
- 시작 오류 뒤에는 실패한 실내·실외 모드만 다시 시도할 수 있었고, 저장 오류는 강도 입력 시트나 스크롤 위치에 가려질 수 있었다.
- 여러 시안 파일과 화면별 근거가 흩어지면 후속 변경에서 현재 기준을 찾기 어려웠다.

### Root Cause

화면별로 정보 위계와 최소 터치 영역을 독립적으로 정해 실제 워치 viewport의 높이와 콘텐츠 분기를 함께 계산하지 않았다. 오류 복구를 단일 행동으로 축약하면서 사용자가 다른 선택으로 돌아갈 경로도 잃었다. 시안과 구현 증거의 갱신 경로가 분리되어 오래된 캡처가 남았다.

## Solution

### Changes Made

| File | Change | Reason |
|---|---|---|
| `RestTimerView.swift` | 시간·심박·RPE를 링 안에 순서대로 표시하고 작은 링에서는 타이머 글자와 제안 문구를 줄임. `+30초`와 건너뛰기는 44pt 이상 | 남은 시간과 즉시 행동을 함께 읽고 누를 수 있도록 함 |
| `ControlsView.swift` | 근력 조작에 제목·운동명을 표시. 보조 행동이 있으면 두 행, 없으면 주요 버튼을 세로 배치 | 실제 행동 수에 맞춰 빈 공간을 줄임 |
| `CardioMainMetricsPage.swift`, `CardioHRZonePage.swift` | 세로 스크롤을 허용하고 콘텐츠보다 화면이 클 때 바운스를 억제 | 작은 워치와 큰 글씨에서도 아래 지표에 접근 |
| `WorkoutPreviewView.swift` | 시작 오류를 화면 안에 표시하면서 실내·실외 선택을 유지 | 실패 후 다른 모드로 회복 가능 |
| `SessionSummaryView.swift` | 시간 우선 요약, 화면 안 오류 설명과 하단 고정 재시도, 접근성 포커스와 오류 햅틱 | 강도 시트나 스크롤 뒤에서도 저장 실패를 인지하고 복구 |
| `CardioMainMetricsPage.swift`, `DUNEWatch/Resources/Localizable.xcstrings` | 활동명을 번역 키로 렌더링하고 공용 카탈로그의 한국어·일본어 활동명 번역을 Watch에 반영 | 유산소 제목이 시스템 언어에 맞게 표시 |
| `docs/plans/2026-10-12-watch-workout-redesign.md`, `docs/design/watch-workout/` | 12개 대표 상태 보드, 62개 코드 상태·구현 분기 대조표, 재생성 스크립트와 실제 캡처를 하나의 경로에 유지 | 다음 화면 변경 때 기준과 실제 구현을 대조 |

### Key Code

```swift
ScrollView(.vertical) {
    VStack(spacing: DS.Spacing.md) {
        activityHeader
        elapsedTimeDisplay(now: context.date)
        bottomRow
    }
}
.scrollBounceBehavior(.basedOnSize)
```

운동 세션의 가로 페이지 전환은 유지하고, 각 지표 페이지 안에서 높이가 넘칠 때만 세로로 탐색한다. 시간 운동은 `MetricsView`의 실시간 타이머가 현행 경로이며, `SetInputSheet`의 시간 입력 분기는 현재 직접 열리지 않는다는 점을 상태표에 명시했다.

## Prevention

### Checklist Addition

- [ ] 화면에 실제로 나타나는 행동 수가 달라질 때 각 분기의 제목·버튼 배치와 빈 공간을 캡처로 확인한다.
- [ ] 작은 워치와 큰 글씨에서 첫 viewport의 필수 행동이 보이는지, 나머지 정보는 스크롤로 도달하는지 확인한다.
- [ ] 오류 상태는 실패한 선택을 재시도하고 다른 선택으로 돌아가는 경로를 모두 제공하는지 확인한다.
- [ ] 44pt 터치 영역은 코드의 최소 높이와 실제 시뮬레이터 프레임을 함께 확인한다.
- [ ] 시안과 화면 캡처를 변경한 코드에 맞춰 같은 PR에서 갱신하고, 상태표에 현재 진입 불가 분기를 구분한다.

### Rule Addition

새 공통 규칙은 만들지 않았다. 기존 `watch-navigation`, `documentation-standards`, `ui-testing` 규칙과 디자인 보드의 상태 코드를 함께 적용한다.

## Lessons Learned

- 고정 크기 카드와 링은 화면 높이뿐 아니라 내부 글자의 실제 높이까지 함께 계산해야 한다.
- 한 화면의 스크린샷만으로 전체 상태의 완료를 주장할 수 없다. 대표 시안, 코드 상태표, 시뮬레이터 결과의 범위를 각각 명시해야 한다.
- 저장 실패처럼 중요한 상태는 스크롤 위치와 시트 표시 여부와 관계없이 보이고 접근성 포커스를 받을 수 있어야 한다.
