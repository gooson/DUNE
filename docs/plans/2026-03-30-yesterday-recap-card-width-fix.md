---
tags: [dashboard, yesterday-recap, layout, inline-card, fix]
date: 2026-03-30
category: plan
status: draft
---

# Fix: YesterdayRecapCard 축소 표시 버그

## Problem

Dashboard의 "어제" 섹션(`YesterdayRecapCard`)이 다른 카드들처럼 full-width로 표시되지 않고, 콘텐츠 크기만큼 축소되어 표시됨.

### 근본 원인

`YesterdayRecapCard`의 `InlineCard` 내부 `VStack(alignment: .leading)`이 `.frame(maxWidth: .infinity)`를 설정하지 않아, SwiftUI가 intrinsic content size로 레이아웃을 계산. 부모 `VStack`의 기본 정렬이 `.center`이므로 카드가 가운데로 좁게 배치됨.

다른 `InlineCard` 사용 카드들(`TodayBriefCard`, `RecoverySleepCard`, `CumulativeStressCard` 등)은 내부에 `Spacer()` 또는 full-width 요소(NavigationLink, 프로그레스 바 등)가 있어 자연스럽게 full-width로 확장됨.

## Affected Files

| 파일 | 변경 유형 |
|------|----------|
| `DUNE/Presentation/Dashboard/Components/YesterdayRecapCard.swift` | VStack에 `.frame(maxWidth: .infinity, alignment: .leading)` 추가 |

## Implementation Steps

### Step 1: VStack frame 수정

`YesterdayRecapCard`의 `InlineCard` 내부 `VStack`에 `.frame(maxWidth: .infinity, alignment: .leading)` 추가.

```swift
// Before
InlineCard {
    VStack(alignment: .leading, spacing: DS.Spacing.sm) {
        ...
    }
}

// After
InlineCard {
    VStack(alignment: .leading, spacing: DS.Spacing.sm) {
        ...
    }
    .frame(maxWidth: .infinity, alignment: .leading)
}
```

## Test Strategy

- 빌드 확인: `scripts/build-ios.sh`
- 시뮬레이터 실행으로 카드 너비가 다른 카드와 동일한지 시각 확인
- 기존 UI 테스트 회귀 확인

## Risks / Edge Cases

- iPad(regular size class)에서도 full-width 동작 확인 필요
- `InlineCard` 자체는 변경하지 않음 (다른 사용처 영향 방지)
