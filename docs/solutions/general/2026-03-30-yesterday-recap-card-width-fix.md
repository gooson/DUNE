---
tags: [dashboard, swiftui, layout, inline-card, frame, yesterday-recap]
date: 2026-03-30
category: general
status: implemented
---

# YesterdayRecapCard 축소 표시 수정

## Problem

Dashboard "어제" 섹션(`YesterdayRecapCard`)이 다른 full-width 카드들과 달리 콘텐츠 크기만큼 축소되어 표시됨.

**근본 원인**: `InlineCard` 내부 `VStack(alignment: .leading)` 이 `.frame(maxWidth: .infinity)`를 설정하지 않았고, VStack 내부에 `Spacer()`나 full-width 요소가 없어 intrinsic content size로 레이아웃이 계산됨.

## Solution

`YesterdayRecapCard.swift`의 `InlineCard` 내부 VStack에 `.frame(maxWidth: .infinity, alignment: .leading)` 추가.

**변경 파일**: `DUNE/Presentation/Dashboard/Components/YesterdayRecapCard.swift` (1줄 추가)

## Prevention

`InlineCard`를 사용하는 새 카드 컴포넌트를 추가할 때:
- 내부 콘텐츠에 `Spacer()` 또는 full-width 요소가 없으면 `.frame(maxWidth: .infinity, alignment: .leading)` 명시
- `InlineCard` 자체가 `maxWidth: .infinity`를 강제하지 않으므로 소비자 측에서 명시해야 함

## Lessons Learned

- `InlineCard`는 `content()` + padding + background로 구성된 래퍼로, 자체적으로 width를 확장하지 않음
- 다른 `InlineCard` 소비자들(`TodayBriefCard`, `RecoverySleepCard` 등)은 내부에 `Spacer()` 포함 HStack, NavigationLink, 프로그레스 바 등 자연스럽게 full-width를 차지하는 요소가 있어 문제가 드러나지 않았음
- 순수 텍스트/라벨만 포함하는 카드는 명시적 width 확장 필수
