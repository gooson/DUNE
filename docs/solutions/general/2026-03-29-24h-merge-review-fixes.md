---
tags: [localization, animation, review, l10n-leak, onAppear, task]
date: 2026-03-29
category: general
status: implemented
---

# 24h Merge Review — L10N Leaks & Animation Lifecycle Fixes

## Problem

최근 24시간 동안 머지된 20개 PR(120 커밋)을 리뷰한 결과 다음 문제를 발견:

1. **SleepRegularityCard**: 수면 시간을 AM/PM 하드코딩으로 표시 — ko/ja에서 영어 AM/PM 노출
2. **ActivityPersonalRecordService**: "Strength", `recordType.rawValue`, "Manual Cardio" 3개 subtitle이 `String(localized:)` 없이 할당 — Leak Pattern 2
3. **WaveRefreshIndicator**: `.repeatForever` 애니메이션을 `.onAppear`에서 시작 — 부모 트랜잭션 간섭
4. **HeroScoreCard**: `.onAppear` 내 `Task { @MainActor in }` — view 소멸 후 취소 불가
5. **MetricSummaryHeader**: 비교 문장이 `Text(stringInterpolation)` 으로 비지역화 경로 사용
6. **xcstrings**: Force Sync, +%@ kg, +%@pt, ~%@ 4개 키에 ko/ja 번역 누락

## Solution

### 1. SleepRegularityCard — locale-aware 시간 포맷
```swift
// Before: hardcoded AM/PM
let period = hour >= 12 ? "PM" : "AM"
return String(format: "%d:%02d %@", displayHour, minute, period)

// After: locale-aware
return date.formatted(.dateTime.hour().minute())
```

### 2. ActivityPersonalRecordService — String(localized:) 적용
- `subtitle: "Strength"` → `subtitle: String(localized: "Strength")`
- `subtitle: recordType.rawValue` → `subtitle: recordType.localizedSubtitle`
- `subtitle: "Manual Cardio"` → `subtitle: String(localized: "Manual Cardio")`
- `PersonalRecordType`에 `localizedSubtitle` computed property 추가

### 3. WaveRefreshIndicator — .onAppear → .task
`.repeatForever` 애니메이션은 반드시 `.task`에서 시작 (swiftui-patterns rule).

### 4. HeroScoreCard — .task(id: score)로 통합
`.onAppear` + uncancellable `Task` + `.onChange(of: score)` 3개를 `.task(id: score)` 하나로 통합.
Task 내 `try? await Task.sleep`은 view 소멸 시 자동 취소.

### 5. MetricSummaryHeader — String(localized:) 래핑
`Text("Your average is \(absChange)% higher than last period")` →
`Text(String(localized: "Your average is \(absChange)% higher than last period"))`

### 6. xcstrings 번역 추가
13개 키에 ko/ja 번역 추가 (4개 기존 누락 + 9개 신규).

## Prevention

1. **Sendable struct에 사용자 대면 String 할당 시 `String(localized:)` 필수** — corrections-active.md Leak Pattern 2 참조
2. **enum rawValue를 UI subtitle에 직접 사용 금지** — `displayName`/`localizedSubtitle` computed property 경유
3. **`.repeatForever` 애니메이션은 `.task`에서만 시작** — `.onAppear` 금지 (swiftui-patterns.md)
4. **`.onAppear` 내 uncancellable `Task` 금지** — `.task(id:)` 사용으로 자동 취소 보장
5. **새 xcstrings 키 추가 시 ko/ja 동시 등록** — 번역 누락 방지

## Lessons Learned

- 대량 머지 후 l10n 누락은 grep/python 스크립트로 체계적 검사 필요
- `String(format:)` 사용은 localization.md에서 금지되어 있으나, 새 코드에서 여전히 사용됨
- `.onAppear` → `.task` 마이그레이션은 반복 발생하는 패턴 — pre-commit hook 검토 고려
