---
tags: [watchos, swiftui, scrollview, button, layout, touch-target]
category: general
date: 2026-03-02
severity: important
related_files: [DUNEWatch/Views/WorkoutPreviewView.swift]
related_solutions: []
---

# Solution: watchOS VStack 버튼이 터치에 반응하지 않는 문제

## Problem

### Symptoms

- Watch 앱에서 유산소 운동 선택 후 Outdoor/Indoor 버튼이 화면에 보이지만 탭해도 반응 없음
- 에러 메시지, 스피너 등 어떤 시각적 피드백도 없음
- 같은 화면의 근력 운동 Start 버튼은 정상 동작

### Root Cause

`cardioStartContent`가 `Spacer()` 3개 + 40pt 아이콘 + 텍스트 + 44pt 버튼 2개를 **ScrollView 없는 VStack**에 배치.

고정 콘텐츠 높이(~196pt)가 watchOS 화면 사용 가능 영역(40mm 기준 ~98pt)을 초과하여, 버튼이 safe area 밖의 비인터랙티브 영역으로 밀림. SwiftUI는 overflow 콘텐츠를 렌더링하지만 터치 이벤트는 전달하지 않음.

근력 운동 경로는 `List`(스크롤 가능)를 사용하므로 영향 없었음.

## Solution

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `DUNEWatch/Views/WorkoutPreviewView.swift` | `VStack` → `ScrollView` > `VStack` | 콘텐츠가 항상 스크롤 가능하도록 |
| 동일 파일 | `Spacer()` 3개 제거 | 화면 overflow 원인 제거 |
| 동일 파일 | `.scrollBounceBehavior(.basedOnSize)` 추가 | 큰 Watch에서 불필요한 바운스 방지 |

### Key Code

```swift
// Before (broken): VStack with Spacers overflows screen
VStack(spacing: DS.Spacing.lg) {
    Spacer()
    Image(systemName: ...)
    Text(...)
    Spacer()
    Button { ... } // ← 터치 불가 영역
    Button { ... } // ← 터치 불가 영역
    Spacer()
}

// After (fixed): ScrollView ensures all content is interactive
ScrollView {
    VStack(spacing: DS.Spacing.lg) {
        Image(systemName: ...)
            .padding(.top, DS.Spacing.lg)
        Text(...)
        Button { ... } // ← 스크롤하여 접근 가능
        Button { ... }
    }
    .padding(.horizontal, DS.Spacing.lg)
}
.scrollBounceBehavior(.basedOnSize)
```

## Prevention

### Checklist Addition

- [ ] watchOS VStack에 고정 높이 콘텐츠 3개+ 배치 시 ScrollView 래핑 확인
- [ ] watchOS에서 Spacer() 사용 시 총 콘텐츠 높이가 ~98pt(40mm) 이하인지 검증
- [ ] ScrollView 사용 시 `.scrollBounceBehavior(.basedOnSize)` 적용

### Rule Addition (if applicable)

`swiftui-patterns.md`에 watchOS 섹션 추가 고려:
> watchOS VStack에 44pt+ 버튼 2개 이상 + 고정 콘텐츠 → ScrollView 필수. Spacer()로 센터링 시 총 높이 초과 위험.

## Lessons Learned

- watchOS에서 VStack overflow 콘텐츠는 **렌더링되지만 터치가 불가능**하여 디버깅이 어려움
- "버튼이 보이는데 안 눌린다" → safe area 밖 overflow 의심
- 근력 운동 경로(List 사용)와 유산소 경로(VStack 사용)의 레이아웃 차이가 버그의 근본 원인
