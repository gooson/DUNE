---
tags: [hero-card, cta, button, navigation-link, swiftui, gesture-conflict]
date: 2026-03-06
category: solution
status: implemented
---

# Hero Card CTA Button Pattern

## Problem

Hero 카드에 CTA 버튼을 추가할 때, `NavigationLink` 내부에 `Button`을 배치하면 제스처 충돌이 발생한다. 버튼 탭 시 NavigationLink의 push navigation도 동시에 트리거된다.

## Solution

CTA 버튼을 `NavigationLink` **외부**에 독립 배치한다. `VStack`으로 NavigationLink와 CTA 버튼을 감싸는 구조.

```swift
VStack(spacing: DS.Spacing.sm) {
    // Hero card inside NavigationLink
    NavigationLink(value: destination) {
        HeroCard(...)
    }
    .buttonStyle(.plain)

    // CTA button outside NavigationLink
    if let data = viewModel.data {
        Button {
            action()
        } label: {
            Label("Start Workout", systemImage: "play.fill")
                .font(.subheadline)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .buttonBorderShape(.capsule)
        .tint(data.status.color)
    }
}
```

### CTA 스타일 패턴

- `.borderedProminent` + `.buttonBorderShape(.capsule)` — 기존 앱 CTA 패턴과 일관
- `.font(.subheadline)` + `.fontWeight(.semibold)` — 정보 밀도 유지
- `.tint(contextColor)` — hero 카드 상태 색상과 매칭
- `.frame(maxWidth: .infinity)` — 카드 너비에 맞춤

## Prevention

- Hero 카드에 interactive 요소를 추가할 때는 항상 NavigationLink 외부 배치 검토
- `HeroCard` 컴포넌트 자체에 `onAction` closure를 추가하지 않음 (소비자 View에서 구조적 분리)

## Related

- Life Hero 업그레이드: `StandardCard` → `HeroCard` + narrative message
- `ProgressRingView` 재사용으로 일관된 링 UI 유지
