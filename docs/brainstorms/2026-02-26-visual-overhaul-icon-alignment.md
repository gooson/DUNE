---
tags: [design, ux, visual, dark-mode, color-palette, icon-alignment]
date: 2026-02-26
category: brainstorm
status: draft
---

# Brainstorm: App Icon 기반 전체 비주얼 오버홀

## Problem Statement

앱 아이콘은 **다크 배경 + 오렌지-골드 그라디언트 파동선**의 프리미엄 디자인이지만, 앱 내부는 **보라/초록 중심의 차가운 톤**으로 구성되어 있어 시각적 일관성이 부족하다. 사용자가 아이콘을 보고 기대하는 프리미엄 다크 경험과 실제 앱 경험 사이에 괴리가 있다.

## Target Users

- Apple Watch + iPhone을 사용하는 건강 관리에 관심 있는 사용자
- 프리미엄 디자인을 선호하는 사용자
- 주로 아침/저녁에 건강 데이터를 확인하는 사용자 (다크 환경에서의 사용 빈도 높음)

## Success Criteria

1. 앱 아이콘 → 앱 내부 전환 시 **시각적 연속성** 확보
2. 세 탭(Today, Activity, Wellness) 간 **일관된 톤** 유지
3. 다크 모드에서 프리미엄하면서도 **가독성 유지**
4. 아이콘의 "파동선(wave)" 모티프가 앱 내부에서 **자연스럽게 등장**
5. 라이트 모드에서도 조화로운 대응

---

## 현재 상태 분석

### App Icon 디자인 언어
- 배경: 거의 순검정 (#0D0D0D)
- 핵심 모티프: 오렌지→골드 그라디언트의 유려한 파동선 (HRV 웨이브폼 연상)
- AccentColor: rgb(201, 149, 107) — 따뜻한 앰버/골드

### 현재 색상 팔레트 (Dark mode 값)

| Token | 현재 Dark | 용도 | 아이콘 톤 조화 |
|-------|-----------|------|---------------|
| AccentColor | (201, 149, 107) | 앱 틴트 | **일치** (골드/앰버) |
| SurfacePrimary | (11, 11, 20) | 앱 배경 | **일치** (거의 검정, 약간 블루) |
| CardBackground | (28, 28, 40) | 카드 배경 | 괜찮음 (블루-블랙) |
| MetricHRV | (129, 140, 248) | HRV 색상 | **불일치** (차가운 보라) |
| MetricRHR | (251, 113, 133) | RHR 색상 | 중간 (핑크-레드) |
| MetricHeartRate | (244, 102, 88) | HR 색상 | 중간 (따뜻한 레드) |
| MetricSleep | (167, 139, 250) | 수면 색상 | **불일치** (차가운 보라) |
| MetricActivity | (52, 211, 153) | 활동 색상 | **불일치** (차가운 초록) |
| MetricSteps | (34, 211, 238) | 걸음 색상 | **불일치** (차가운 시안) |
| MetricBody | (251, 191, 36) | 체중 색상 | **일치** (골드/옐로) |
| WellnessVitals | (0, 217, 208) | 바이탈 색상 | **불일치** (차가운 틸) |
| WellnessFitness | (64, 213, 102) | 피트니스 색상 | **불일치** (차가운 초록) |
| LaunchBackground | (13, 13, 13) | 런치 배경 | **일치** |

### 현재 UI 구조

**배경 처리 (3탭 공통 패턴)**
```swift
.background {
    LinearGradient(
        colors: [DS.Color.xxx.opacity(0.03), .clear],
        startPoint: .top, endPoint: .center
    ).ignoresSafeArea()
}
```
→ 0.03 opacity = 사실상 투명. 탭 간 시각적 구분 불가.

**카드 시스템**
- `HeroCard`: `.ultraThinMaterial` + tintColor 0.08 gradient overlay
- `StandardCard`: `.thinMaterial` + shadow
- `InlineCard`: `.ultraThinMaterial`
- `SectionGroup`: `.thinMaterial`

**히어로 카드 (탭별)**
- Today: `ConditionHeroView` — 점수 상태별 색상 (Excellent=초록, Fair=주황 등)
- Activity: `HeroScoreCard` — Readiness 점수 + HRV/Sleep/Recovery 서브바
- Wellness: `HeroScoreCard` — Wellness 점수 + Sleep/Condition/Body 서브바

---

## 제안 방향

### 1. 색상 팔레트 워밍(Warming) 전략

**핵심 원칙**: 차가운 보라/초록/시안 → 따뜻한 앰버/코랄/골드 축으로 이동

| Token | 현재 Dark | 제안 Dark | 변화 설명 |
|-------|-----------|-----------|-----------|
| MetricHRV | 보라(129,140,248) | 앰버(200,160,100) 또는 아이콘 골드 계열 | HRV = 앱의 핵심 지표. 아이콘 파동선과 동일 톤 |
| MetricSleep | 보라(167,139,250) | 라벤더-로즈(180,140,200) 또는 인디고 유지 | 수면의 "밤" 연상. 보라 유지도 가능하되 채도 조절 |
| MetricActivity | 초록(52,211,153) | 따뜻한 틸(100,200,160) 또는 민트-골드 | 에너지 느낌은 유지하되 톤을 워밍 |
| MetricSteps | 시안(34,211,238) | 따뜻한 블루(100,180,220) | 시안→스카이블루로 워밍 |
| WellnessVitals | 틸(0,217,208) | 소프트 골드(200,180,120) | 바이탈 = 심장 관련 → 골드/앰버 |
| WellnessFitness | 초록(64,213,102) | 따뜻한 초록(140,200,100) | 채도 낮추고 옐로-그린 방향 |

**유지할 색상**:
- AccentColor (이미 일치)
- MetricBody (이미 골드)
- MetricHeartRate (따뜻한 레드, 적합)
- Score 등급 색상 (Excellent=초록, Fair=주황 등 — 의미 기반이므로 유지)
- LaunchBackground, SurfacePrimary (이미 다크 톤)

### 2. 배경 그라디언트 강화

**현재**: 0.03 opacity → 사실상 투명
**제안**: 탭별 미묘한 warm gradient로 분위기 전환

```
Today: 아이콘 골드 warm glow (top) → transparent (center)
Activity: 따뜻한 에메랄드 glow → transparent
Wellness: 소프트 인디고-앰버 glow → transparent
```

- Opacity: 0.03 → **0.06~0.10** (다크 모드에서 인지 가능한 수준)
- Gradient 범위: top→center → **top→bottom 40%** 확장
- 추가로 **미세한 radial gradient** (스크린 상단 중앙에서 방사형)도 고려

### 3. 아이콘 "파동(Wave)" 모티프 적용

아이콘의 핵심 아이덴티티인 파동선을 앱 내부에서 활용:

**적용 위치**:
- [ ] **탭 전환 시 상단 배경**: 미세한 wave path를 배경 그라디언트 마스크로 활용
- [ ] **히어로 카드 배경**: HeroCard 하단에 미세한 wave line overlay
- [ ] **Section divider**: 직선 대신 subtle wave path로 섹션 구분
- [ ] **Empty state**: 데이터 없을 때 파동선 애니메이션
- [ ] **Loading state**: 파동 애니메이션 (맥박 느낌)
- [ ] **Pull-to-refresh indicator**: wave 형태의 커스텀 indicator
- [ ] **ScrollView 상단 overscroll 영역**: wave 패턴 reveal

**주의**: 과용 금지. 2-3곳에만 은은하게 적용. 프리미엄 앱은 절제가 핵심.

### 4. 카드 스타일 업그레이드

**현재**: `.thinMaterial` 기반 glass morphism — 깔끔하지만 평범

**제안 (다크 모드 우선)**:
- Material 유지하되, **미세한 골드 border** 추가 (opacity 0.08~0.12)
- HeroCard에 **앰버 글로우** 효과 강화 (현재 0.08 → 0.12~0.15)
- StandardCard shadow: 현재 white 0.03 → **앰버 0.05** (다크 모드에서 따뜻한 광택)
- 카드 border에 **1px gradient stroke** (골드→투명) — 옵션

```swift
// 예시: warm glass card
RoundedRectangle(cornerRadius: DS.Radius.md)
    .fill(.thinMaterial)
    .overlay(
        RoundedRectangle(cornerRadius: DS.Radius.md)
            .strokeBorder(
                LinearGradient(
                    colors: [Color.accentColor.opacity(0.12), .clear],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 0.5
            )
    )
```

### 5. 히어로 카드 비주얼 업그레이드

세 탭의 히어로를 통합된 프리미엄 느낌으로:

- **Progress Ring**: 현재 `AngularGradient` → **앰버-골드 기반 그라디언트**로 통일 (점수 상태 색상은 accent로 유지)
- **Hero 배경**: 현재 단색 tint → **골드 → 상태색 gradient** overlay
- **타이포그래피**: `.rounded` 디자인 유지 (이미 좋음), 점수 숫자에 **미세한 골드 그라디언트** 적용 가능
- **서브스코어 바**: 현재 capsule fill → 약간의 글로우 추가

### 6. 다크/라이트 모드 전략

**다크 모드 (Primary)**:
- 아이콘과 완전 일치
- 배경: 거의 검정 (현재 SurfacePrimary 유지)
- 카드: 다크 material + 골드 hint
- 텍스트: 화이트 + 골드 accent

**라이트 모드 (Secondary)**:
- 배경: 크림/웜 화이트 (현재 연보라 → 웜 톤으로 변경)
- 카드: 화이트 + 섀도 (현재와 유사)
- 색상은 dark의 desaturated 버전
- AccentColor, 골드 hint는 동일하게 유지

---

## 영향 범위

### 색상 변경 시 수정 파일

| 영역 | 파일/위치 | 변경 내용 |
|------|-----------|-----------|
| Color assets | `Assets.xcassets/Colors/*.colorset` | 색상값 조정 (10~15개 colorset) |
| DesignSystem | `DesignSystem.swift` | 토큰 추가 (wave color, glow color 등) |
| SurfacePrimary | `SurfacePrimary.colorset` | 라이트 모드: 연보라→웜 화이트 |
| CardBackground | `CardBackground.colorset` | 라이트 모드: 순백→웜 크림 |

### UI 컴포넌트 변경

| 컴포넌트 | 파일 | 변경 내용 |
|----------|------|-----------|
| HeroCard | `GlassCard.swift` | tint overlay 강화, warm border 추가 |
| StandardCard | `GlassCard.swift` | shadow 워밍, border hint 추가 |
| SectionGroup | `SectionGroup.swift` | material 유지, 옵션으로 warm tint |
| ProgressRing | `ProgressRingView.swift` | gradient 조정 |
| 3탭 배경 | `DashboardView.swift`, `ActivityView.swift`, `WellnessView.swift` | gradient 강화 |

### 새로 추가할 컴포넌트

| 컴포넌트 | 위치 | 용도 |
|----------|------|------|
| WaveBackground | `Shared/Components/` | 파동 모티프 배경 Shape |
| WaveLoadingView | `Shared/Components/` | wave 기반 로딩 인디케이터 |

---

## Constraints

### 기술적 제약
- Named color(`Color("MetricHRV")`) 기반이므로 colorset 값 변경만으로 전체 반영 가능
- Material 기반 카드는 시스템 지원이므로 안정적
- Custom wave Shape는 `Path` 기반으로 성능 이슈 없음 (Correction #82 준수)
- 색상 변경은 기존 차트(Swift Charts)의 가독성에 영향 → 검증 필요

### 리스크
- 색상 팔레트 전면 변경 → **기존 차트/그래프 가독성 저하 가능**
- 따뜻한 톤으로 통일 시 **메트릭 간 구분력 감소 가능** (모든 게 골드면 구분 안됨)
- 라이트 모드 대응이 불충분하면 밝은 환경 사용자 이탈
- Wave 모티프 과용 시 게임/엔터 앱 느낌 → 절제 필수

### 시간/리소스
- Color asset 변경: 비교적 작은 작업 (1~2시간)
- 카드 스타일 조정: 중간 (3~4시간)
- 히어로 리디자인: 큰 작업 (6~8시간)
- Wave 모티프 구현: 중간 (3~4시간)
- 전체 QA/미세조정: 큰 작업 (4~6시간)

---

## Edge Cases

- **색맹/색약 사용자**: 골드 톤 통일 시 메트릭 구분이 색상만으로는 불가. 아이콘+라벨 병행 필수 (현재 이미 대응됨)
- **OLED 번인**: 순검정 배경에 고정 UI 요소 → 번인 위험 낮음 (스크롤 기반)
- **다이나믹 타입**: 현재 DS.Typography가 Dynamic Type 대응 → 유지
- **iPad 가로모드**: HStack 레이아웃에서 wave 배경이 어색할 수 있음
- **watchOS**: 별도 디자인 시스템 (현재 독립), 색상 토큰만 공유

---

## Scope

### MVP (Must-have)
- [ ] 색상 팔레트 워밍 (colorset 값 조정)
- [ ] SurfacePrimary 라이트 모드: 연보라 → 웜 크림
- [ ] 3탭 배경 그라디언트 강화 (opacity + 범위)
- [ ] HeroCard/StandardCard warm border hint
- [ ] 다크 모드 전체 스크린샷 검증

### Nice-to-have (Future)
- [ ] Wave 모티프 배경 Shape
- [ ] Wave 로딩 애니메이터
- [ ] 히어로 카드 골드 그라디언트 점수
- [ ] Pull-to-refresh 커스텀 wave indicator
- [ ] 디자인 시스템 SKILL.md 완전 정의
- [ ] watchOS 색상 톤 동기화

---

## Open Questions

1. **메트릭 색상 구분 전략**: 모든 메트릭을 warm 톤으로 바꾸면 HRV/Sleep/Steps 시각 구분이 어려워짐. "warm but distinct" 팔레트를 어떻게 구성할지?
   - 옵션 A: 골드/앰버/코랄/테라코타/머스타드 같은 warm 스펙트럼 내 분산
   - 옵션 B: 핵심 지표(HRV, HR)만 warm, 나머지는 현행 유지
   - 옵션 C: warm neutral 기반 + 각 메트릭에 고유 hue accent
2. **Score 등급 색상은 변경할지?**: Excellent=초록, Fair=주황은 범용적 의미가 있어 유지가 안전. 다만 초록이 앱 톤과 어울리는지?
3. **Wave 모티프의 적정 수준**: 어디에 몇 개까지?
4. **기존 스크린샷/마케팅 소재 영향**: 전면 변경 시 App Store 에셋 전량 교체 필요

## Next Steps

- [ ] `/plan` 으로 MVP 범위의 구현 계획 생성
- [ ] 색상 팔레트 시안 제작 (Figma 또는 코드 내 preview)
- [ ] 다크 모드 before/after 스크린샷 비교
