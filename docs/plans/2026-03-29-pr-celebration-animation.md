---
tags: [celebration, confetti, haptic, animation, personal-records, level-up, gamification]
date: 2026-03-29
category: plan
status: draft
---

# Plan: PR Celebration Animation

## Summary

운동 완료 후 새 PR 달성이나 레벨업이 감지되면 WorkoutCompletionSheet에 confetti 파티클 효과와 강화된 haptic 피드백을 추가한다.

## Affected Files

| File | Change Type | Description |
|------|------------|-------------|
| `DUNE/Presentation/Shared/ViewModifiers/ConfettiModifier.swift` | **New** | Canvas 기반 confetti 파티클 ViewModifier |
| `DUNE/Presentation/Exercise/Components/WorkoutCompletionSheet.swift` | Modify | confetti + haptic 트리거 추가 |
| `DUNE/Presentation/Shared/DesignSystem.swift` | Modify | celebration 애니메이션 프리셋 추가 |
| `Shared/Resources/Localizable.xcstrings` | Modify | 새 문자열 (Level Up! 축하 메시지) en/ko/ja |
| `DUNETests/ConfettiModifierTests.swift` | **New** | 파티클 생성/lifecycle 유닛 테스트 |

## Implementation Steps

### Step 1: ConfettiModifier (Canvas 기반 파티클 시스템)

새 ViewModifier `ConfettiModifier`를 `DUNE/Presentation/Shared/ViewModifiers/` 에 생성.

**설계:**
- `Canvas` + `TimelineView(.animation)` 기반 파티클 렌더링
- 파티클 모델: position, velocity, rotation, color, shape (circle/rect/triangle)
- 물리: gravity + random horizontal drift + spin
- Lifecycle: burst → fall → fade out → auto-remove
- 파티클 수: ~60 (performance 친화적)
- Duration: ~2.5초 (burst 0.3초 + fall 2.2초)
- `reduceMotion` 대응: confetti 스킵, 대신 간단한 glow pulse만 표시
- `.confetti(trigger:)` View extension으로 호출

**기존 패턴 참조:**
- `OceanWaveBackground.swift`: Canvas 렌더링 패턴
- `StaggeredAppearModifier.swift`: @State + .task 애니메이션 트리거 패턴

### Step 2: DS.Animation celebration 프리셋

`DesignSystem.swift`의 Animation enum에 추가:
```swift
static let celebrationBurst = Animation.spring(duration: 0.3, bounce: 0.2)
```

### Step 3: WorkoutCompletionSheet에 confetti + haptic 통합

**변경 사항:**
- `@State private var celebrationTrigger = 0` 추가
- PR 달성 시 (prAchievements.isEmpty == false): confetti 트리거 + `.success` haptic
- `.confetti(trigger: celebrationTrigger)` modifier를 sheet body에 추가
- `.sensoryFeedback(.success, trigger: celebrationTrigger)` 추가
- `onAppear`에서 기존 `showCelebration = true` 직후 `celebrationTrigger += 1`

**조건부 트리거:**
- `prAchievements`가 비어있으면 confetti/haptic 안 함 (일반 완료는 기존 체크마크만)
- PR 있으면 confetti + `.success` haptic

### Step 4: 유닛 테스트

`ConfettiModifierTests.swift`:
- 파티클 생성 수 검증
- 파티클 lifecycle (active → expired) 검증
- reduceMotion 시 파티클 생성 안 함 검증

### Step 5: Localization

현재 "Workout Complete!"와 "New PR!" 문자열은 이미 존재. 추가 문자열 불필요.
(confetti는 순수 비주얼 효과로 새 문자열 없음)

## Test Strategy

- **유닛 테스트**: ConfettiParticle 모델 생성/만료 로직
- **수동 검증**: 시뮬레이터에서 운동 완료 → PR 달성 시 confetti 표시 확인
- **reduceMotion**: 설정 변경 후 confetti 비활성화 확인

## Risks & Edge Cases

| Risk | Mitigation |
|------|-----------|
| Canvas 파티클 성능 (많은 파티클) | 60개 제한, expired 즉시 제거 |
| reduceMotion 미대응 | `@Environment(\.accessibilityReduceMotion)` 체크 |
| Sheet dismiss 중 animation leak | TimelineView가 view hierarchy에서 제거되면 자동 중단 |
| 기존 checkmark 애니메이션과 타이밍 충돌 | celebrationTrigger를 onAppear에서 동일 시점 발화 |

## Design Decisions

1. **Canvas 사용 (SpriteKit 아님)**: 기존 프로젝트가 Canvas 패턴 사용, 추가 프레임워크 의존 없음
2. **ViewModifier 패턴**: `.confetti(trigger:)`로 재사용 가능, 향후 다른 화면에도 적용 가능
3. **WorkoutCompletionSheet만 대상**: 가장 자연스러운 축하 시점. Activity 탭 진입 시 중복 축하는 과도함
4. **Level-up 별도 표시 없음 (이번 scope)**: TODO #153 scope는 confetti + haptic만. 레벨업 전용 full-screen overlay는 별도 TODO로 분리 가능
