---
tags: [theme, ocean, wave, design-system, animation, ui]
date: 2026-03-01
category: brainstorm
status: draft
---

# Ocean Cool Theme — Premium 해양 테마

## Problem Statement

현재 앱은 Desert Warm 단일 테마만 지원. ThemePickerSection에 Ocean Cool이 "Coming Soon"으로 존재하나 구현 없음.
사용자가 원하는 것: **진짜 파도처럼 보이는** 다층 해양 물결 효과 + 전체 UI 색상 테마 전환.

## Scope

- **구현 범위**: Tier 3 (Premium) + 전체 UI 테마
- **Wave 효과**: OceanWaveShape (비대칭 파형) + 3-4 레이어 Parallax + Swell 변조
- **테마 깊이**: Wave 배경 + 탭바 tint + 카드/차트/아이콘 전체 색상 교체

## 참고 이미지

머니투데이 해안 사진 — 핵심 시각 요소:
- **깊이감**: 먼 파도(어두운 남색) → 가까운 파도(밝은 청록)
- **Parallax**: 각 층이 다른 속도로 움직임
- **비대칭 파형**: 뾰족한 마루(crest) + 완만한 골(trough)
- **Foam**: 파도 꼭대기의 흰 포말

---

## 1. OceanWaveShape — 비대칭 파형

### 현재 WaveShape
단일 sine: `y = A * sin(kx + phase)` — 대칭적, 기계적

### OceanWaveShape (새 Shape)
Harmonic enrichment: `y = A * [sin(θ) + steepness * sin(2θ + offset)]`

```swift
struct OceanWaveShape: Shape {
    let amplitude: CGFloat
    let frequency: CGFloat
    var phase: CGFloat              // Animatable
    let verticalOffset: CGFloat
    let steepness: CGFloat          // 0.0 (sine) ~ 0.5 (very sharp crest)
    let harmonicOffset: CGFloat     // Second harmonic phase offset

    // Pre-computed points (same pattern as WaveShape)
    // path(in:) evaluates: sin(angle + phase) + steepness * sin(2*angle + phase + harmonicOffset)
}
```

**시각 효과**: steepness=0.3일 때 뾰족한 마루 + 넓고 완만한 골 → 실제 파도 실루엣

### 성능 고려
- 기존 120 sample points 유지
- 추가 연산: sample당 sin() 1회 추가 (총 2회) → ~미미
- `animatableData`는 phase만 (기존과 동일)

---

## 2. 다층 Parallax 합성 (3-4 레이어)

### 레이어 구성

| 레이어 | Shape | 색상 | 진폭 | 주파수 | 속도 | 방향 | 불투명도 |
|--------|-------|------|------|--------|------|------|----------|
| Deep | OceanWaveShape (steepness: 0.1) | `oceanDeep` | 0.025 | 1.0 | 10s | → | 0.07 |
| Mid | OceanWaveShape (steepness: 0.2) | `oceanMid` | 0.045 | 1.5 | 7s | ← | 0.11 |
| Surface | OceanWaveShape (steepness: 0.35) | `oceanSurface` | 0.07 | 2.0 | 5s | → | 0.15 |
| Foam | WaveShape (기존 sine) | `oceanFoam` | 0.008 | 2.0 | 5s | → (Surface 추적) | 0.06 |

### Parallax 깊이감
- **속도 차이**: 10s / 7s / 5s — 멀리 느리고 가까이 빠름
- **진폭 차이**: 작음 → 큼 — 멀리 작고 가까이 큼
- **투명도 차이**: 낮음 → 높음 — 멀리 흐리고 가까이 선명
- **역방향 Mid 레이어**: 교차 해류 효과, 자연스러운 복잡성 추가

### OceanWaveOverlayView (새 컴포넌트)
```swift
struct OceanWaveOverlayView: View {
    var color: Color
    var opacity: Double
    var amplitude: CGFloat
    var frequency: CGFloat
    var verticalOffset: CGFloat
    var bottomFade: CGFloat
    var driftDuration: TimeInterval = 6  // NEW: 레이어별 속도 제어
    var driftDirection: DriftDirection = .forward  // NEW: 방향 제어
    var steepness: CGFloat = 0  // NEW: 0이면 기존 sine, >0이면 ocean

    enum DriftDirection { case forward, reverse }
}
```

---

## 3. Swell 진폭 변조

실제 바다의 "파도 세트" — 큰 파도 그룹이 주기적으로 도착.

```swift
// 20초 주기로 진폭이 70%~100% 범위에서 변동
let swellMultiplier = 0.85 + 0.15 * sin(swellPhase)
// swellPhase: 0→2π in 20s, separate animation
```

- Surface + Foam 레이어에만 적용 (Deep/Mid는 안정적)
- `accessibilityReduceMotion` 시 비활성화

---

## 4. Ocean Cool 색상 팔레트

### Wave 전용 색상 (xcassets)

| 토큰 | Light Mode | Dark Mode | 용도 |
|------|------------|-----------|------|
| `OceanDeep` | #2C4A6B | #1B2838 | 가장 먼 파도, 배경 그라데이션 하단 |
| `OceanMid` | #2E8B9E | #1A6B7A | 중간 파도 |
| `OceanSurface` | #3CB4C8 | #4DC8DB | 가장 가까운 파도, 메인 액센트 |
| `OceanFoam` | #E8F4F8 | #D0EBF0 | 파도 마루 하이라이트 |
| `OceanMist` | #8BA5B5 | #A0BCC8 | 부드러운 회청 (보조 텍스트) |

### 전체 UI 테마 색상 매핑

| Desert Warm 토큰 | Ocean Cool 대체 | 역할 |
|------------------|----------------|------|
| `AccentColor` (warmGlow) | `OceanAccent` (oceanSurface 기반) | 앱 전체 액센트 |
| `DesertBronze` | `OceanBronze` (깊은 청록) | Hero 텍스트 그라데이션 |
| `DesertDusk` | `OceanDusk` (남색) | 보조 그라데이션, 링 하단 |
| `SandMuted` | `OceanSand` (밝은 회청) | 장식 텍스트 |
| `TabTrain` | `OceanTrain` (활기찬 청록) | Activity 탭 파도 |
| `TabWellness` | `OceanWellness` (깊은 남색) | Wellness 탭 파도 |
| `TabLife` | `OceanLife` (부드러운 회청) | Life 탭 파도 |
| `CardBackground` | `OceanCardBackground` | 카드 배경 (약간 푸른 톤) |

### 차트/메트릭 색상
- Score gradient: 따뜻한 톤 → 차가운 톤 변환 (green/teal/blue/indigo/purple)
- Metric 색상: 독립적 (HRV, RHR 등은 테마와 무관하게 유지)
- Activity category: Ocean 팔레트로 재매핑 (Cardio=Teal, Strength=Navy 등)

### 그라데이션

| Desert Warm | Ocean Cool |
|-------------|------------|
| heroText: Bronze → WarmGlow | heroText: OceanBronze → OceanSurface |
| detailScore: Bronze → Dusk | detailScore: OceanBronze → OceanDusk |
| sectionAccent: WarmGlow → Dusk | sectionAccent: OceanSurface → OceanDusk |
| tabBackground: color → WarmGlow → clear | tabBackground: color → OceanDeep → clear |

---

## 5. 테마 스위칭 인프라

### AppTheme enum

```swift
enum AppTheme: String, CaseIterable, Codable, Sendable {
    case desertWarm
    case oceanCool
    // case forestGreen (future)
}
```

### 색상 resolver

```swift
extension AppTheme {
    var accentColor: Color { ... }
    var tabTodayColor: Color { ... }
    var tabTrainColor: Color { ... }
    var tabWellnessColor: Color { ... }
    var tabLifeColor: Color { ... }
    var heroTextGradient: LinearGradient { ... }
    var detailScoreGradient: LinearGradient { ... }
    // ... 모든 테마 의존 토큰
}
```

### 저장소
- `UserDefaults` + bundle prefix (`com.dune.app.theme`)
- `@AppStorage` binding in SettingsView
- iCloud KVS 동기화 가능 (NSUbiquitousKeyValueStore)

### 전파 메커니즘

**Option A: Environment 전파 (선호)**
```swift
// ContentView
.environment(\.appTheme, selectedTheme)

// 하위 View에서
@Environment(\.appTheme) private var theme
// color 참조: theme.accentColor
```

**Option B: DS 토큰 동적 교체**
- Asset catalog에서 theme별 색상 세트 분리
- 런타임에 active 세트 전환
- 장점: 기존 `DS.Color.warmGlow` 호출 코드 변경 불필요
- 단점: Asset catalog 런타임 전환이 SwiftUI에서 불안정

→ **Option A 선호**: 명시적이고 컴파일 타임 안전

### Wave 배경 분기

```swift
// TabWaveBackground 내부
switch theme {
case .desertWarm:
    DesertWaveContent(preset: preset, color: color, atmosphere: atmosphere)
case .oceanCool:
    OceanWaveContent(preset: preset)  // 자체 4-레이어 합성
}
```

또는 별도 View:
```swift
struct OceanTabWaveBackground: View { ... }  // 4-레이어 전용
struct DesertTabWaveBackground: View { ... }  // 현재 로직 추출
```

---

## 6. 탭별 Ocean 파도 캐릭터

| 탭 | 캐릭터 | Surface 진폭 | 주파수 | Swell | 레이어 수 |
|----|--------|-------------|--------|-------|----------|
| Today | 잔잔한 해변 | 0.05 | 1.5 | ✓ (약) | 3 |
| Train | 거친 바다 | 0.09 | 2.5 | ✓ (강) | 4 (Foam 포함) |
| Wellness | 깊은 바다 | 0.04 | 1.2 | ✗ | 3 |
| Life | 호수 같은 잔잔함 | 0.03 | 1.0 | ✗ | 2 |

---

## 7. 영향 범위 (전체 UI 테마)

### Wave 시스템
- `WaveShape.swift` — OceanWaveShape 추가
- `WavePreset.swift` — Ocean 전용 프리셋 or OceanWavePreset
- `WaveOverlayView` — driftDuration, direction, steepness 파라미터
- 새 파일: `OceanTabWaveBackground.swift`, `OceanDetailWaveBackground.swift`, `OceanSheetWaveBackground.swift`

### Design System
- `DesignSystem.swift` — Ocean 색상 토큰, 그라데이션, 애니메이션 추가
- `AppTheme.swift` — 새 파일, 테마 enum + resolver
- Asset catalog — Ocean 색상 세트 20+ 항목

### UI 전파 (주요)
- `ContentView.swift` — 테마 기반 environment 설정
- `ThemePickerSection.swift` — 실제 선택 기능 활성화
- `SettingsView.swift` — 테마 저장/로드
- Hero card, score display, section headers — 그라데이션 교체
- 카드 배경, 테두리 색상 — 테마 대응

### 예상 수정 파일 수
- **핵심 변경**: 10-15 파일 (Wave, DS, Theme infra, ContentView)
- **색상 전파**: 20-30 파일 (모든 DS.Color.warmGlow, DS.Gradient 참조)
- **Asset catalog**: 20+ 색상 항목 추가

---

## 8. 구현 순서 제안

### Phase 1: 인프라 (F2)
1. AppTheme enum + UserDefaults 저장
2. Ocean 색상 토큰 (xcassets)
3. ThemePickerSection 활성화
4. Environment 전파 (`\.appTheme`)

### Phase 2: Wave 효과 (F3)
1. OceanWaveShape (비대칭 파형)
2. OceanWaveOverlayView (속도/방향 파라미터)
3. OceanTabWaveBackground (4-레이어 합성)
4. Ocean Detail/Sheet backgrounds
5. Swell 진폭 변조

### Phase 3: 전체 UI 테마 (F2)
1. DS 토큰 → 테마 대응 (그라데이션, 카드, 텍스트)
2. 탭 색상 매핑
3. 차트/메트릭 색상 조정
4. Light/Dark 모드 양쪽 검증

### Phase 4: 폴리싱 (F1)
1. 테마 전환 애니메이션 (smooth cross-fade)
2. 접근성 (Reduce Motion, 고대비)
3. Watch 테마 동기화 (WCSession)

---

## Open Questions

1. **Score gradient 테마화**: Score 색상(Excellent~Warning)도 Ocean 팔레트로 바꿀지, 아니면 테마 독립으로 유지할지?
2. **Weather 상호작용**: Ocean 테마에서 날씨 반응형 파도도 유지할지? (비 올 때 거친 바다 등)
3. **Watch 동기화**: Watch에서도 Ocean 테마를 적용할지? (WatchOS wave는 단순화 필요)
4. **전환 모션**: 테마 전환 시 파도가 바뀌는 transition 효과 (cross-fade vs morphing)?
5. **Metric 색상**: HRV/RHR 등 메트릭 고유 색상은 테마 독립 유지할지?
