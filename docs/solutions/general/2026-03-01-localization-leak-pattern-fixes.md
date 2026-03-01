---
tags: [localization, xcstrings, leak-pattern, LocalizedStringKey, String-localized, coaching]
date: 2026-03-01
category: solution
status: implemented
---

# Localization Leak Pattern 수정 및 코칭 메시지 번역

## Problem

초기 전수 조사 이후 추가 발견된 localization 누락:
1. **Leak Pattern 1**: 5개 공유 컴포넌트의 `String` 파라미터가 `Text()`에 전달되어 번역 미적용
2. **Leak Pattern 3**: `DashboardViewModel.buildCoachingMessage()` 반환값 6건이 bare English
3. **xcstrings 키 불일치**: `PM₂.₅ %@` 키가 코드의 `Int` interpolation (`%lld`)과 불일치
4. **Dead parameter**: `weightRow.fallbackLabel`이 accessibility 제거 후 orphan

## Solution

### 1. Leak Pattern 1 — 컴포넌트 파라미터 `String` → `LocalizedStringKey` (5개 파일)

| 컴포넌트 | 변경된 파라미터 |
|---------|--------------|
| `EmptyStateView` | `title`, `message`, `actionTitle` |
| `SubScoreTrendChartView` | `title` |
| `SectionGroup` | `title` |
| `WellnessScoreDetailView.weightRow()` | `label` |
| `WellnessScoreDetailView.explainerItem()` | `text` |

`LocalizedStringKey`는 `ExpressibleByStringLiteral`을 구현하므로 기존 string literal 호출부는 변경 불필요.

### 2. Leak Pattern 3 — buildCoachingMessage() `String(localized:)` 래핑 (6건)

ViewModel에서 반환하는 사용자 대면 문자열 6건에 `String(localized:)` 적용 + xcstrings ko/ja 동시 추가.

plural 문제: `"day\(count == 1 ? "" : "s")"` 코드 내 영어 복수형 → 단일 형태 `"days"` 사용 (ko/ja는 복수형 없음).

### 3. 동적 String + LocalizedStringKey 충돌 해결

`DashboardView.errorSection`에서 `EmptyStateView(message:)`에 동적 errorMessage를 전달할 때:

```swift
// Before: 전체를 interpolation으로 감싸 LocalizedStringKey lookup 무력화
message: "\(viewModel.errorMessage ?? String(localized: "An unexpected error occurred."))"

// After: 분기로 분리 — nil이면 static key (catalog lookup), 있으면 dynamic interpolation
let message: LocalizedStringKey = if let msg = viewModel.errorMessage {
    "\(msg)"
} else {
    "An unexpected error occurred."
}
```

### 4. String(localized:) 상수 호이스팅

body에서 매 렌더마다 `String(localized:)` 호출하는 패턴 → `private enum Labels { static let }` 으로 호이스트:

- `WellnessHeroCard`: WELLNESS, Sleep, Condition, Body (4건)
- `WellnessScoreDetailView.scoreHero`: Sleep, Condition, Body (3건)

### 5. xcstrings 키 수정

- `"PM₂.₅ %@"` → `"PM₂.₅ %lld"` (코드의 `Int` interpolation에 매칭)
- `"Best Time"` ja: `"ベストタイム"` → `"最適時間"` (ko 의미 번역과 일관성)
- orphan 키 삭제: `"No body data"`, `"No condition data"` (weightRow에서 fallbackLabel 제거)

## Prevention

### Leak Pattern 탐지 체크리스트

1. View helper에 `String` 파라미터 → `Text()` 전달 확인 → `LocalizedStringKey` 변경
2. ViewModel에서 반환하는 사용자 대면 문자열 → `String(localized:)` 필수
3. `String(localized:)` 상수를 body에서 호출 → `private enum Labels` 호이스트
4. xcstrings 키의 format specifier → 코드의 실제 타입 일치 확인 (`Int` → `%lld`, `String` → `%@`)
5. 파라미터 제거 시 → xcstrings orphan 키 동시 삭제
