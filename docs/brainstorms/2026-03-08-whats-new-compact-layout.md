---
tags: [whats-new, sf-symbol, layout, compact, ui]
date: 2026-03-08
category: brainstorm
status: draft
---

# Brainstorm: What's New SF Symbol 영역 축소 + 상세화면 레이아웃 변경

## Problem Statement

What's New 카탈로그의 SF Symbol 카드 영역이 불필요하게 큰 공간을 차지하여 정보 밀도가 낮다.

**현재 문제점**:
- 리스트 Row: 138px 높이의 thumbnail 카드가 row 하단에 배치 → 실제 정보(title, summary)보다 장식 영역이 더 큼
- 상세화면: 260px 높이의 hero 카드가 상단에 배치 → 스크롤 없이 텍스트 정보가 거의 보이지 않음
- SF Symbol 자체는 유용한 시각 단서이지만, 전용 카드 영역은 과도함

## Target Users

- 앱 업데이트 후 새 기능을 빠르게 훑어보려는 사용자
- Settings > About에서 변경사항을 확인하려는 사용자

## Success Criteria

1. 리스트 Row에서 SF Symbol이 시각적 단서로 유지되되, 텍스트 중심 레이아웃으로 전환
2. 상세화면에서 hero 카드 없이 텍스트 정보가 즉시 보임
3. 기존 area별 tint color, badge 등 브랜딩 요소는 보존

## Proposed Approach

### A. 리스트 Row: 카드 → 인라인 아이콘

**Before** (현재):
```
+-------------------------------+
| [Activity] icon               |
| Exercise Volume Analysis      |
| Track your training load...   |
| +---------------------------+ |
| |  SF Symbol card 138px     | |
| |  gradient bg + icon       | |
| +---------------------------+ |
+-------------------------------+
```

**After** (제안):
```
+-------------------------------+
| icon   [Activity]             |
| 28pt   Exercise Volume...     |
|        Track your...     [>]  |
+-------------------------------+
```

**변경 사항**:
- `WhatsNewFeatureCard(style: .thumbnail)` + `.frame(height: 138)` 제거
- SF Symbol 아이콘을 Row 왼쪽에 ~28pt로 배치
- area tint color를 아이콘 배경 원(circle)에 적용
- Row 높이가 텍스트 콘텐츠에 의해 자연스럽게 결정됨

**구현 방향**:
```swift
// WhatsNewFeatureRow 변경
HStack(alignment: .top, spacing: DS.Spacing.md) {
    // SF Symbol icon with tint background
    Image(systemName: feature.symbolName)
        .font(.system(size: 20, weight: .semibold))
        .foregroundStyle(.white)
        .frame(width: 40, height: 40)
        .background(tintColor.gradient, in: RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))

    VStack(alignment: .leading, spacing: DS.Spacing.sm) {
        WhatsNewBadge(title: feature.area.badgeTitle, tint: tintColor)
        Text(feature.title)
            .font(DS.Typography.sectionTitle)
        Text(feature.summary)
            .font(.subheadline)
            .foregroundStyle(DS.Color.textSecondary)
            .lineLimit(3)
    }
}
```

### B. 상세화면: Hero 카드 제거, 텍스트 중심

**Before** (현재):
```
+------------------------------+
| +- Hero Card 260px ---------+|
| | gradient + SF Symbol 64pt ||
| +---------------------------+|
| [Activity]      v0.2.0       |
| Exercise Volume Analysis     |
| Description...               |
| +- Release intro -----------+|
+------------------------------+
```

**After** (제안):
```
+------------------------------+
| icon [Activity]    v0.2.0    |
| 28pt                         |
| Exercise Volume Analysis     |
| Description of the feature   |
| goes here with full detail   |
|                              |
| +- Release intro -----------+|
+------------------------------+
```

**변경 사항**:
- `WhatsNewFeatureCard(style: .hero)` + `.frame(height: 260)` 제거
- Badge + icon을 인라인 헤더로 전환 (리스트 Row와 동일한 패턴)
- 텍스트 영역이 즉시 보여 정보 접근성 향상

**구현 방향**:
```swift
// WhatsNewFeatureDetailView 변경
ScrollView {
    VStack(alignment: .leading, spacing: DS.Spacing.xl) {
        // Inline header (hero 카드 대체)
        HStack(alignment: .top, spacing: DS.Spacing.md) {
            Image(systemName: feature.symbolName)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .background(tintColor.gradient, in: RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))

            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                WhatsNewBadge(title: feature.area.badgeTitle, tint: tintColor)
                Text(feature.title)
                    .font(.system(.title2, design: .rounded, weight: .bold))
            }

            Spacer(minLength: 0)
            WhatsNewVersionBadge(version: release.version)
        }

        Text(feature.summary)
            .font(.subheadline)
            .foregroundStyle(DS.Color.textSecondary)
            .fixedSize(horizontal: false, vertical: true)

        StandardCard {
            Text(release.intro)
                .font(.subheadline)
                .foregroundStyle(DS.Color.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
    .padding(DS.Spacing.lg)
}
```

### C. WhatsNewFeatureCard 정리

CardStyle의 `.hero`와 `.thumbnail` 모두 사용되지 않게 되므로:
- `WhatsNewFeatureCard` struct 전체 제거
- `CardStyle` enum 제거
- `WhatsNewStyle.secondarySymbol(for:)` → 더 이상 decorative secondary symbol 불필요, 제거 가능

## Constraints

| 제약 | 대응 |
|------|------|
| 기존 accessibilityIdentifier 유지 | `whatsnew-row-{id}`, `whatsnew-detail-{id}` 패턴 보존 |
| area tint color 브랜딩 | 아이콘 배경에 gradient 적용으로 유지 |
| 3개 언어 지원 | 텍스트 중심이므로 오히려 개선됨 |

## Edge Cases

1. **긴 title**: 텍스트 중심이므로 자연스럽게 wrap (개선됨)
2. **많은 feature 항목**: Row가 컴팩트해져 스크롤 양 감소 (개선됨)
3. **iPad 가로 모드**: 텍스트 중심 레이아웃이 더 자연스러움

## Scope

### MVP (Must-have)
- [ ] `WhatsNewFeatureRow` 리팩토링: 카드 제거 + 인라인 아이콘
- [ ] `WhatsNewFeatureDetailView` 리팩토링: hero 카드 제거 + 텍스트 중심
- [ ] `WhatsNewFeatureCard` struct 제거
- [ ] 기존 테스트/Preview 업데이트

### Nice-to-have (Future)
- [ ] 아이콘에 subtle animation (scale on appear)
- [ ] area별 아이콘 배경 형태 다양화 (circle, rounded rect 등)

## Open Questions

없음 — 방향이 명확합니다.

## Next Steps

- [ ] `/plan whats-new-compact-layout` 으로 구현 계획 생성
