---
tags: [whats-new, sf-symbol, layout, compact, ui]
date: 2026-03-08
category: plan
status: approved
---

# Plan: What's New SF Symbol 영역 축소 + 상세화면 레이아웃 변경

## Summary

What's New 카탈로그의 138px thumbnail 카드와 260px hero 카드를 제거하고, 40x40 인라인 아이콘으로 교체하여 텍스트 중심 레이아웃으로 전환한다.

## Affected Files

| File | Change | Risk |
|------|--------|------|
| `DUNE/Presentation/WhatsNew/WhatsNewView.swift` | WhatsNewFeatureRow, WhatsNewFeatureDetailView 리팩토링, WhatsNewFeatureCard 제거 | Low — private 컴포넌트, 외부 의존 없음 |

## Implementation Steps

### Step 1: WhatsNewFeatureRow 리팩토링

**변경**: 138px thumbnail 카드를 40x40 인라인 아이콘으로 교체

**Before**:
```swift
VStack(alignment: .leading, spacing: DS.Spacing.md) {
    VStack(alignment: .leading, spacing: DS.Spacing.sm) {
        HStack(spacing: DS.Spacing.sm) {
            WhatsNewBadge(...)
            Image(systemName: feature.symbolName)  // caption size
        }
        Text(feature.title)
        Text(feature.summary)
    }
    WhatsNewFeatureCard(feature: feature, style: .thumbnail)
        .frame(height: 138)
}
```

**After**:
```swift
HStack(alignment: .top, spacing: DS.Spacing.md) {
    Image(systemName: feature.symbolName)
        .font(.system(size: 20, weight: .semibold))
        .foregroundStyle(.white)
        .frame(width: 40, height: 40)
        .background(tintColor.gradient, in: RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))

    VStack(alignment: .leading, spacing: DS.Spacing.sm) {
        WhatsNewBadge(...)
        Text(feature.title)
        Text(feature.summary)
    }
}
```

**Verification**: Row 높이가 텍스트 콘텐츠에 의해 자연 결정됨

### Step 2: WhatsNewFeatureDetailView 리팩토링

**변경**: 260px hero 카드를 제거하고 인라인 아이콘+배지 헤더로 교체

**Before**:
```swift
VStack(alignment: .leading, spacing: DS.Spacing.xl) {
    WhatsNewFeatureCard(feature: feature, style: .hero)
        .frame(height: 260)
    // title, summary, release intro below
}
```

**After**:
```swift
VStack(alignment: .leading, spacing: DS.Spacing.xl) {
    HStack(alignment: .top, spacing: DS.Spacing.md) {
        Image(systemName: feature.symbolName)
            .font(.system(size: 20, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 40, height: 40)
            .background(tintColor.gradient, in: RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))

        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            WhatsNewBadge(...)
            Text(feature.title)
                .font(.system(.title2, design: .rounded, weight: .bold))
            Text(feature.summary)
        }
        Spacer(minLength: 0)
        WhatsNewVersionBadge(version: release.version)
    }
    StandardCard { ... }
}
```

**Verification**: 상세화면 진입 시 텍스트가 즉시 보임

### Step 3: WhatsNewFeatureCard 및 관련 코드 제거

**삭제 대상**:
- `WhatsNewFeatureCard` struct (lines 195-266) — private, 외부 사용 없음
- `WhatsNewStyle.secondarySymbol(for:)` (lines 288-303) — decorative secondary symbol, 더 이상 사용 안 함

**유지 대상**:
- `WhatsNewStyle.tintColor(for:)` — 인라인 아이콘 배경에 계속 사용
- `WhatsNewBadge` — row와 detail 모두에서 사용
- `WhatsNewVersionBadge` — detail에서 사용

**Verification**: 빌드 성공, 미참조 심볼 없음

## Test Strategy

- **기존 테스트**: `WhatsNewManagerTests.swift`는 JSON 파싱/데이터 로직만 테스트하므로 변경 불필요
- **UI 테스트**: View body 변경은 테스트 면제 대상 (testing-required.md)
- **수동 검증**: Preview로 리스트/상세화면 레이아웃 확인

## Risks & Edge Cases

| Risk | Mitigation |
|------|------------|
| accessibilityIdentifier 변경 | `whatsnew-card-*` identifier는 WhatsNewFeatureCard에만 있어 삭제됨. row/detail identifier는 유지 |
| 긴 feature title wrap | HStack + VStack 구조로 자연 wrap 가능 |
| iPad 가로 모드 | 텍스트 중심이므로 오히려 개선됨 |

## Alternatives Considered

1. **카드 높이만 축소 (138→80)**: 여전히 불필요한 공간 차지, 근본 해결 안 됨
2. **카드 완전 제거 + 아이콘 없음**: SF Symbol 시각 단서가 사라져 area 구분이 어려워짐
3. **선택안: 인라인 아이콘**: 시각 단서 유지 + 공간 최소화 — 최적
