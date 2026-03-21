---
tags: [swiftui, heatmap, detail-view, card-navigation, accessibility, localization]
date: 2026-03-22
category: general
status: implemented
---

# Heatmap Card → Detail View Pattern

## Problem

Activity heatmap 섹션이 3가지 문제를 가지고 있었다:
1. 고정 셀 크기(12px)로 카드 너비를 채우지 못함
2. 탭해도 상세 화면이 없어 정보 탐색 불가
3. "Less/More" 범례만 있고 데이터 의미 설명 없음

## Solution

### 1. HabitHeatmapView — 탭 가능 카드

```swift
Button(action: onTapDetail) {
    VStack { header; description; HabitHeatmapGridView(data:); HabitHeatmapLegend() }
    .padding(DS.Spacing.md)
    .background { RoundedRectangle(...).fill(.ultraThinMaterial) }
}
.buttonStyle(CardPressButtonStyle())
.accessibilityLabel(Text("Activity heatmap"))
.accessibilityHint(Text("Tap to view detail"))
```

**핵심**: `onTapGesture` 대신 `Button`으로 래핑해야 VoiceOver 자동 등록됨.

### 2. HabitHeatmapDetailView — 상세 화면

- Summary card (총 completions)
- Stats row (일 평균, 최장 streak, 활동일)
- 확대 히트맵 (HabitHeatmapGridView 재사용)
- 요일별 breakdown (GeometryReader 비율 바)

### 3. 공유 컴포넌트

`HabitHeatmapGridView` + `HabitHeatmapLegend`를 추출하여 카드와 상세 화면에서 재사용.

## Prevention

### Card → Detail 패턴 체크리스트

- [ ] 카드 전체 탭: `Button` + `.buttonStyle(.plain)` (onTapGesture 금지)
- [ ] 접근성: `accessibilityLabel` + `accessibilityHint`
- [ ] Navigation: `navigationDestination(isPresented:)` 연결
- [ ] chevron 표시: 우측 상단 `chevron.right` 아이콘
- [ ] Press 피드백: `CardPressButtonStyle` (opacity 0.7)

### Helper 함수 LocalizedStringKey 체크리스트

- Helper 함수가 `String`을 받아 `Text()`에 전달 → `LocalizedStringKey`로 변경
- `String(localized:)` 호출부 대신 리터럴 전달 가능

### GeometryReader 바 차트 정렬

GeometryReader 내부 바에 명시적 height + `.frame(maxHeight: .infinity, alignment: .center)` 필요.
```swift
GeometryReader { geo in
    RoundedRectangle(...)
        .frame(width: barWidth, height: 12)
        .frame(maxHeight: .infinity, alignment: .center)
}
.frame(height: 20)
```

## Lessons Learned

1. `onTapGesture`는 VoiceOver에 노출되지 않음 — 네비게이션용은 반드시 `Button`
2. Helper 함수의 `title: String` 파라미터는 localization leak 패턴 (localization.md Leak Pattern 1)
3. GeometryReader 내부 뷰는 기본 topLeading 정렬 — 수직 중앙 정렬이 필요하면 명시
