---
tags: [design-system, color, desert-horizon, metric, chart, ring, full-overhaul, warm-palette]
date: 2026-02-28
category: brainstorm
status: draft
---

# Brainstorm: Desert Horizon 전면 디자인 리디자인

## Problem Statement

투데이 링의 Desert Horizon 느낌(DesertBronze→DesertDusk 그래디언트, warmGlow 레이어링)은 앱의 핵심 비주얼 아이덴티티지만, 이 언어가 **앱 전반에 균일하게 퍼져 있지 않음**.

### 현재 불일치 지점

| 영역 | 사막 느낌 수준 | 문제 |
|------|-------------|------|
| 투데이 링 | ★★★★★ | 기준점 — DesertBronze→DesertDusk gradient, warmGlow 레이어 |
| Hero/Glass 카드 | ★★★★☆ | warmGlow 보더 있지만 내부는 기본 material |
| 웨이브 배경 | ★★★☆☆ | warmGlow 톤이지만 탭별 개성이 사막과 무관 |
| Metric 카테고리 색상 | ★★☆☆☆ | HRV=골드만 사막 계열. Sleep=퍼플, Activity=초록은 완전 이질적 |
| 차트/그래프 | ★★☆☆☆ | metric 단색 + 기본 opacity fade. 사막 느낌 부재 |
| Score 5단계 | ★★☆☆☆ | Excellent=틸, Good=라임 — 표준 건강앱 색상, 사막과 무관 |
| Watch | ★☆☆☆☆ | DS 토큰 자체가 부분적. 하드코딩 30개 |

### 핵심 목표

> "스크린샷 한 장으로 DUNE이라는 것을 알 수 있는 수준의 비주얼 아이덴티티"
> 투데이 링 품질을 앱 전체 영역으로 확장

---

## Desert Horizon 비주얼 DNA

링에서 추출한 사막의 핵심 요소:

```
색상 흐름: 따뜻한 골드/앰버(상단) → 구리/브론즈(중간) → 시원한 블루-그레이(하단)
배경 톤:  다크 초콜릿 브라운 (사막 밤하늘)
숫자 톤:  구리/브론즈
전체 인상: 사막 황혼 (Desert Dusk) — 따뜻한 모래와 시원한 여명의 경계

자연 팔레트 영감:
  🏜️ 사막 모래    → 골드, 앰버, 샌드
  🌅 사막 석양    → 테라코타, 코랄, 크림슨
  🌿 오아시스     → 따뜻한 틸, 세이지 그린
  🌙 사막 밤하늘  → 인디고, 슬레이트, 딥 퍼플
  🪨 사막 바위    → 시에나, 올리브, 캐년 브라운
```

---

## 1. Metric 카테고리 색상 — 사막 팔레트 내 교체

### 현재 → 제안 매핑

| Metric | 현재 색상 | 현재 느낌 | 제안 색상 | 사막 테마 | 연상 |
|--------|----------|----------|----------|----------|------|
| **HRV** | `(0.745, 0.588, 0.353)` | 골드 ✓ | **Desert Gold** (유지/미세 조정) | 사막 모래 | 모래 위 아지랑이 |
| **RHR** | `(0.863, 0.467, 0.373)` | 코랄 레드 | **Terracotta** | 사막 흙벽 | 따뜻한 점토 |
| **HeartRate** | `(0.906, 0.298, 0.235)` | 순수 레드 | **Sunset Crimson** | 석양 붉은빛 | 지평선 위 석양 |
| **Sleep** | `(0.478, 0.400, 0.745)` | 퍼플 ❌ | **Twilight Indigo** | 사막 밤하늘 | 별이 뜨기 직전 |
| **Activity** | `(0.337, 0.718, 0.478)` | 순수 그린 ❌ | **Desert Sage** | 오아시스 풀 | 사막 속 생명 |
| **Steps** | `(0.275, 0.675, 0.686)` | 순수 틸 ❌ | **Oasis Teal** | 오아시스 물 | 사막 속 청량함 |
| **Body** | `(0.804, 0.584, 0.216)` | 앰버 ✓ | **Canyon Amber** (미세 조정) | 캐년 바위 | 오래된 사암 |
| **WellnessVitals** | `(0.565, 0.659, 0.439)` | 올리브 그린 | **Canyon Olive** | 사막 식물 | 다육식물 |
| **WellnessFitness** | `(0.420, 0.706, 0.337)` | 밝은 그린 ❌ | **Dune Sage** | 모래 위 풀 | 사막 허브 |

### 색상 설계 원칙

1. **Warm shift**: 모든 색상의 색온도를 따뜻하게 이동 (blue→teal, green→sage, purple→indigo)
2. **Muted saturation**: 채도를 10-20% 낮추어 사막의 건조한 공기감 표현
3. **Earthy undertone**: 순색 대신 흙/모래/바위의 undertone 추가
4. **구분성 유지**: 차트에서 인접 배치 시 hue 차이 20°+ 확보

### 제안 RGB 값 (Light / Dark)

```
Desert Gold (HRV)       Light: (0.76, 0.60, 0.36)  Dark: (0.84, 0.68, 0.44)
Terracotta (RHR)        Light: (0.80, 0.48, 0.36)  Dark: (0.88, 0.56, 0.44)
Sunset Crimson (HR)     Light: (0.84, 0.34, 0.28)  Dark: (0.92, 0.42, 0.36)
Twilight Indigo (Sleep) Light: (0.42, 0.38, 0.62)  Dark: (0.52, 0.48, 0.72)
Desert Sage (Activity)  Light: (0.45, 0.60, 0.42)  Dark: (0.53, 0.70, 0.50)
Oasis Teal (Steps)      Light: (0.32, 0.58, 0.58)  Dark: (0.40, 0.68, 0.66)
Canyon Amber (Body)     Light: (0.78, 0.58, 0.28)  Dark: (0.86, 0.66, 0.36)
Canyon Olive (Vitals)   Light: (0.52, 0.58, 0.38)  Dark: (0.60, 0.66, 0.46)
Dune Sage (Fitness)     Light: (0.46, 0.60, 0.36)  Dark: (0.54, 0.70, 0.44)
```

> 최종 값은 프로토타입 빌드 후 다크/라이트 시각 검증으로 미세 조정

---

## 2. Score 5단계 색상 — 사막 시간대 매핑

현재 Score 색상은 표준 건강앱(틸→그린→옐로우→오렌지→레드)과 동일하여 Desert Horizon 아이덴티티가 없음.

### 제안: 사막 하루의 시간대 → 컨디션 매핑

| Score | 현재 | 제안 | 사막 시간대 | 의미 |
|-------|------|------|-----------|------|
| **Excellent** | 틸 `(0, 0.8, 0.545)` | **Dawn Oasis** (따뜻한 틸) | 새벽 오아시스 | 가장 상쾌한 시간 |
| **Good** | 라임 `(0.22, 0.78, 0.42)` | **Morning Sage** (따뜻한 세이지) | 아침 사막 초목 | 활력 넘치는 아침 |
| **Fair** | 골드 `(0.918, 0.7, 0.059)` | **Midday Sand** (앰버 골드) | 한낮 모래 | 뜨거운 정오 |
| **Tired** | 오렌지 `(0.922, 0.5, 0.18)` | **Dusk Terracotta** (테라코타) | 석양 전 | 지쳐가는 오후 |
| **Warning** | 레드 `(0.894, 0.2, 0.31)` | **Night Ember** (따뜻한 크림슨) | 꺼져가는 모닥불 | 회복 필요 |

### 설계 원칙

- **의미적 직관성 유지**: 틸→그린→옐로우→오렌지→레드의 "신호등" 직관은 보존
- **Warm shift**: 각 단계에 사막 tonality 부여 (순색 → earthy tone)
- **Wellness Score와 통합**: 현재 Condition ≠ Wellness 불일치 해소. 단일 5단계 공유

---

## 3. 차트/그래프 팔레트 — Desert Horizon 적용

### 3-1. Area/Line Chart Gradient

```
현재: metricColor.opacity(0.3) → metricColor.opacity(0.05)
제안: metricColor.opacity(0.25) → warmGlow.opacity(0.04) → clear
```

효과: 차트 하단에 은은한 모래색 잔영. 모든 metric 차트가 같은 "사막 바닥"을 공유.

### 3-2. Chart Grid Line

```
현재: 시스템 기본 회색
제안: warmGlow.opacity(0.06) — 사막 모래알 느낌
```

### 3-3. Chart Selection Indicator

```
현재: .gray.opacity(0.3) dashed
제안: warmGlow.opacity(0.15) dashed + selection point에 warmGlow glow
```

### 3-4. Activity Category 11색

현재 Activity 차트 색상도 Desert Horizon 계열로 이미 전환됨 (2026-02-28 커밋).
Metric 색상 변경 시 Activity 색상과의 시각적 조화 재검증 필요.

### 3-5. Bar Chart (Training Volume 등)

BarMark에 세로 방향 미세 그라데이션: `metricColor → metricColor.opacity(0.7)` (하단 약간 밝게)
— 모래 위에 세운 기둥 느낌

---

## 4. 카드 & 컨테이너 스타일 통일

### 4-1. StandardCard 보더 — 골드→블루 그래디언트

```swift
// 현재 (다크 모드)
.strokeBorder(warmGlow.opacity(0.15), lineWidth: 0.5)

// 제안
.strokeBorder(
    LinearGradient(
        colors: [warmGlow.opacity(0.12), DS.Color.desertDusk.opacity(0.08)],
        startPoint: .topLeading, endPoint: .bottomTrailing
    ), lineWidth: 0.5
)
```

### 4-2. InlineCard — 하단 accent line

```swift
.overlay(alignment: .bottom) {
    LinearGradient(
        colors: [.clear, warmGlow.opacity(0.08), .clear],
        startPoint: .leading, endPoint: .trailing
    )
    .frame(height: 1)
}
```

### 4-3. Material 내부 Overlay — warm 힌트 통일

현재 HeroCard만 warmGlow overlay가 있고 StandardCard에는 없음.
StandardCard에도 아주 미세한 `warmGlow.opacity(0.03)` overlay 추가.

---

## 5. 텍스트 & 타이포 분위기

### 5-1. 핵심 수치에 DesertBronze 적용 범위 확대

현재: Hero 점수 숫자만 `DesertBronze→DesertDusk` gradient
제안: **모든 "중요한 숫자"에 동일 문법 적용**

적용 대상:
- Hero score, HeroScoreCard detail score
- VitalCard 메인 값 (HRV 55ms, RHR 62bpm 등)
- 차트 selection annotation 값
- Training Volume 요약 숫자

### 5-2. SandMuted 장식적 텍스트

적용 대상:
- 차트 축 레이블 (날짜, 수치 단위)
- "Updated N min ago" 타임스탬프
- 카드 내 부제목 / 단위 텍스트
- Section header의 보조 텍스트

### 5-3. Section Title 강조

섹션 타이틀 왼쪽에 2px warmGlow vertical bar:
```swift
HStack(spacing: DS.Spacing.xs) {
    RoundedRectangle(cornerRadius: 1)
        .fill(DS.Color.warmGlow.opacity(0.3))
        .frame(width: 2, height: 14)
    Text(title)
        .font(DS.Typography.sectionTitle)
}
```

---

## 6. DS 토큰 체계 정비

### 6-1. 새로운 Color 토큰 구조

```swift
enum DS.Color {
    // Brand (기존 유지)
    static let warmGlow      // AccentColor — 앱 전체 accent
    static let desertBronze  // 구리/브론즈 — 핵심 수치
    static let desertDusk    // 블루-그레이 — gradient 하단
    static let sandMuted     // 모래색 — 장식적 텍스트

    // Metric (사막 팔레트로 교체)
    static let hrv           // Desert Gold
    static let rhr           // Terracotta
    static let heartRate     // Sunset Crimson
    static let sleep         // Twilight Indigo
    static let activity      // Desert Sage
    static let steps         // Oasis Teal
    static let body          // Canyon Amber
    static let vitals        // Canyon Olive
    static let fitness       // Dune Sage

    // Score (사막 시간대)
    static let scoreExcellent // Dawn Oasis
    static let scoreGood      // Morning Sage
    static let scoreFair      // Midday Sand
    static let scoreTired     // Dusk Terracotta
    static let scoreWarning   // Night Ember

    // Feedback (현행 유지 — UX 시그널 직관성 우선)
    static let positive       // 그린 (변경 없음)
    static let negative       // 레드 (변경 없음)
    static let caution        // 앰버 (변경 없음)

    // Tab identity (기존 유지)
    static let tabTrain       // Desert Coral
    static let tabWellness    // Oasis Teal
}
```

### 6-2. 누락 토큰 추가

```swift
// Gradient 토큰
enum DS.Gradient {
    static let heroScoreText    // DesertBronze → DesertDusk
    static let cardBorder       // warmGlow → desertDusk (topLeading → bottomTrailing)
    static let chartAreaFade    // metricColor → warmGlow.hint → clear
    static let warmOverlay      // warmGlow.medium → warmGlow.subtle
}

// Opacity 토큰 (기존 5개에 추가)
enum DS.Opacity {
    static let chartGrid: 0.06   // 차트 그리드 라인
    static let cardOverlay: 0.03 // StandardCard warm overlay
    static let hintBlend: 0.04   // 차트 area warm blend
}
```

### 6-3. Watch DS 동기화

iOS DS 변경 시 `DUNEWatch/DesignSystem.swift`에 동일 토큰 반영 필수.
현재 Watch DS는 iOS의 부분 집합 — metric 색상, score 색상은 Watch에서도 사용되므로 반드시 동기.

---

## 7. Watch 디자인 시스템 적용

### 현재 상태

- 30개 하드코딩 컬러 (`.green`, `.gray`, `.red`, `.yellow`)
- DS 토큰 부분적 사용
- 사막 느낌 거의 없음

### 제안

1. Watch DS에 metric/score 토큰 추가
2. 30개 하드코딩 → DS 토큰 교체
3. Watch 카드/배경에 미세한 warmGlow 힌트
4. Watch 링에도 동일 Desert Horizon gradient 적용

---

## 8. 모션 & 전환 사막화

### 8-1. Period 전환 Sand Shimmer

차트 기간 전환(7D→30D) 시 0.3초간 warmGlow.opacity(0.06) shimmer overlay

### 8-2. Card 등장 시 warm flash

카드가 뷰포트에 진입할 때 0.2초 warmGlow border flash + fade

### 8-3. Pull-to-Refresh 웨이브 골드→블루 힌트

`WaveRefreshIndicator` stroke에 warmGlow→desertDusk gradient 적용

---

## 9. 수행 순서 (전체 일괄)

전체 일괄 작업이지만, 빌드 가능 상태 유지를 위해 논리적 순서를 따름:

### Phase 1: DS 토큰 기반 정비

1. xcassets에 새/변경 colorset 생성 (Metric 9개 + Score 5개 + Feedback 3개)
2. `DesignSystem.swift` 토큰 업데이트 (iOS)
3. `DUNEWatch/DesignSystem.swift` 동기 업데이트
4. DS.Gradient, DS.Opacity 새 토큰 추가

### Phase 2: 색상 전환

5. xcassets Metric 9개 colorset RGB 값 교체
6. Score 5개 colorset RGB 값 교체 + Wellness 전용 4개 삭제 (통합)
7. HR Zone 5개 colorset 사막 팔레트로 교체
8. `WellnessScore+View.swift` → `score*` 토큰으로 통일

### Phase 3: 차트 사막화

9. Area chart gradient에 warmGlow blend 추가
10. Grid line warmGlow 톤 적용
11. Selection indicator 사막화
12. Bar chart 미세 그라데이션

### Phase 4: 카드 & 텍스트 사막화

13. StandardCard 보더 골드→블루 gradient
14. InlineCard 하단 accent
15. 핵심 수치에 DesertBronze gradient 확대
16. SandMuted 장식 텍스트 적용
17. Section title accent bar

### Phase 5: Watch 적용

18. Watch DS 토큰 동기화
19. 하드코딩 30개 → DS 토큰 교체
20. Watch 카드 warmGlow 힌트

### Phase 6: 모션 & 환경 요소

21. Period 전환 Sand Shimmer 애니메이션
22. Card 등장 warm flash
23. Pull-to-refresh 웨이브 사막화
24. Dark mode 배경 미세 brown shift
25. Empty state 사막 일러스트 힌트
26. Section title accent bar

### Phase 7: 접근성 & 검증

27. 색맹 시뮬레이션 테스트 (red-green deficiency)
28. WCAG AAA (7:1) contrast 달성
29. 전체 빌드 검증 (iOS + Watch)
30. 다크/라이트 모드 시각 검증

---

## Constraints

- **접근성**: WCAG AA contrast ratio 4.5:1 유지. 특히 dark mode에서 muted 색상 주의
- **성능**: 새 gradient은 static let 캐싱 필수 (Correction #80, #83, #105, #165)
- **차트 가독성**: Metric 색상 변경 후 인접 배치 시 hue 20°+ 차이 확인
- **CloudKit 영향 없음**: 색상은 프레젠테이션 레이어만 변경, 데이터 모델 무관
- **Correction #129**: v1(보수적) → v2(강화) 2단계 가능하나, 사용자가 전체 일괄 요청하므로 한 번에 완성도 높게
- **Correction #138**: Watch DS ↔ iOS DS 동기 필수

## Edge Cases

- **기존 스크린샷/문서**: Score 색상 변경 시 docs/ 내 참조 이미지 업데이트 필요
- **Activity 11색과 Metric 9색 충돌**: 동일 차트에 배치될 가능성 낮지만, 전체 팔레트 hue map 검증
- **색맹 사용자**: 사막 팔레트가 red-green deficiency에서 구분 가능한지 시뮬레이션 필요
- **Light mode에서 muted 색상 가시성**: 밝은 배경에서 채도 낮은 색상이 흐려보일 수 있음
- **Watch 작은 화면**: metric 색상이 작은 화면에서도 충분히 구분되는지 확인

## Scope

### MVP (Must-have — 이번 작업)

- [ ] Metric 9개 색상 사막 팔레트 교체
- [ ] Score 5단계 색상 사막 시간대 매핑
- [ ] Wellness Score 전용 4색 삭제 → Condition Score 5색으로 통합
- [ ] HR Zone 5색 사막 팔레트 교체
- [ ] DS 토큰 정비 (Gradient, Opacity 추가)
- [ ] 차트 area/grid/selection 사막화
- [ ] 카드 보더 골드→블루 gradient 통일
- [ ] 핵심 수치 DesertBronze gradient 확대
- [ ] SandMuted 장식 텍스트 적용
- [ ] Watch DS 동기화 + 하드코딩 교체
- [ ] 전체 빌드 검증

- [ ] Sand Shimmer 전환 애니메이션
- [ ] Card 등장 warm flash
- [ ] Pull-to-refresh 사막화
- [ ] Dark mode 배경 미세 brown shift
- [ ] Empty state 사막 일러스트
- [ ] Section title accent bar
- [ ] 색맹 시뮬레이션 테스트
- [ ] WCAG AAA (7:1) contrast 달성

### Nice-to-have (Future)

- [ ] Watch/iOS DS 공유 SPM 패키지 통합

## 결정 사항

### Q1. Score 색상 통합 → **완전 통합**

Condition Score와 Wellness Score를 **동일 5색** 공유.
- 현재 `scoreTired`는 이미 양쪽에서 공유 → 분리가 의도적이지 않았음
- Wellness 전용 4개 colorset(`WellnessScoreExcellent/Good/Fair/Warning`) 삭제
- `WellnessScore+View.swift`의 color switch를 `scoreExcellent/Good/Fair/Warning`으로 통일
- 사막 팔레트 전환 시 5색만 관리 (9색 → 5색)

### Q2. HR Zone 5색 → **사막 팔레트로 통합**

HRZone1~5도 Desert Horizon 계열로 전환.
사막 하루의 활동 강도와 매핑:
- Zone1 (편안): Dawn Blue (새벽 서늘함)
- Zone2 (지방 연소): Morning Sand (아침 모래)
- Zone3 (유산소): Midday Gold (한낮 열기)
- Zone4 (고강도): Sunset Ember (석양 붉음)
- Zone5 (최대): Desert Fire (사막 열파)

### Q3. Feedback 색상 → **현행 유지**

`DS.Color.positive/negative/caution`은 40곳+ UX 시그널 용도로 사용 중.
CTA 버튼, 삭제 확인, 증감 화살표 등 **즉각적 직관성**이 최우선.
warm shift하면 "초록=긍정, 빨강=위험" 보편 직관이 약해지므로 **변경하지 않음**.

## Open Questions

1. **Light mode 채도**: muted 사막 톤이 light mode에서 충분히 선명한지 — 프로토타입 후 판단

## Next Steps

- [ ] `/plan` 으로 Phase 1~6 상세 구현 계획 생성
- [ ] Phase 1 색상값 확정 후 프로토타입 빌드
- [ ] 다크/라이트 스크린샷 비교 검증
- [ ] Watch 시뮬레이터 시각 검증
