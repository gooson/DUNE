---
tags: [swiftui, theme, button, sf-symbol, template]
category: general
date: 2026-03-12
severity: minor
related_files:
  - DUNE/Presentation/Exercise/Components/CreateTemplateView.swift
related_solutions:
  - docs/solutions/architecture/2026-03-03-theme-prefix-resolver-shared-extension.md
---

# Solution: Template Generate Button Icon Visibility

## Problem

`TemplateFormView`의 AI 템플릿 생성 버튼에서 일부 테마 사용 시 텍스트만 보이고 leading SF Symbol icon이 사라졌다.

### Symptoms

- `Generate Template` 버튼에 `wand.and.stars` 아이콘이 보이지 않는다.
- 테마 tint는 정상 반영되지만, 아이콘이 빠져 CTA affordance가 약해진다.

### Root Cause

버튼 label이 기본 `Label` 렌더링에 의존하고 있었고, 테마 tint 및 상위 label rendering 환경 변화가 겹치면서 icon 노출이 불안정해졌다.

## Solution

버튼 label을 명시적인 `HStack + Image + Text` 구조로 바꾸고, tint를 현재 `appTheme.accentColor`에 직접 연결했다.

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `DUNE/Presentation/Exercise/Components/CreateTemplateView.swift` | `Label`을 `HStack + Image + Text`로 교체하고 `theme.accentColor` tint 추가 | 아이콘 렌더링을 직접 제어하고 테마별 CTA 색상을 명시적으로 고정하기 위해 |

### Key Code

```swift
@Environment(\.appTheme) private var theme

Button {
    Task { await generateTemplateFromPrompt() }
} label: {
    HStack(spacing: DS.Spacing.xs) {
        Image(systemName: "wand.and.stars")
            .symbolRenderingMode(.monochrome)
        Text("Generate Template")
    }
    .font(.subheadline.weight(.semibold))
}
.buttonStyle(.borderedProminent)
.tint(theme.accentColor)
```

## Prevention

아이콘이 필수 affordance인 CTA는 기본 `Label` 렌더링에만 의존하지 말고, 테마/스타일 영향을 많이 받는 화면에서는 icon/text 구조를 명시적으로 그린다.

### Checklist Addition

- [ ] 테마 tint가 들어가는 주요 CTA에서 icon이 `LabelStyle` 변화 없이 항상 보이는지 확인한다.

### Rule Addition (if applicable)

새 rule 파일은 추가하지 않았다. 동일 증상이 반복되면 theme-aware CTA 렌더링 규칙으로 승격을 검토한다.

## Lessons Learned

SwiftUI의 기본 `Label`은 대부분 충분하지만, 테마와 시스템 버튼 스타일이 겹치는 CTA에서는 명시적 `Image + Text` 구성이 더 안정적이다.
