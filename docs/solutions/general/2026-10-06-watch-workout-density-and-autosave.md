---
tags: [watchos, swiftui, workout, rest-timer, swiftdata, healthkit, accessibility, ui-test]
category: general
date: 2026-10-06
status: implemented
severity: important
related_files:
  - DUNEWatch/Views/RestTimerView.swift
  - DUNEWatch/Views/MetricsView.swift
  - DUNEWatch/Views/SessionSummaryView.swift
  - DUNEWatch/Views/WorkoutPreviewView.swift
  - DUNEWatchUITests/Helpers/WatchUITestBaseCase.swift
related_solutions:
  - docs/solutions/general/2026-03-02-watchos-button-overflow-fix.md
  - docs/solutions/testing/2026-03-12-watch-ui-smoke-surface-fallback-hardening.md
  - docs/solutions/design/2026-03-15-watch-machine-level-preview-picker.md
---

# Solution: Watch 운동 화면 밀도와 완료 저장 분리

## Problem

### Symptoms

- 40mm Watch 휴식 화면에서 타이머, RPE, `+30초`/`건너뛰기`/`종료`가 작은 영역에 몰려 있었다.
- 휴식 중 종료 확인을 열었다가 취소하면 카운트다운 작업이 중단될 수 있었다.
- 최종 요약의 `완료`를 누르지 않으면 운동 기록을 저장하지 않았다.
- Watch UI 테스트에서 미리보기 버튼은 보이지만 개별 접근성 식별자로 찾을 수 없었고, 운동 목록의 빠른 스와이프는 중간 행을 건너뛰었다.

### Root Cause

휴식 화면은 세 개의 동작을 같은 줄에 두어 타이머의 우선순위를 낮췄다. 기존 종료 확인은 사용자의 최종 의사가 정해지기 전에 타이머를 취소했다. 요약 화면은 기록 저장과 화면 닫기를 `완료` 버튼 하나에 결합했다. 운동 미리보기의 상위 SwiftUI 뷰에 붙인 접근성 식별자가 watchOS 트리에서 자식 버튼 식별자를 덮었고, UI 테스트의 기본 스와이프 속도는 40mm 목록의 중간 행을 건너뛰었다.

## Solution

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `DUNEWatch/Views/RestTimerView.swift` | 타이머와 RPE를 한 행에, `+30초`/`건너뛰기`를 다음 행에 배치하고 종료를 상단 확인 동작으로 이동 | 남은 시간과 다음 행동을 분명히 표시 |
| `DUNEWatch/Views/MetricsView.swift` | 중복 진행 표시 제거, 세트 완료 직후 추정 RPE 기록 | 작은 화면 공간 확보 및 조기 종료 데이터 보존 |
| `DUNEWatch/Views/SessionSummaryView.swift` | 요약 진입 시 저장, 저장 상태 표시, `완료` 하단 고정, 이후 강도 수정 저장 | 저장과 요약 닫기 분리 |
| `DUNEWatch/Views/WorkoutPreviewView.swift` | `.accessibilityElement(children: .contain)`으로 화면 컨테이너 구성 | 자식 버튼 식별자 보존 |
| `DUNEWatchUITests/Helpers/WatchUITestBaseCase.swift` | 중첩 컨트롤은 `firstMatch`, 운동 목록은 느린 짧은 드래그와 역방향 탐색 | 실제 watchOS 접근성·스크롤 동작 검증 |

### Key Code

```swift
.accessibilityElement(children: .contain)
.accessibilityIdentifier(WatchWorkoutSurfaceAccessibility.workoutPreviewScreen)
```

```swift
.onAppear {
    if !didStartAutomaticSave {
        didStartAutomaticSave = true
        startSaving()
    }
}
```

`saveSession`은 SwiftData 저장 성공을 확인한 뒤 `hasSaved`를 설정한다. 재시도 때는 이미 생성한 `ExerciseRecord`와 HealthKit ID를 재사용해 중복 운동을 만들지 않는다. `완료`는 저장된 운동을 닫고, 저장 오류가 있으면 재시도를 제공한다.

## Prevention

### Checklist Addition

- [ ] Watch 완료 화면에서 기록 저장이 화면 닫기 버튼에만 묶여 있는지 확인한다.
- [ ] 40mm와 큰 글씨에서 타이머, 기본 동작, 보조 동작의 위계와 터치 가능 영역을 확인한다.
- [ ] 상위 SwiftUI 뷰에 접근성 식별자를 붙일 때 자식 컨트롤 식별자가 유지되는지 xcresult 트리로 확인한다.
- [ ] Watch `List` UI 테스트는 전체 스와이프로 중간 행을 건너뛰지 않는지 확인한다.

### Rule Addition

별도 공통 규칙은 추가하지 않았다. Watch 화면의 실제 접근성 트리와 작은 기기 스크롤을 함께 확인하는 항목을 기존 UI 테스트 점검에 적용한다.

## Lessons Learned

- 작은 Watch 화면에서 중복 정보와 가로 조작 세 개는 중요한 타이머를 약하게 만든다.
- 운동 종료 확정, 기록 저장, 요약 닫기는 서로 다른 시점의 사용자 행동이다.
- 스크린샷에 보이는 컨트롤도 상위 접근성 식별자 때문에 자동화와 VoiceOver에서 구분되지 않을 수 있다.
- UI 테스트의 스와이프 거리뿐 아니라 속도와 스크롤 스냅도 fixture 탐색 결과를 바꾼다.
