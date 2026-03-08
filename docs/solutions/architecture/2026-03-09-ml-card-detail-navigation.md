---
tags: [navigation, detail-view, ml-sdk, presentation-extension, localization]
date: 2026-03-09
category: solution
status: implemented
---

# ML Card Detail Screen Navigation Pattern

## Problem

ML SDK 카드(Injury Risk, Weekly Report, Tonight's Sleep)의 상세 화면이 연결되지 않아
사용자가 카드를 탭해도 아무 반응이 없었음. 또한 각 카드의 UI 문자열에 다국어 처리가
누락되어 영어만 표시됨.

## Solution

### Navigation Wiring

**Activity Tab** (enum-based routing):
```swift
// ActivityDetailDestination에 case 추가
case injuryRisk
case weeklyReport

// ActivityView에서 NavigationLink(value:) + nil guard
if viewModel.injuryRiskAssessment != nil {
    NavigationLink(value: ActivityDetailDestination.injuryRisk) {
        InjuryRiskCard(assessment: viewModel.injuryRiskAssessment)
    }
    .buttonStyle(.plain)
} else {
    InjuryRiskCard(assessment: nil)
}
```

**Wellness Tab** (struct-based routing — enum 미사용):
```swift
struct SleepPredictionDestination: Hashable {}

// NavigationLink + nil guard
if viewModel.sleepPrediction != nil {
    NavigationLink(value: SleepPredictionDestination()) {
        SleepPredictionCard(prediction: viewModel.sleepPrediction)
    }
    .buttonStyle(.plain)
}

// .navigationDestination(for:) 핸들러
.navigationDestination(for: SleepPredictionDestination.self) { _ in
    if let prediction = viewModel.sleepPrediction {
        SleepPredictionDetailView(prediction: prediction)
    }
}
```

### Presentation Extension Pattern

Domain 타입의 UI 프로퍼티(color, iconName, recommendations)는
`Presentation/Shared/Extensions/{DomainType}+View.swift`에 배치:

```swift
// InjuryRiskAssessment+View.swift
extension InjuryRiskAssessment.Level {
    var color: Color { ... }
    var iconName: String { ... }
    var recommendations: [String] { ... }  // String(localized:) 사용
}
```

Card와 DetailView 모두 동일 extension을 참조하여 시각적 일관성 보장.

### LocalizedStringKey in Helper Functions

Swift 6에서 `LocalizedStringKey`는 non-Sendable → `static let` 저장 불가.

```swift
// BAD: Swift 6 concurrency error
private enum Labels {
    static let sessions: LocalizedStringKey = "Sessions"  // ❌
}

// GOOD: 문자열 리터럴을 직접 전달 → auto-resolve to LocalizedStringKey
statCell(value: "5", label: "Sessions")  // ✅

// Helper function signature
private func statCell(value: String, label: LocalizedStringKey, ...) -> some View
```

### Foundation Models Locale

`FoundationModelReportFormatter.localeInstruction(periodName:)`에서
`Locale.current.language.languageCode`로 한국어/일본어/영어 프롬프트 분기:

```swift
private func localeInstruction(periodName: String) -> String {
    let code = Locale.current.language.languageCode?.identifier ?? "en"
    switch code {
    case "ko": return "한국어로 ... 작성해주세요"
    case "ja": return "日本語で ... 書いてください"
    default: return "Write in English..."
    }
}
```

## Key Decisions

1. **Optional vs non-optional input**: InjuryRisk/WeeklyReport은 optional (자체 emptyState),
   SleepPrediction은 non-optional (NavigationLink nil-guard로 진입 차단)
2. **DetailScoreHero 재사용**: 기존 공유 컴포넌트 활용 (score, statusLabel, guideMessage)
3. **DateIntervalFormatter 캐싱**: `private enum Cache { static let }` 패턴
4. **factor icon**: Sleep factor row에서 `factor.type.iconName` 사용 (종류 구분),
   impact는 우측 badge로 표시

## Prevention

- Detail view 추가 시 Presentation extension에 UI 프로퍼티 배치 먼저 확인
- `LocalizedStringKey`를 `static let`으로 저장하지 말 것 (Swift 6 Sendable)
- Card와 Detail이 동일 Domain extension을 참조하여 색상/아이콘 불일치 방지
- 새 UI 문자열은 xcstrings에 en/ko/ja 3개 언어 동시 등록
