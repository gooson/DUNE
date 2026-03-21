---
tags: [swiftui, sheet, navigation, toolbar, life-tab]
date: 2026-03-22
category: general
status: implemented
---

# History Sheet: Triple Close Button + Content Overhaul

## Problem

HabitHistorySheet에 "닫기" 버튼이 3개 표시되고, 히스토리 항목에 action 이름과 날짜만 표시되어 유용한 정보가 없었다.

## Root Cause

### Triple Close Button

`.sheet(item:)` 가 `HabitListQueryView` body의 VStack에 붙어 있으며, 이 VStack은 ContentView의 `NavigationStack` 내부에 위치.

HabitHistorySheet 내부에 다시 `NavigationStack`을 생성하면서, 부모 navigation bar의 toolbar item이 sheet에 leak되어 닫기 버튼이 중복.

### 빈약한 히스토리

`HabitHistoryEntry`에 `action`, `date`, `value`만 포함. 습관 유형, 목표값, 단위 정보가 없어 "완료됨" + 날짜만 표시.

## Solution

### NavigationStack 제거

Sheet에서 `NavigationStack` + `.toolbar` 제거. 대신 커스텀 header VStack으로 대체:
- 습관 아이콘 + 이름 + 기록 수
- 단일 X 닫기 버튼 (우측 상단)

### HabitHistoryEntry 확장

```swift
struct HabitHistoryEntry: Identifiable, Sendable {
    let goalValue: Double    // NEW
    let goalUnit: String?    // NEW
    let habitType: HabitType // NEW
}
```

### 히스토리 항목 상세 표시

- Check: "Done"
- Duration: "30/60 min"
- Count: "3/8 glasses"
- 상대 날짜: "Today", "Yesterday", "3 days ago"
- 절대 날짜: "2026년 3월 22일"

## Prevention

- Sheet에 `NavigationStack`을 넣을 때는 부모 NavigationStack과의 toolbar 충돌을 먼저 확인
- watch-navigation.md의 "Sheet 내부 NavigationStack 금지" 규칙이 iOS에도 적용되는 패턴
- 히스토리/상세 뷰에는 항상 원본 데이터의 context (유형, 목표, 단위)를 함께 전달
