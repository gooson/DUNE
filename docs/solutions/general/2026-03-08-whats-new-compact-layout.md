---
tags: [whats-new, sf-symbol, layout, compact, ui-refactor, card-removal]
category: general
date: 2026-03-08
severity: minor
related_files: [DUNE/Presentation/WhatsNew/WhatsNewView.swift]
related_solutions: [2026-03-07-whats-new-toolbar-tipkit-entrypoint.md]
---

# Solution: What's New SF Symbol 카드를 인라인 아이콘으로 축소

## Problem

### Symptoms

- What's New 리스트의 각 feature row가 138px 높이의 SF Symbol thumbnail 카드를 포함하여 불필요하게 넓은 공간 차지
- 상세화면에서 260px hero 카드가 화면 상단을 지배하여 텍스트 콘텐츠가 스크롤해야 보임
- SF Symbol 카드가 decorative secondary symbol까지 표시하여 시각적 노이즈 증가

### Root Cause

`WhatsNewFeatureCard` 구조체가 `.thumbnail`(138px)과 `.hero`(260px) 두 가지 스타일로 SF Symbol을 크게 표시하도록 설계되어 있었음. 카드 내부에 primary + secondary symbol, gradient 배경, 장식용 아이콘이 포함되어 면적 대비 정보 밀도가 낮았음.

## Solution

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `WhatsNewView.swift` | `WhatsNewFeatureRow`: VStack+카드 → HStack+40x40 인라인 아이콘 | 텍스트 중심 레이아웃으로 전환 |
| `WhatsNewView.swift` | `WhatsNewFeatureDetailView`: hero 카드 → 인라인 아이콘+배지 헤더 | 텍스트가 즉시 보이도록 개선 |
| `WhatsNewView.swift` | `WhatsNewFeatureCard` struct 삭제 (75줄) | 더 이상 참조 없음 |
| `WhatsNewView.swift` | `WhatsNewStyle.secondarySymbol(for:)` 삭제 (16줄) | 카드 전용 decorative symbol |

### Key Code

```swift
// 인라인 아이콘 패턴 (Row + Detail 공통)
Image(systemName: feature.symbolName)
    .font(.system(size: 20, weight: .semibold))
    .foregroundStyle(.white)
    .frame(width: 40, height: 40)
    .background(
        tintColor.gradient,
        in: RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
    )
    .accessibilityHidden(true)
```

## Prevention

### Checklist Addition

- [ ] SF Symbol 표시 영역이 40x40을 초과하면 정보 밀도 대비 공간 효율성 검토

### Rule Addition (if applicable)

해당 없음 — 프로젝트 전반 규칙이 아닌 What's New 특화 결정

## Lessons Learned

- 카탈로그형 UI에서 큰 decorative 카드는 초기에는 시각적으로 인상적이지만, 콘텐츠가 늘어나면 스크롤 부담이 됨
- SF Symbol은 작은 크기(20pt)에서도 area별 tint color gradient 배경과 함께 충분한 시각적 구분을 제공
- private struct + 단일 파일 스코프 변경은 영향 범위가 명확하여 안전한 리팩토링 대상
