---
tags: [scrollview, lazyvgrid, swiftdata, query, layout-feedback-loop, bounce, eager-grid, scroll-bounce-behavior]
category: performance
date: 2026-02-28
severity: critical
related_files: [DUNE/Presentation/Wellness/WellnessView.swift]
related_solutions: []
---

# Solution: ScrollView Infinite Bounce — LazyVGrid + @Query Feedback Loop

## Problem

### Symptoms

- Wellness 탭에서 스크롤을 최하단으로 내리면 스크롤이 무한으로 위아래를 반복하며 튕김
- 때로는 시간이 지난 후 스크롤하면 정상 작동 (데이터 로딩 완료 후)
- Dashboard 탭(LazyVGrid 사용)과 Activity 탭(@Query 사용)에서는 발생하지 않음

### Root Cause

**LazyVGrid + @Query 조합**이 layout feedback loop를 형성:

1. `LazyVGrid`는 스크롤 위치에 따라 셀을 동적으로 로드/언로드하며, 이 과정에서 content size가 미세하게 변동
2. `@Query`(SwiftData)가 부모 WellnessView에 직접 있어서, DB 변경 감지 시 `body`가 재평가되고 ScrollView 전체가 re-layout
3. 스크롤 바운스 중 이 두 가지가 상호 작용: 바운스 → LazyVGrid 셀 재로드 → content size 변경 → 스크롤 위치 보정 → 다시 바운스

**핵심 발견**: WellnessView만 `LazyVGrid` + `@Query`를 동시에 가지고 있었음.
- DashboardView: LazyVGrid 사용, @Query 없음 → 정상
- ActivityView: @Query 사용, LazyVGrid 없음 → 정상
- WellnessView: LazyVGrid + @Query 둘 다 → 무한 바운스

### Failed Approaches (6회 시도)

| # | 접근 | 결과 | 배운 점 |
|---|------|------|---------|
| 1 | 조건부 ScrollView 렌더링 변경 | 실패 | ScrollView 자체 생성/파괴는 원인이 아님 |
| 2 | @State 캐시 + onChange 제거 | 실패 | 캐싱만으로는 body 재평가를 막지 못함 |
| 3 | @Query를 child view로 추출 (단독) | 실패 | LazyVGrid가 여전히 layout 불안정 유발 |
| 4 | .waveRefreshable → .refreshable 교체 | 실패 | 커스텀 refresh modifier는 원인이 아님 |
| 5 | **eager VStack grid + scrollBounceBehavior** | **성공** | LazyVGrid lazy loading이 핵심 원인 |
| 6 | Group wrapper 제거 | 실패 | Group은 원인이 아님 |

## Solution

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| WellnessView.swift | LazyVGrid → eager VStack+HStack `cardGrid()` | lazy 로드/언로드에 의한 layout 재계산 방지 |
| WellnessView.swift | `.scrollBounceBehavior(.basedOnSize)` 추가 | content가 영역 초과할 때만 바운스 허용 |
| WellnessView.swift | @Query를 `WellnessInjuryBannerView`, `BodyHistoryLinkView` child view로 추출 | SwiftData observation이 부모 body 재평가를 트리거하지 않도록 격리 |

### Key Code

```swift
// 1. Eager grid — stride 기반 row pairing + stable card identity
private func cardGrid(cards: [VitalCardData]) -> some View {
    let rows: [(left: VitalCardData, right: VitalCardData?)] = stride(from: 0, to: cards.count, by: 2).map { i in
        (left: cards[i], right: i + 1 < cards.count ? cards[i + 1] : nil)
    }
    return VStack(spacing: DS.Spacing.md) {
        ForEach(rows, id: \.left.id) { row in
            HStack(spacing: DS.Spacing.md) {
                NavigationLink(value: row.left.metric) { VitalCard(data: row.left) }
                    .buttonStyle(.plain)
                if let right = row.right {
                    NavigationLink(value: right.metric) { VitalCard(data: right) }
                        .buttonStyle(.plain)
                } else {
                    Color.clear
                }
            }
        }
    }
}

// 2. Scroll bounce behavior
ScrollView { ... }
    .scrollBounceBehavior(.basedOnSize)

// 3. Isolated @Query child view
private struct WellnessInjuryBannerView: View {
    @Query(sort: \InjuryRecord.startDate, order: .reverse) private var injuryRecords: [InjuryRecord]
    // ...body renders independently of parent
}
```

## Prevention

### Checklist Addition

- [ ] `LazyVGrid`와 `@Query`를 같은 View에서 사용하는지 확인 — 사용한다면 @Query를 child view로 격리
- [ ] ScrollView에 동적 content size 변경 요소(LazyVGrid, GeometryReader)가 있으면 `.scrollBounceBehavior(.basedOnSize)` 적용 검토
- [ ] 새 탭/섹션에 카드 그리드 추가 시 eager grid vs LazyVGrid 결정 — 카드 수가 20개 미만이면 eager grid 우선

### Rule Addition

`.claude/rules/` 에 추가할 규칙:
- **LazyVGrid + @Query 동일 View 금지**: @Query를 사용하는 View에서 LazyVGrid를 쓰면 scroll bounce feedback loop 위험. @Query를 격리된 child view로 추출하거나, eager grid(VStack+HStack)를 사용할 것.

## Lessons Learned

1. **조합 버그는 개별 제거로 진단**: LazyVGrid 단독, @Query 단독은 문제없었지만 조합이 문제. 다른 탭과 비교하여 "이 탭에만 있는 조합"을 찾는 것이 핵심
2. **성공한 수정은 즉시 커밋**: Fix 5가 이전 세션에서 효과가 있었지만 커밋되지 않아 context 소실로 작업을 반복. 효과 확인 즉시 커밋 필수
3. **`.scrollBounceBehavior(.basedOnSize)`는 방어적 안전장치**: 근본 원인(LazyVGrid)을 제거하더라도 추가 안전장치로서 가치가 있음
4. **"시간이 지나면 괜찮다"는 비동기 데이터 로딩 힌트**: 사용자의 "어쩌다가 시간이 지나서 내리면 괜찮을때가 있네"라는 피드백이 데이터 로딩 완료 후 @Observable 변경이 멈추면서 feedback loop가 종료됨을 의미
