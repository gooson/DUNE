tags: [swiftui, foreach, lazyvgrid, identity, consistency, calendar]
date: 2026-03-08
category: solution
status: implemented
---

# Consistency Weekday Duplicate `ForEach` ID Fix

## Problem

Consistency 화면의 월간 캘린더에서 콘솔에 아래 경고가 반복 출력됐다.

- `ForEach<Array<String>, String, ...>: the ID T occurs multiple times within the collection`
- `ForEach<Array<String>, String, ...>: the ID S occurs multiple times within the collection`
- `LazyVGridLayout: ... explicitID: Optional("T") ... is used by multiple child views`

## Root Cause

요일 헤더 배열 `["S", "M", "T", "W", "T", "F", "S"]`를 `ForEach(..., id: \.self)`로 렌더링하고 있었다.

화면에는 같은 라벨이 자연스럽지만, SwiftUI identity 관점에서는 `T`와 `S`가 중복 ID가 되어 grid child identity가 깨졌다.

## Solution

표시 문자열과 식별자를 분리했다. weekday header를 `ConsistencyWeekdayHeader` 모델로 감싸고, 라벨은 유지하되 `index`를 stable ID로 사용하도록 바꿨다.

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `DUNE/Presentation/Activity/Consistency/ConsistencyDetailView.swift` | `ConsistencyWeekdayHeader` 추가, weekday `ForEach`를 `Identifiable` 모델 기반으로 변경 | duplicate ID 제거 |
| `DUNETests/ConsistencyDetailViewModelTests.swift` | weekday header ID uniqueness test 추가 | 회귀 방지 |

### Key Code

```swift
struct ConsistencyWeekdayHeader: Identifiable {
    let index: Int
    let label: String

    var id: Int { index }
}
```

## Prevention

- `ForEach(..., id: \.self)`는 값 자체가 항상 유일할 때만 사용한다.
- 요일 이니셜, 등급 문자, 축약 라벨처럼 중복 가능성이 있는 UI 값은 `index`나 domain ID를 별도 식별자로 둔다.
- `LazyVGrid`/`List` 경고는 화면만 멀쩡해 보여도 identity corruption 신호로 보고 바로 수정한다.

## Lessons Learned

화면 텍스트의 중복 허용성과 SwiftUI view identity의 유일성은 별개다. 특히 캘린더/차트/축 레이블처럼 값 중복이 자연스러운 영역에서는 표시용 label과 렌더링용 ID를 처음부터 분리하는 편이 안전하다.
