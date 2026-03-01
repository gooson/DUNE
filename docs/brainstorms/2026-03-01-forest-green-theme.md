---
tags: [theme, forest, ukiyo-e, design-system, animation, ui, texture]
date: 2026-03-01
category: brainstorm
status: draft
---

# Forest Green Theme — 우키요에 숲 테마

## Problem Statement

현재 앱은 Desert Warm + Ocean Cool 2개 테마를 지원. ThemePickerSection에 Forest Green이 "Coming Soon"으로 존재하나 구현 없음.
사용자가 원하는 것: **우키요에(浮世絵) 목판화 스타일**의 산/숲 실루엣 배경 + 붉은 단풍/금빛 악센트 + 목판화 질감(grain, bokashi, 불균일 엣지) + 전체 UI 색상 테마 전환.

## 참고 이미지 분석

5장의 참고 이미지에서 추출한 핵심 요소:

| 요소 | 설명 |
|------|------|
| **색감** | 깊은 초록(#2D5A3D) → 연한 안개 초록(#8FB996) + 붉은 단풍(#C73E1D) + 금빛(#D4A843) |
| **형태** | 중첩된 산등성이/숲 스카이라인 실루엣, 유기적 곡선 |
| **질감** | 목판화 grain, bokashi(色ぼかし) 그라데이션, 불균일 잉크 엣지 |
| **분위기** | 안개 낀 숲속, 빛줄기, 반딧불/꽃잎 파티클 |
| **깊이** | 전경(진한) → 중경(중간) → 원경(연한) 패럴랙스 |

## Scope

- **구현 범위**: 전체 (배경 + 색상 + 아이콘 대안)
- **플랫폼**: iOS + watchOS 동시
- **배경 효과**: ForestSilhouetteShape (산/숲 실루엣) + 3레이어 Parallax + 우키요에 질감 오버레이
- **테마 깊이**: 배경 + 탭바 tint + 카드/차트/아이콘 전체 색상 교체

---

## 1. ForestSilhouetteShape — 산/숲 스카이라인

### 기존 테마 비교

| 테마 | Shape | 핵심 곡선 | 특징 |
|------|-------|----------|------|
| Desert | WaveShape (sine) | 매끄러운 사인파 | 기하학적, 단순 |
| Ocean | OceanWaveShape (harmonic) | 비대칭 파도 | 유기적, 복잡 |
| **Forest** | **ForestSilhouetteShape** | **산등성이 + 나무 실루엣** | **우키요에, 불규칙** |

### Shape 설계

```swift
struct ForestSilhouetteShape: Shape {
    let amplitude: CGFloat        // 산 높이 비율 (0.03~0.08)
    let frequency: CGFloat        // 봉우리 밀도 (1.0~3.0)
    var phase: CGFloat            // Animatable — 수평 드리프트
    let verticalOffset: CGFloat   // 기준선 위치 (0.5)
    let ruggedness: CGFloat       // 불규칙도 (0.0=매끄러운 언덕, 1.0=울퉁불퉁 산)
    let treeDensity: CGFloat      // 나무 실루엣 밀도 (0.0~1.0)

    // Pre-computed 120 sample points
    // path(in:): base ridge + harmonic noise + tree silhouette bumps
}
```

**파형 공식**:
```
y = A * [sin(θ) + ruggedness * sin(3θ + offset) + treeDensity * trianglePulse(θ)]
```

- `sin(θ)`: 주 산등성이 곡선
- `ruggedness * sin(3θ)`: 3차 하모닉으로 울퉁불퉁한 산세
- `trianglePulse(θ)`: 간헐적 삼각 펄스로 나무 꼭대기 실루엣

### 시각 효과

```
         /\    /\     ← 나무 실루엣 (triangle pulse)
   /\/\ /  \  /  \/\  ← 산등성이 (harmonic ridge)
  /    \/    \/      \ ← 주 곡선 (base sine)
─────────────────────── ← 기준선
```

### 성능 고려
- 기존 120 sample points 유지
- 추가 연산: sample당 sin() 1회 + triangle pulse 1회 → ~미미
- `animatableData`는 phase만 (기존과 동일)

---

## 2. 다층 Parallax 합성 (3 레이어)

### 레이어 구성

| 레이어 | 역할 | 색상 | 진폭 | 주파수 | 속도 | 불투명도 | ruggedness |
|--------|------|------|------|--------|------|----------|------------|
| Far | 먼 산/안개 | `forestMist` | 0.025 | 1.0 | 12s | 0.06 | 0.1 |
| Mid | 중간 숲 | `forestMid` | 0.045 | 1.8 | 8s | 0.10 | 0.4 |
| Near | 가까운 숲 | `forestDeep` | 0.07 | 2.5 | 5s | 0.14 | 0.7 |

### Parallax 깊이감
- **속도 차이**: 12s / 8s / 5s — 원경 느리고 근경 빠름
- **불규칙도 차이**: 0.1 → 0.7 — 멀리 매끄럽고 가까이 디테일
- **투명도 차이**: 0.06 → 0.14 — 멀리 흐리고 가까이 선명
- **나무 실루엣**: Near 레이어만 treeDensity=0.3 적용

### ForestWaveOverlayView (새 컴포넌트)

```swift
struct ForestWaveOverlayView: View {
    let preset: WavePreset
    let color: Color
    @State private var phaseFar: CGFloat = 0
    @State private var phaseMid: CGFloat = 0
    @State private var phaseNear: CGFloat = 0

    var body: some View {
        ZStack {
            // Far: 먼 산 안개
            ForestSilhouetteShape(amplitude: 0.025, frequency: 1.0,
                                   phase: phaseFar, ruggedness: 0.1, treeDensity: 0)
                .fill(forestMistColor.opacity(0.06))

            // Mid: 중간 숲
            ForestSilhouetteShape(amplitude: 0.045, frequency: 1.8,
                                   phase: phaseMid, ruggedness: 0.4, treeDensity: 0.1)
                .fill(forestMidColor.opacity(0.10))

            // Near: 가까운 숲 + 나무
            ForestSilhouetteShape(amplitude: 0.07, frequency: 2.5,
                                   phase: phaseNear, ruggedness: 0.7, treeDensity: 0.3)
                .fill(forestDeepColor.opacity(0.14))

            // Texture overlay: 우키요에 grain
            UkiyoeGrainOverlay(opacity: 0.04)
        }
        .clipped()
        .task { /* phase animation start */ }
    }
}
```

---

## 3. 우키요에 질감 시스템

### 3가지 질감 레이어

#### A. Grain Overlay (목판 결)
```swift
struct UkiyoeGrainOverlay: View {
    let opacity: CGFloat  // 0.03~0.06

    // 구현: pre-rendered noise texture (256x256) → tiled
    // 또는 Metal shader로 실시간 Perlin noise
    var body: some View {
        Image("ukiyoe-grain-tile")
            .resizable(resizingMode: .tile)
            .opacity(opacity)
            .blendMode(.multiply)
    }
}
```

- **성능**: 256x256 타일 이미지 = ~16KB, GPU 텍스처 타일링으로 무한 반복
- **대안**: `Canvas` + noise algorithm (번들 크기 0, 약간 CPU)

#### B. Bokashi (色ぼかし — 색번짐 그라데이션)
```swift
// 기존 gradient을 bokashi 스타일로 변형
// 핵심: 경계가 부드럽게 번지는 2-3 색상 그라데이션
// 구현: 비선형 gradient stops으로 색번짐 시뮬레이션

static let forestBokashi = LinearGradient(
    stops: [
        .init(color: forestDeep, location: 0.0),
        .init(color: forestDeep.opacity(0.7), location: 0.3),
        .init(color: forestMid.opacity(0.4), location: 0.5),
        .init(color: forestMist.opacity(0.15), location: 0.75),
        .init(color: .clear, location: 1.0)
    ],
    startPoint: .bottom,
    endPoint: .top
)
```

#### C. 불균일 엣지 (Washi Edge Effect)
```swift
// ForestSilhouetteShape의 엣지를 불균일하게
// 구현: path에 micro-noise 추가 (sample간 ±1~2pt 랜덤 오프셋)
// pre-computed array로 성능 유지

let edgeNoise: [CGFloat]  // 120 pre-computed random offsets (-2...2)
// path 생성 시: y += edgeNoise[i] * edgeRoughness
```

### 질감 적용 범위

| 영역 | Grain | Bokashi | 불균일 엣지 |
|------|-------|---------|------------|
| Tab 배경 | O (0.04) | O | O |
| Detail 배경 | O (0.03) | O (줄임) | O (줄임) |
| Sheet 배경 | O (0.02) | X | X |
| 카드 | X | O (미세) | X |
| Watch | X | O | X |

---

## 4. 색상 팔레트

### Core Colors (Asset Catalog)

| Token | 용도 | Light | Dark | 근거 |
|-------|------|-------|------|------|
| `ForestAccent` | 앱 틴트, 강조 | #D4A843 (금빛) | #E0B84D | 금빛 악센트 |
| `ForestBronze` | 히어로 텍스트 | #C73E1D (붉은 단풍) | #D44E2D | 붉은 악센트 |
| `ForestDusk` | 그라데이션 끝 | #5A3E28 (갈색 나무줄기) | #6B4E38 | 나무/흙 |
| `ForestSand` | 뮤트 보조 | #8FB996 (연한 초록) | #7BA888 | 안개 초록 |
| `ForestDeep` | 근경 숲 | #1A3A2A | #0F2E1F | 가장 진한 초록 |
| `ForestMid` | 중경 숲 | #2D5A3D | #234D32 | 중간 초록 |
| `ForestMist` | 원경 안개 | #A8CDB0 | #8FB996 | 연한 안개 |
| `ForestFoam` | 빛줄기/하이라이트 | #F0E6C8 (크림) | #D4CEB0 | 우키요에 종이색 |

### Tab Wave Colors

| 탭 | 색상 | 이유 |
|----|------|------|
| Today | ForestAccent (금빛) | 아침 숲 햇살 |
| Train | ForestBronze (붉은) | 단풍 에너지 |
| Wellness | ForestMid (초록) | 자연 회복 |
| Life | ForestMist (연초록) | 고요한 숲 |

### Score Colors

| Level | 색상 | 근거 |
|-------|------|------|
| Excellent | #4CAF50 (생동 초록) | 싱싱한 잎 |
| Good | #8BC34A (연두) | 새잎 |
| Fair | #D4A843 (금빛) | 가을 잎 |
| Tired | #E07B39 (주황) | 마른 잎 |
| Warning | #C73E1D (붉은) | 낙엽 |

### Metric Colors

| Metric | 색상 | 근거 |
|--------|------|------|
| HRV | #4CAF50 (생동 초록) | 심장 변이 = 자연의 다양성 |
| RHR | #2D5A3D (깊은 초록) | 안정 = 깊은 숲 |
| Heart Rate | #C73E1D (붉은) | 심장 = 붉은 단풍 |
| Sleep | #1A3A2A (야간 숲) | 밤 = 어두운 숲 |
| Activity | #D4A843 (금빛) | 활동 = 햇살 |
| Steps | #8FB996 (연한 초록) | 걸음 = 숲길 |
| Body | #6B4E38 (나무줄기) | 몸 = 나무 |

---

## 5. 애니메이션 특성

### 숲 특유의 움직임

| 요소 | 기존 테마 | Forest 테마 |
|------|----------|------------|
| 주 배경 | 수평 드리프트 | 수평 드리프트 (느리게, 바람에 의한 미세 흔들림) |
| 속도감 | Desert 6s / Ocean 5-10s | Forest 5-12s (원경 매우 느림) |
| 특수 효과 | Ocean: 큰파도 | Forest: (Future) 떨어지는 낙엽 파티클 |

### Tab별 파라미터 (WavePreset 확장)

```swift
// Forest preset parameters
extension WavePreset {
    var forestPrimary: ForestWaveParams {
        switch self {
        case .today:   return .init(amplitude: 0.04, frequency: 1.5, opacity: 0.12, ruggedness: 0.3)
        case .train:   return .init(amplitude: 0.06, frequency: 2.0, opacity: 0.15, ruggedness: 0.5)
        case .wellness: return .init(amplitude: 0.035, frequency: 1.3, opacity: 0.11, ruggedness: 0.2)
        case .life:    return .init(amplitude: 0.03, frequency: 1.2, opacity: 0.10, ruggedness: 0.15)
        }
    }
}
```

---

## 6. watchOS 적용

### Watch Forest Background

| 항목 | iOS | watchOS |
|------|-----|---------|
| 레이어 수 | 3 (Far/Mid/Near) | 2 (Far/Near) |
| Sample points | 120 | 60 |
| Grain overlay | O | X (화면 너무 작음) |
| Bokashi | O | O (간소화) |
| 애니메이션 | 5-12s | 8-15s (배터리 절약) |

### Watch 색상

기존 `OceanXxx` 패턴을 따라 `ForestXxx` 색상 세트를 watchOS Asset Catalog에도 추가.

---

## 7. 앱 아이콘 대안

### Forest 아이콘 컨셉

- 기존 아이콘의 실루엣/구도를 유지하되 색감을 Forest로 변경
- 배경: 깊은 초록 그라데이션 + 미세 grain 질감
- 악센트: 금빛 또는 붉은 단풍 하이라이트
- (Future) Settings에서 대안 아이콘 선택 가능

---

## 8. 구현 순서 (추천)

### Phase 1: Foundation
1. `AppTheme.forestGreen` case 추가
2. Asset Catalog에 Forest 색상 세트 추가 (iOS + watchOS)
3. `AppTheme+View.swift`에 Forest 색상 매핑 추가
4. ThemePickerSection "Coming Soon" 해제

### Phase 2: Background
5. `ForestSilhouetteShape` 구현 (120 samples, animatable phase)
6. `ForestWaveBackground.swift` — Tab/Detail/Sheet 3종
7. `UkiyoeGrainOverlay` — 타일 텍스처 또는 Canvas noise
8. Bokashi gradient 적용

### Phase 3: Integration
9. `ContentView`에서 Forest 테마 분기 추가
10. watchOS `WatchWaveBackground` Forest 분기
11. watchOS Asset Catalog 색상 추가

### Phase 4: Polish
12. 앱 아이콘 대안 생성
13. 테마 전환 애니메이션 검증
14. 다크 모드 색상 미세 조정
15. 접근성 (Reduce Motion) 검증

---

## 9. 기술적 고려사항

### 성능 예산

| 항목 | 목표 | 비고 |
|------|------|------|
| Shape 연산 | < 0.5ms/frame | pre-computed 120 samples |
| Grain 텍스처 | < 100KB | 256x256 tile, PNG |
| 메모리 증가 | < 5MB | 3 Shape + 1 texture |
| 배터리 영향 | 기존 테마 대비 +5% 이내 | grain은 정적 오버레이 |

### Grain 구현 대안 비교

| 방식 | 번들 크기 | CPU | GPU | 품질 |
|------|----------|-----|-----|------|
| 타일 이미지 | +16KB | 없음 | 텍스처 샘플링 | 고정 |
| Canvas + noise | 0 | 초기 생성 | 없음 | 가변 |
| Metal shader | 0 | 없음 | 실시간 | 최상 |

**추천**: 타일 이미지 (가장 단순, 성능 최적, 품질 충분)

### 불균일 엣지 seed

```swift
// deterministic random으로 앱 실행마다 동일한 패턴
let edgeNoise = (0..<120).map { i in
    sin(Double(i) * 7.3 + 2.1) * sin(Double(i) * 13.7 + 5.3)  // pseudo-random ±1
}
```

---

## 10. 기존 규칙 체크리스트

- [ ] xcassets 색상은 `Colors/` 하위 배치 (#119, #177)
- [ ] light/dark 동일이면 universal만 (#120, #137)
- [ ] 다크 모드 배경 gradient opacity >= 0.06 (#127, #128)
- [ ] `Shape.path(in:)` 내 문자열 파싱 금지 → init-time 수행 (#performance)
- [ ] Watch DTO 필드 추가 시 양쪽 target 동기화 (#69, #138)
- [ ] 정적 색상 배열은 `CaseIterable`에서 파생 (#178)
- [ ] `.clipped()` 필수 (#swiftui-patterns)

## Open Questions

1. **Grain 텍스처 에셋**: 직접 제작 vs AI 생성 vs 무료 소스?
2. **낙엽 파티클**: MVP에 포함할지 Future로 미룰지?
3. **앱 아이콘**: `setAlternateIconName` API 사용 or Settings 내 표시만?

## Next Steps

- [ ] `/plan forest-green-theme` 으로 구현 계획 생성
