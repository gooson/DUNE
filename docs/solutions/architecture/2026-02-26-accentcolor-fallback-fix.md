---
tags: [swiftui, accentColor, asset-catalog, color, design-system, xcodegen]
date: 2026-02-26
category: architecture
status: implemented
---

# Color.accentColor가 시스템 파란색으로 Fallback되는 문제

## Problem

Today 탭의 웨이브 배경과 히어로 카드가 앱 아이콘의 warm orange-gold (#C9956B)가 아닌 **시스템 기본 파란색**으로 렌더링됨.

### 근본 원인

`SwiftUI.Color.accentColor`는 `ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME` 빌드 설정이 지정되어 있을 때만 asset catalog의 `AccentColor`를 반환함. 이 설정이 `project.yml`에 없으면 **iOS 시스템 기본 파란색**으로 fallback.

- `Color.accentColor` → 빌드 설정 기반, fallback = 시스템 파란색
- `Color("AccentColor")` → asset catalog에서 직접 로드, 항상 정확한 값

### 영향 범위

- `DS.Color.warmGlow` (DesignSystem 토큰)
- `DashboardView` — TabWaveBackground, waveRefreshable
- `ConditionHeroView` — scoreGradient

## Solution

### 1. DS.Color.warmGlow 정의 수정

```swift
// Before: 시스템 accent color (파란색 fallback)
static let warmGlow = SwiftUI.Color.accentColor

// After: asset catalog에서 직접 로드 (항상 #C9956B)
static let warmGlow = SwiftUI.Color("AccentColor")
```

### 2. DashboardView 색상 참조 변경

```swift
.background { TabWaveBackground(primaryColor: DS.Color.warmGlow) }
.waveRefreshable(color: DS.Color.warmGlow) { ... }
```

### 3. ConditionHeroView 색상 참조 변경

```swift
static let scoreGradient = LinearGradient(
    colors: [DS.Color.warmGlow, DS.Color.warmGlow.opacity(0.7)],
    ...
)
```

### 변경 파일

| 파일 | 변경 |
|------|------|
| `Presentation/Shared/DesignSystem.swift` | `warmGlow` 정의 수정 |
| `Presentation/Dashboard/DashboardView.swift` | 색상 참조 → `DS.Color.warmGlow` |
| `Presentation/Dashboard/Components/ConditionHeroView.swift` | 색상 참조 → `DS.Color.warmGlow` |

## Prevention

1. **브랜드 컬러에 `.accentColor` 직접 사용 금지**: `Color("AccentColor")` 또는 DS 토큰 경유
2. **새 color 토큰 추가 시**: `.accentColor` 의존 여부 확인. xcodegen 환경에서는 빌드 설정 누락 가능성 상존
3. **시각적 검증**: 색상 변경 후 다크 모드에서 실제 렌더링 확인 필수

## Lessons Learned

- `Color.accentColor`와 `Color("AccentColor")`는 다른 메커니즘. 전자는 빌드 설정 의존, 후자는 asset catalog 직접 참조
- xcodegen 프로젝트에서는 Xcode가 자동 설정하는 빌드 설정이 누락될 수 있음
- 시뮬레이터에서 파란색이 보이면 AccentColor fallback을 먼저 의심
