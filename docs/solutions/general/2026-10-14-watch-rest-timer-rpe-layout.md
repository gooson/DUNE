---
tags: [watchos, swiftui, rest-timer, rpe, compact-layout, ui-test]
category: general
date: 2026-10-14
status: implemented
severity: important
related_files:
  - DUNEWatch/Views/RestTimerView.swift
  - DUNEWatchUITests/Smoke/WatchSetRPEEntryUITests.swift
  - DUNEWatch/Resources/Localizable.xcstrings
related_solutions:
  - docs/solutions/general/2026-10-12-watch-workout-screen-system.md
---

# Solution: Watch 휴식 타이머와 RPE 확정 버튼의 첫 화면 배치

## Problem

### Symptoms

- 작은 Watch 화면에서 카운트다운과 RPE 문구가 진행 링에 닿고 링 아래 조작 행의 여백이 불균형했다.
- RPE 조정 시트의 `RPE 확정` 버튼이 첫 화면 아래로 밀려 스크롤해야 보였다.

### Root Cause

링 크기는 화면 높이에 맞춰 100pt 안팎까지 줄였지만, 링 안에는 카운트다운·심박·44pt RPE 버튼을 그대로 쌓았다. RPE 시트도 값 표시, 44pt 증감 행, 44pt 확정 버튼을 세로로 배치해 작은 viewport의 높이를 넘겼다.

## Solution

### Changes Made

| File | Change | Reason |
|---|---|---|
| `RestTimerView.swift` | 링 안에는 카운트다운과 심박만 두고, RPE를 `+30초`·`건너뛰기`와 함께 44pt 조작 행으로 이동. RPE 버튼은 46pt 폭에서 두 줄로 표시 | 링 경계와 텍스트를 분리하고 좁은 버튼의 좌우 여백을 확보 |
| `RestTimerView.swift` | RPE 값·설명을 증감 버튼 사이에 배치하고 확정 버튼을 `safeAreaInset`에 고정 | 내용이 길어져도 확정 동작은 첫 화면에 유지 |
| `WatchSetRPEEntryUITests.swift` | 확정 버튼의 스크롤 전 표시·탭 가능 여부와 44pt 높이, 휴식 화면 RPE 버튼 폭과 양쪽 간격 검증 | 화면 밖 버튼과 좁은 조작 행의 회귀 방지 |
| `Localizable.xcstrings` | 두 줄 버튼의 `Record`를 한국어·일본어로 번역 | 짧은 조작 문구를 언어별로 유지 |

### Key Code

```swift
.safeAreaInset(edge: .bottom, spacing: 0) {
    Button {
        onRPEAdjusted?(adjustedRPE)
        hasConfirmedRPE = true
        showRPEInput = false
        WKInterfaceDevice.current().play(.success)
    } label: {
        Text("Confirm RPE")
            .font(.caption.weight(.semibold))
            .frame(maxWidth: .infinity, minHeight: 44)
            .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .foregroundStyle(.black)
    .background(theme.metricActivity, in: Capsule())
    .accessibilityIdentifier("watch-rest-timer-rpe-confirm")
    .padding(.top, DS.Spacing.xs)
}
```

조정 행은 이 코드의 상위 `ScrollView`에 배치한다. 40mm Watch 시뮬레이터에서 휴식 타이머와 RPE 시트의 첫 화면을 캡처하고 관련 두 UI 테스트 시나리오가 통과하는 것을 확인했다.

## Prevention

### Checklist Addition

- [ ] 원형 UI의 최소 지름을 정할 때 텍스트의 사각 프레임뿐 아니라 원의 위아래 곡선 여유도 확인한다.
- [ ] 작은 Watch의 첫 viewport에서 필수 버튼이 완전히 보이고 44pt 이상이며, 스크롤 없이 눌리는지 확인한다.
- [ ] 한국어처럼 긴 조작 문구를 세 버튼에 배치하면 실제 40mm 캡처에서 좌우 여백을 확인한다.

### Rule Addition

새 공통 규칙은 추가하지 않았다. 기존 Watch UI 테스트의 첫 viewport 프레임 검증을 재사용한다.

## Lessons Learned

`ViewThatFits`가 스크롤 fallback을 제공해도 주요 확정 버튼이 첫 화면에 남는 것은 보장하지 않는다. 크기가 줄어드는 링의 내부 정보는 최소 기기에서 다시 구성해야 한다.
