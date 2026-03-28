---
tags: [animation, motion-design, ux, all-tabs, rich-animation]
date: 2026-03-28
category: brainstorm
status: draft
---

# Brainstorm: Rich Animation Enhancement (All Tabs)

## Problem Statement

현재 앱의 애니메이션은 기본적인 수준에 머물러 있음:
- 카드/섹션이 데이터 로드 후 갑자기 나타남 (stagger가 Dashboard 일부에만 적용)
- 점수/숫자 변화 연출이 단조로움 (카운터는 있으나 시각적 임팩트 부족)
- 화면 전환이 iOS 기본 push/pop에 의존
- 인터랙션 피드백이 거의 없음

Streaks/Gentler Streak 수준의 Rich 모션 디자인으로 앱 전체를 업그레이드하여, 앱 자체가 시각적 경험이 되는 프리미엄 느낌을 목표로 함.

## Target Users

- 매일 앱을 사용하는 피트니스 사용자
- 건강 데이터 변화를 시각적으로 체감하고 싶은 사용자
- 프리미엄 앱 경험을 기대하는 사용자

## Success Criteria

1. 모든 탭의 모든 화면에서 데이터 등장 시 stagger + spring 애니메이션 적용
2. 점수/숫자 변화에 glow, scale pulse, celebration 효과 포함
3. 카드 → 상세 전환에 커스텀 transition (zoom morph 등) 적용
4. 버튼/카드 press 시 시각적 + 햅틱 피드백 일관 적용
5. `reduceMotion` 접근성 100% 대응
6. 애니메이션 추가 후 스크롤 성능 저하 없음 (60fps 유지)

## Proposed Approach

### Phase 1: 공통 애니메이션 인프라

#### 1-A. DS.Animation 확장

```swift
enum DS.Animation {
    // 기존 유지
    static let snappy      = Spring(duration: 0.25, bounce: 0.05)
    static let standard    = Spring(duration: 0.35, bounce: 0.1)
    static let emphasize   = Spring(duration: 0.6, bounce: 0.15)
    static let slow        = Spring(duration: 1.0, bounce: 0.1)

    // 신규 Rich 프리셋
    static let cardEntrance  = Spring(duration: 0.5, bounce: 0.15)   // 카드 등장
    static let heroMorph     = Spring(duration: 0.55, bounce: 0.12)  // hero 전환
    static let scoreDrama    = Spring(duration: 1.2, bounce: 0.08)   // 점수 드라마틱
    static let celebration   = Spring(duration: 0.8, bounce: 0.2)    // 달성 축하
    static let pressDown     = Spring(duration: 0.2, bounce: 0.0)    // 버튼 눌림
    static let pressUp       = Spring(duration: 0.4, bounce: 0.15)   // 버튼 복귀

    // Stagger 함수
    static func stagger(index: Int, base: Double = 0.08, max: Int = 8) -> Double {
        Double(min(index, max)) * base
    }
}
```

#### 1-B. 공통 ViewModifier

| Modifier | 효과 | 적용 대상 |
|----------|------|----------|
| `.staggeredAppear(index:)` | slide-up(16pt) + fade + scale(0.95) | 모든 카드/섹션 |
| `.pressable()` | press시 scale(0.96) + shadow 변화 + haptic | 탭 가능한 카드 |
| `.scoreCounter(value:)` | 드라마틱 카운터 + glow pulse | 점수 표시 |
| `.celebrationEffect(trigger:)` | particle burst + scale bounce | 기록 달성 |
| `.shimmerOnLoad(isLoading:)` | skeleton shimmer → 컨텐츠 전환 | 데이터 로딩 |

#### 1-C. 커스텀 Transition

| Transition | 효과 | 사용처 |
|-----------|------|--------|
| `.zoomMorph` | scale + opacity + corner radius 동시 변환 | 카드→상세 |
| `.slideUpFade` | slide-up(16pt) + opacity | 섹션 등장 |
| `.blurDismiss` | blur + scale down + opacity | sheet dismiss |

### Phase 2: 탭별 적용

#### Today (Dashboard)

| 요소 | 현재 | 목표 |
|------|------|------|
| Condition Hero Card | 기본 등장 | scale(0.9)→1.0 + fade + ring fill 순차 |
| Score Counter | easeOut 0.6s | 1.2s dramatic + glow pulse at end |
| Insight Cards | stagger 50ms | stagger 80ms + slide-up + scale |
| Weather Card | 즉시 표시 | atmosphere fade-in 1.5s (기존) + 아이콘 bounce |
| Coaching Card | 즉시 표시 | typewriter-style text reveal |
| Period 전환 | opacity | parallax slide + fade cross-dissolve |
| Briefing Entry | 즉시 | slide-up + pulse glow on new |
| Template Nudge | 즉시 | gentle bounce-in |

#### Train (Activity)

| 요소 | 현재 | 목표 |
|------|------|------|
| Training Readiness Hero | 기본 등장 | ring fill + score counter drama |
| Weekly Stats Grid | 즉시 | stagger per cell (L→R, T→B) |
| Volume Chart Bars | 즉시 | bottom-up grow + stagger per bar |
| Muscle Recovery Map | 즉시 | 색상 fade-in 영역별 순차 |
| Fatigue Legend | 즉시 | fade-in cascade |
| Suggested Workout | 즉시 | slide-in from right + badge pulse |
| PR Section | 즉시 | stagger + 새 기록시 celebration |
| RPE Trend Chart | 즉시 | line draw animation |

#### Wellness

| 요소 | 현재 | 목표 |
|------|------|------|
| Wellness Hero Card | 기본 등장 | ring fill + body score cascade |
| Vital Cards | 즉시 | stagger + sparkline draw animation |
| Sleep Charts | 즉시 | stage bars grow bottom-up |
| Sleep Prediction | 즉시 | gauge fill animation |
| Nocturnal Vitals | 즉시 | line draw + area fade-in |
| Sleep Deficit Gauge | 기본 | arc fill + 색상 transition |
| Body Composition | 즉시 | trend line draw |

#### Life

| 요소 | 현재 | 목표 |
|------|------|------|
| Habit Rows | 즉시 | stagger slide-up |
| Completion Chart | 즉시 | bar grow + stagger |
| Heatmap Cells | 즉시 | cascade fill (oldest→newest) |
| Check/Uncheck | 즉시 | scale bounce + haptic |
| Weekly Report | 즉시 | stagger sections |

#### Exercise Session

| 요소 | 현재 | 목표 |
|------|------|------|
| Set Row 추가 | 즉시 | slide-down + fade |
| Set 완료 체크 | 즉시 | checkmark draw + row highlight flash |
| Rest Timer | move+opacity | circular countdown + haptic at intervals |
| Exercise Transition | move+opacity | crossfade + slide |
| Workout Complete | 기본 sheet | celebration particles + stats cascade |
| RPE Picker | 즉시 | scale-in segments |

#### Detail Views (공통)

| 요소 | 현재 | 목표 |
|------|------|------|
| Hero Score | 기본 | ring fill + counter drama |
| Chart 영역 | 즉시 | line draw / bar grow animation |
| Summary Stats | 즉시 | stagger fade-up |
| Period Selector | opacity | underline slide + content cross-fade |

### Phase 3: 인터랙션 피드백

| 인터랙션 | 시각 효과 | 햅틱 |
|----------|----------|------|
| 카드 탭 | scale(0.96) + shadow reduce | `.light` |
| 버튼 탭 | scale(0.94) + brightness shift | `.medium` |
| 스와이프 삭제 | bounce 제거 후 fade | `.warning` (첫 스와이프) |
| 점수 달성 | particle burst + ring glow | `.success` pattern |
| Period 변경 | content slide + haptic tick | `.selection` |
| Pull to refresh | wave 확장 (기존) | `.light` 연속 |
| Long press 차트 | overlay scale-in + vibrate | `.rigid` |

### Phase 4: 점수 도달 Celebration

점수가 특정 임계값에 도달했을 때 축하 효과:

- **Condition 80+**: 골드 particle burst + ring glow pulse
- **Wellness 90+**: 은은한 shimmer wave
- **Training Readiness "Ready"**: 에너지 pulse effect
- **PR 달성**: confetti-style particle + badge bounce

## Constraints

### 기술적 제약
- `reduceMotion` 대응 필수 (모든 Rich 효과에 instant fallback)
- LazyVGrid/LazyVStack 내 애니메이션은 visible cell만 트리거
- Canvas 기반 particle은 cell reuse 시 clean up 필요
- `.matchedGeometryEffect`는 NavigationStack 전환에서 제한적 → custom transition 필요할 수 있음

### 성능 제약
- 동시 애니메이션 8개 이하 유지 (GPU 과부하 방지)
- Particle effect는 Canvas 기반 (SwiftUI View 개별 생성 금지)
- stagger max index 제한 (화면 밖 요소는 즉시 표시)
- Score counter는 `TimelineView` 대신 `.animation` 기반

### 기존 시스템 호환
- Wave Background 시스템과 충돌 없이 공존
- DS.Animation 기존 프리셋 하위호환 유지
- ChartSelectionOverlay 제스처와 pressable 제스처 충돌 방지

## Edge Cases

1. **데이터 없는 화면**: 빈 상태도 graceful 등장 애니메이션 적용
2. **빠른 탭 전환**: 이전 탭 애니메이션 즉시 완료 처리
3. **Background → Foreground**: 복귀 시 re-animate 여부 결정 (NO: 이미 보인 데이터)
4. **스크롤 중 데이터 로드**: 이미 스크롤된 위치의 카드는 stagger 없이 즉시 표시
5. **iPad Split View**: 넓은 화면에서 stagger 방향 (LTR 추가 고려)
6. **대량 카드 (10+)**: stagger max 적용, 나머지는 일괄 fade
7. **Celebration 중복**: 짧은 시간 내 여러 달성 시 queue 처리
8. **watchOS**: Watch에는 별도 경량 애니메이션 정책 (이 브레인스톰 범위 외)

## Scope

### MVP (Must-have)
- [ ] DS.Animation Rich 프리셋 추가
- [ ] `.staggeredAppear(index:)` ViewModifier
- [ ] `.pressable()` ViewModifier + haptic
- [ ] `.scoreCounter(value:)` enhanced ViewModifier
- [ ] Dashboard: Hero card entrance + score drama
- [ ] Dashboard: Insight cards stagger
- [ ] Activity: Hero card + weekly stats stagger
- [ ] Wellness: Hero card + vital cards stagger
- [ ] Life: Habit rows stagger + check animation
- [ ] Detail views: chart draw animation (line/bar)
- [ ] Detail views: hero score ring entrance
- [ ] `reduceMotion` 전체 대응

### Nice-to-have (Future)
- [ ] Particle celebration effects (PR 달성, 고점수)
- [ ] 카드→상세 zoom morph transition
- [ ] Typewriter text reveal (coaching card)
- [ ] Muscle map 영역별 sequential color fill
- [ ] Heatmap cascade fill animation
- [ ] Parallax depth on period transition
- [ ] 3D tilt press effect
- [ ] Blur dismiss transition for sheets
- [ ] Rest timer circular countdown redesign
- [ ] Workout completion celebration scene

## Resolved Questions

1. **Celebration 임계값**: Condition 80+, Wellness 90+, Training Readiness "Ready", PR 달성
2. **Watch**: 경량 버전 적용 (stagger + score counter 수준)
3. **Chart draw 방향**: 왼→오 (시간순) — 라인/에어리어/바 모두 시간축 기준
4. **Theme별 차별화**: 테마별 particle 색상/형태 차별화 (Desert=금색 모래, Ocean=물방울, Sakura=꽃잎 등)

## Open Questions

1. **Score counter 사운드**: 카운터 애니메이션에 사운드 효과 추가할지?

## Next Steps

- [ ] `/plan rich-animation-enhancement` 로 구현 계획 생성
- [ ] 공통 ViewModifier 우선 구현 후 한 탭에 적용하여 feel 테스트
- [ ] 성능 프로파일링 기준 수립 (Instruments Time Profiler)
