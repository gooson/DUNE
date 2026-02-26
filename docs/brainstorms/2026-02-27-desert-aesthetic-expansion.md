---
tags: [design, desert-theme, visual-identity, DUNE, gradient, subtle]
date: 2026-02-27
category: brainstorm
status: draft
---

# Brainstorm: Desert Aesthetic Expansion

## Problem Statement

링 컬러의 **골드→블루 그라데이션**이 사막 느낌의 핵심이지만, 이 비주얼 언어가 앱 전반에 균일하게 퍼져 있지 않음.
현재 웨이브 배경과 warmGlow 토큰은 존재하지만, 차트/카드/텍스트/모션 영역은 아직 기본 iOS 느낌에 가까움.

### 링에서 추출한 사막 비주얼 DNA

```
색상 흐름: 올리브/카키(상단좌) → 앰버/골드(우측) → 페일 블루-그레이(하단)
배경:     다크 초콜릿 브라운 (사막 밤하늘)
숫자:     구리/브론즈 톤
전체 인상: 사막 황혼 (Desert Dusk) — 따뜻한 모래와 시원한 여명의 경계
```

## Target Users

일반 건강 앱 사용자 중 프리미엄 비주얼 경험을 기대하는 사람.
"또 다른 건강앱"이 아니라 DUNE이라는 세계관이 느껴지는 독자적 아이덴티티.

## Success Criteria

- 스크린샷만 봐도 "이 앱은 DUNE이다"라고 인식 가능
- 기존 iOS 패턴을 깨지 않으면서 은은한 사막 분위기
- 다크 모드에서 특히 효과적 (사막 밤 → 사막 낮 전환)

## 강도: Subtle

> 현재 iOS 기반 유지 + 포인트 요소만 사막 터치 추가.
> 모든 변경은 "기본 iOS에서 이건 뭐지?" 수준이 아니라
> "기본 iOS인데 뭔가 분위기가 다르다" 수준을 목표.

---

## 확장 가능한 요소 분석

### 1. 차트/그래프 영역

현재 차트는 metric별 단색 tintColor + 단순 opacity gradient만 사용.
사막 느낌이 가장 부족한 영역.

#### 1-1. Chart Area Gradient에 골드→블루 힌트

**현재**: `tintColor.opacity(0.3) → tintColor.opacity(0.05)` (단색 페이드)
**제안**: Area fill 하단에 아주 미세한 warmGlow 블렌딩 추가

```
AS-IS:  tintColor 0.3 ─────────→ tintColor 0.05
TO-BE:  tintColor 0.25 → warmGlow 0.04 → clear
```

변경 포인트: `AreaLineChartView.areaGradient` computed property
효과: 차트 아래쪽에 은은한 모래색 잔영 — 다크 모드에서 특히 효과적

#### 1-2. Chart Grid Line 워밍

**현재**: 시스템 기본 회색 `AxisGridLine()`
**제안**: 다크 모드에서 grid line에 warmGlow 아주 미세하게 적용

```swift
AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
    .foregroundStyle(warmGlow.opacity(0.06))  // 사막 모래알 느낌
```

효과: 차트 전체에 따뜻한 기운이 은은하게 깔림

#### 1-3. Chart Selection Indicator 사막화

**현재**: `RuleMark` + `.gray.opacity(0.3)` dashed line
**제안**: selection rule mark를 warmGlow 베이스로 변경

```
AS-IS:  .gray.opacity(0.3) dashed
TO-BE:  warmGlow.opacity(0.15) dashed + 선택 포인트에 warmGlow glow
```

효과: 차트 터치 시 사막 모래에서 빛이 반사되는 듯한 인터랙션

#### 1-4. BarChart에 Desert Horizon 그라데이션 옵션

Training Volume 등의 BarMark에 세로 방향 골드→블루 미세 그라데이션 적용 가능성.
다만 metric 구분이 중요하므로 **optional parameter**로.

---

### 2. 카드/컨테이너 스타일

현재 HeroCard는 warmGlow 보더가 잘 되어 있지만, StandardCard와 InlineCard는 상대적으로 밋밋함.

#### 2-1. StandardCard 보더에 골드→블루 그라데이션

**현재**: 다크 모드에서 `warmGlow.opacity(0.15)` 단색 보더
**제안**: 링처럼 topLeading=warmGlow, bottomTrailing=쿨블루 그라데이션

```swift
// AS-IS
.strokeBorder(warmGlow.opacity(0.15), lineWidth: 0.5)

// TO-BE
.strokeBorder(
    LinearGradient(
        colors: [warmGlow.opacity(0.12), DS.Color.desertDusk.opacity(0.08)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    ),
    lineWidth: 0.5
)
```

새 토큰 필요: `DS.Color.desertDusk` — 링 하단의 페일 블루-그레이

#### 2-2. InlineCard에 미세한 bottom border accent

**현재**: 보더/그림자 없는 `ultraThinMaterial`만
**제안**: 하단 1px에 warmGlow가 아주 미세하게 빛나는 효과

```swift
.overlay(alignment: .bottom) {
    Rectangle()
        .fill(warmGlow.opacity(0.06))
        .frame(height: 1)
        .padding(.horizontal, cornerRadius)
}
```

효과: 카드 리스트가 사막 모래 위에 놓인 듯한 미세한 구분

#### 2-3. SectionGroup 헤더 아이콘에 warmGlow tint

SectionGroup의 아이콘이 각 metric 색상을 따르는데,
섹션 타이틀 옆에 아주 작은 warmGlow dot/accent를 추가하면 통일감 증가.

---

### 3. 텍스트/타이포 분위기

가장 subtle하면서 효과적인 영역. 색상 미세 조정만으로 큰 분위기 변화.

#### 3-1. 숫자 레이블에 구리/브론즈 톤 (핵심)

**현재**: 점수, 수치가 시스템 `.primary` 또는 metric color 사용
**제안**: Hero 점수 숫자에 링의 "56"과 동일한 구리/브론즈 톤 적용

새 토큰: `DS.Color.desertBronze` — 구리색 (#B87A5E light / #D4A07A dark)
적용 범위: `HeroScoreCard`의 점수 숫자, `ConditionCalculationCard`의 최종값

효과: 앱 전체에서 "중요한 숫자 = 구리색"이라는 시각 문법 형성

#### 3-2. Secondary Text에 모래색 힌트

**현재**: `.secondary` (시스템 회색)
**제안**: 특정 컨텍스트(날짜, 단위)에서 warmGlow 기반의 muted sand 톤 사용

새 토큰: `DS.Color.sandMuted` — 음소거된 모래색 (#A69480 light / #8A7D6E dark)
적용 범위: 차트 축 레이블, 카드 내 부제목, "Updated N min ago" 류 타임스탬프

주의: 전체 `.secondary`를 교체하면 과하므로, 특정 장식적 텍스트에만 제한

#### 3-3. Section Title 옆 장식적 바

섹션 타이틀 왼쪽에 2px 너비의 warmGlow vertical bar 추가 (선택적)
또는 타이틀 아래에 매우 옅은 골드→투명 underline

---

### 4. 전환 애니메이션/모션

현재 wave drift는 잘 되어 있지만, 상태 전환에서 사막 느낌은 없음.

#### 4-1. Period 전환 시 Sand Shimmer

차트 기간 전환(7D → 30D) 시 crossfade에 warmGlow shimmer overlay 추가.
0.3초간 warmGlow.opacity(0.08)가 화면을 스쳐지나가는 효과.

```swift
.transition(.opacity.combined(with: .move(edge: .trailing)))
// + 0.3s warmGlow shimmer overlay during transition
```

#### 4-2. Score Ring Fill에 골드→블루 순차 채움

**현재**: AngularGradient로 단일 방향 채움
**제안**: 채움 진행 중 색상이 골드(시작) → 블루(끝)로 미세하게 변화
이미 `useWarmGradient`가 있으므로 gradient stops 조정으로 구현 가능

#### 4-3. Pull-to-Refresh 웨이브에 골드→블루 힌트

**현재**: `WaveRefreshIndicator`가 단색
**제안**: 웨이브 stroke에 미세한 골드→블루 gradient 적용

#### 4-4. Card 등장 애니메이션에 warmGlow flash

리스트 스크롤 시 새 카드가 뷰포트에 진입할 때
0.2초간 미세한 warmGlow border flash + fade out

---

### 5. 추가 환경적 요소 (Nice-to-have)

#### 5-1. 새 DS 컬러 토큰 세트: Desert Palette

```swift
enum DesertPalette {
    static let dusk     // 링 하단의 페일 블루-그레이 (#8E9BAB / #6B7A8E)
    static let bronze   // 링 숫자의 구리톤 (#B87A5E / #D4A07A)
    static let sand     // 음소거된 모래색 (#A69480 / #8A7D6E)
    static let horizon  // 골드→블루 전환점 (#C9A76C / #B8956A)
}
```

#### 5-2. Empty State에 사막 일러스트 힌트

`EmptyStateView`의 wave decoration을 골드→블루 듀얼 톤으로.
"데이터 없음" 상태가 사막의 고요함을 연상.

#### 5-3. Dark Mode 배경에 사막 밤하늘 그라데이션

`surfacePrimary` dark를 순수 검정(#0B0B0F)에서
아주 미세한 다크 브라운 힌트(#0F0D0B)로 시프트.
화면 전체에 사막 밤의 따뜻함이 깔림.

---

## Constraints

- **Subtle 강도**: 기본 iOS 패턴을 깨지 않아야 함
- **접근성**: contrast ratio 유지 (WCAG AA 4.5:1 이상)
- **성능**: 새 gradient/animation은 static 캐싱 필수 (Correction #80, #83, #105)
- **다크/라이트 모드 모두 동작**: 라이트에서는 더 미세하게, 다크에서 효과 극대화
- **기존 토큰 활용 우선**: 가능하면 새 토큰 최소화

## Scope

### MVP (Must-have)

**Phase 1: Desert Palette 토큰**
1. `DS.Color.desertDusk` 토큰 추가 — 링 하단 블루-그레이
2. `DS.Color.desertBronze` 토큰 추가 — 구리/브론즈 숫자
3. `DS.Color.sandMuted` 토큰 추가 — 음소거된 모래색
4. iOS + Watch DS 양쪽에 동일 토큰 동기 추가 (Correction #138)

**Phase 2: 차트 사막화**
5. Chart area gradient에 warmGlow 블렌딩 (1-1)
6. Chart grid line 워밍 — warmGlow 0.06 (1-2)
7. Chart selection indicator 사막화 — warmGlow 기반 rule mark (1-3)

**Phase 3: 카드 사막화**
8. StandardCard 보더를 골드→블루 그라데이션으로 (2-1)
9. InlineCard bottom accent — 하단 1px warmGlow (2-2)

**Phase 4: 텍스트 사막화**
10. Hero 점수 숫자에 desertBronze 적용 (3-1)
11. 장식적 텍스트(날짜, 단위, 타임스탬프)에 sandMuted 적용 (3-2)

**Phase 5: 모션 사막화**
12. Period 전환 시 Sand Shimmer overlay (4-1)

### Nice-to-have (Future)

- Pull-to-refresh 골드→블루 (4-3)
- Score Ring Fill 골드→블루 순차 채움 (4-2)
- Card 등장 시 warmGlow flash (4-4)
- Dark mode 배경 브라운 시프트 (5-3)
- Empty State 듀얼 톤 웨이브 (5-2)
- Section Title 장식 바 (3-3)

## Open Questions

1. `desertDusk` 블루-그레이의 정확한 hex — 링 레퍼런스에서 추출 필요
2. `desertBronze` 톤이 기존 `warmGlow`와 충분히 구분되는지 — 나란히 비교 필요
3. 라이트 모드에서 골드→블루 그라데이션이 자연스러운지 — 프로토타입 확인

## Next Steps

- [ ] `/plan` 으로 MVP 12개 항목의 구현 계획 생성 (5 Phase)
- [ ] 레퍼런스 이미지에서 정확한 hex 값 추출
- [ ] 프로토타입 빌드 후 다크/라이트 시각 검증
