---
tags: [life-tab, history, sheet, ux]
date: 2026-03-22
category: plan
status: draft
---

# Plan: History Sheet 전면 개편

## Summary

History 시트에 "닫기" 버튼이 3개 나타나는 버그 + 히스토리 내용이 빈약한 UX 문제를 수정.

## Root Cause Analysis

### 버그: "닫기" 3개

`HabitHistorySheet`는 `.sheet(item:)` 으로 `HabitListQueryView` body의 VStack에 붙어 있다.
이 VStack은 ContentView의 `NavigationStack` 내부에 있다.

Sheet가 `NavigationStack`을 내부에 다시 생성하면서, 부모 navigation bar의 toolbar item이
sheet에 leak되어 중복 표시. 해결: sheet 내 NavigationStack 제거 → toolbar 구성 단순화.

### UX: 빈약한 히스토리

현재 `HabitHistoryEntry`는 `action`, `date`, `value`만 포함.
View에서는 action명("완료됨")과 date만 표시. value도, 습관 유형도, 목표 대비 진행도 표시 안 함.

## Affected Files

| # | 파일 | 변경 유형 | 목적 |
|---|------|----------|------|
| 1 | `Presentation/Life/LifeView.swift` | 수정 | HabitHistorySheet 전면 개편 |
| 2 | `Presentation/Life/LifeViewModel.swift` | 수정 | HabitHistoryEntry에 context 필드 추가 |

## Implementation Steps

### Step 1: HabitHistoryEntry 확장

ViewModel의 `HabitHistoryEntry`에 습관 context 추가:

```swift
struct HabitHistoryEntry: Identifiable, Sendable {
    let id: UUID
    let action: HabitCycleAction
    let date: Date
    let value: Double
    let goalValue: Double        // NEW
    let goalUnit: String?        // NEW
    let habitType: HabitType     // NEW
}
```

`historyEntries(for:)` 메서드에서 habit의 goalValue, goalUnit, habitType을 전달.

### Step 2: HabitHistorySheet 전면 개편

1. **NavigationStack 제거** — sheet 자체에 toolbar 대신 단순 header
2. **닫기 버튼 1개** — 상단 우측 X 버튼
3. **각 항목에 상세 표시**:
   - Check: "완료됨" or "미완료"
   - Duration: "30분 / 60분" 형태 (value / goal)
   - Count: "3 / 8" 형태
   - 날짜: 상대 날짜 ("오늘", "어제", "3일 전") + 절대 날짜
4. **습관 이름 + 아이콘 헤더**
5. **빈 상태 개선**: 아이콘 + 동기부여 메시지

### Step 3: 번역 추가

새 문자열을 xcstrings에 등록.

## Test Strategy

- 빌드 확인 (`scripts/build-ios.sh`)
- 시뮬레이터에서 History 시트 열기 → 닫기 버튼 1개 확인
- 히스토리 내용에 value/goal 표시 확인

## Edge Cases

- 습관에 로그가 0개 → 빈 상태 표시
- check 타입 → value 1.0은 "완료", 0은 skip/snooze
- duration → value=30, goal=60 → "30/60 min"
- cycle skip/snooze → value=0 → skip/snooze label만 표시 (진행률 없음)

## Risks

- 낮음: UI 전용 변경, 로직 영향 없음
