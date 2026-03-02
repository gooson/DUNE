---
tags: [localization, xcstrings, swiftui, localizedstringkey, appsection, training-readiness]
category: general
date: 2026-03-02
severity: important
related_files:
  - DUNE/App/AppSection.swift
  - DUNE/App/ContentView.swift
  - DUNE/Presentation/Activity/TrainingReadiness/TrainingReadinessDetailView.swift
  - DUNE/Resources/Localizable.xcstrings
related_solutions:
  - docs/solutions/general/localization-gap-audit.md
  - docs/solutions/general/2026-03-01-localization-leak-pattern-fixes.md
---

# Solution: Training Readiness 상세/탭 라벨 Localization Leak Fix

## Problem

Training Readiness 상세 화면에서 일부 항목이 한국어 로케일에서도 영어로 노출되고, 하단 탭 타이틀도 영어로 고정 노출되었습니다.

### Symptoms

- `점수 구성` 섹션 내 `HRV Variability`, `Recovery Status`, `Trend Bonus`가 영어로 표시
- `계산 방법` 본문 4줄이 영어로 표시
- 하단 탭(`Today`, `Activity`, `Wellness`, `Life`)이 영어 고정

### Root Cause

- `Localizable.xcstrings`에 일부 키가 누락되어 번역 lookup이 실패
- `Text(verbatim:)` 및 `Text(String)` 경로로 localization lookup이 우회되는 leak pattern 존재
- `DetailScoreHero`가 `String` 기반 파라미터를 받아 호출부에서 `String(localized:)` 적용이 필요했으나 누락

## Solution

누락 키 보강과 leak 경로 제거를 함께 적용했습니다.

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `DUNE/App/AppSection.swift` | `title` 타입을 `LocalizedStringKey`로 변경 | 탭 타이틀을 SwiftUI key 경로로 localize |
| `DUNE/App/ContentView.swift` | `Text(verbatim:)` 제거 → `Text(AppSection.*.title)` | localization 우회 제거 |
| `DUNE/Presentation/Activity/TrainingReadiness/TrainingReadinessDetailView.swift` | `Labels` static `String(localized:)` 상수 추가, `calculationMethodLine` 파라미터 `LocalizedStringKey` 변경 | String 기반 전달부/헬퍼 함수 leak 차단 |
| `DUNE/Resources/Localizable.xcstrings` | 누락 키 8개(가중치/계산식/RHR) ko/ja 번역 추가 | 실제 번역 데이터 보완 |

### Key Code

```swift
// AppSection.swift
var title: LocalizedStringKey {
    switch self {
    case .today: "Today"
    case .train: "Activity"
    case .wellness: "Wellness"
    case .life: "Life"
    }
}

// ContentView.swift
Label { Text(AppSection.today.title) } icon: { Image(systemName: AppSection.today.icon) }

// TrainingReadinessDetailView.swift
private enum Labels {
    static let scoreLabel = String(localized: "READINESS")
    static let rhr = String(localized: "RHR")
}

private func calculationMethodLine(_ text: LocalizedStringKey) -> some View {
    Text(text)
}
```

## Prevention

### Checklist Addition

- [ ] `Text(verbatim:)`가 사용자 대면 문자열에 사용되지 않는지 확인
- [ ] `Text(String)` helper 파라미터가 static key를 받는 경우 `LocalizedStringKey` 타입인지 확인
- [ ] `String` 파라미터 컴포넌트(`DetailScoreHero`류)에 전달되는 레이블이 `String(localized:)`인지 확인
- [ ] 신규 UI 문자열 추가 시 `.xcstrings`에 ko/ja 번역 동시 추가

### Rule Addition (if applicable)

기존 `.claude/rules/localization.md`의 leak pattern 규칙으로 커버 가능하여 신규 룰 추가는 불필요합니다.

## Lessons Learned

- 카탈로그 키 누락과 코드 경로 누락(`verbatim`/`String`)은 동시에 발생하기 쉽기 때문에 둘을 분리해 점검해야 합니다.
- `LocalizedStringKey`와 `String(localized:)`는 컴포넌트 시그니처(`Text` 기반인지 `String` 기반인지)에 맞춰 혼용해야 안정적으로 누락을 막을 수 있습니다.
