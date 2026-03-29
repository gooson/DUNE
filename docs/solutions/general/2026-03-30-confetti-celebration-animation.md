---
tags: [confetti, animation, canvas, particle, haptic, celebration, personal-records, gamification]
date: 2026-03-30
category: general
status: implemented
---

# Solution: Confetti Celebration Animation on PR Achievement

## Problem

운동 완료 후 새 PR 달성 시 시각적 축하 효과가 없어 gamification 경험이 약했음. WorkoutCompletionSheet에 체크마크 애니메이션만 있고 PR 달성의 성취감을 높이는 visual feedback이 부재.

## Solution

### Canvas 기반 Confetti 파티클 시스템

`ConfettiModifier.swift` — `.confetti(trigger:)` ViewModifier:

1. **파티클 모델** (`ConfettiParticle`):
   - 위치(x,y), 속도, 회전, 색상, 형태(circle/rectangle/triangle)
   - 중력 + 공기저항 물리 시뮬레이션
   - y > 0.6 이후 opacity fade out → y > 1.2 에서 만료

2. **렌더링** (`TimelineView(.animation)` + `Canvas`):
   - 60개 파티클 burst, ~2.5초 duration
   - Canvas의 `drawParticle()` 에서 transform + fill

3. **성능 최적화** (`@Observable ParticleStore`):
   - `@State var particles` 대신 class-backed store 사용
   - 이유: `@State` 값타입 배열 mutation이 매 프레임 full-body re-render 유발
   - `removeAll(where: \.isExpired)` 로 O(N) 일괄 제거 (O(N²) reverse-index 제거 대체)

4. **접근성** (`reduceMotion`):
   - 모션 감소 설정 시 confetti 대신 glow pulse 1회 표시

### 통합

`WorkoutCompletionSheet.swift`:
- `@State private var celebrationTrigger = 0`
- `prAchievements`가 비어있지 않으면 onAppear에서 trigger 발화
- `.sensoryFeedback(.success, trigger:)` haptic 동시 트리거

## Key Design Decisions

| 결정 | 이유 |
|------|------|
| Canvas (not SpriteKit) | 기존 프로젝트 패턴 (OceanWaveBackground), 추가 프레임워크 불필요 |
| ViewModifier 패턴 | `.confetti(trigger:)` 로 재사용 가능, 향후 다른 화면에도 적용 |
| `@Observable` class store | P1 성능 이슈 해결: 값타입 배열 mutation이 매 프레임 sheet body 재평가 유발 |
| `ParticleShape` (not `Shape`) | `SwiftUI.Shape` 프로토콜과 이름 충돌 방지 |
| 60 파티클 제한 | 시각적 효과 vs 성능 균형 |

## Prevention

- **Canvas 파티클 시스템에서 `@State` 값타입 배열 사용 금지**: 매 프레임 mutation이 있는 데이터는 `@Observable` class로 감싸서 SwiftUI body 재평가 범위를 Canvas overlay로 제한
- **reverse-index removal 패턴 금지**: `particles.remove(at: i)` in reversed loop → `removeAll(where:)` 로 대체
- **디자인 시스템 토큰은 소비자가 있을 때만 추가**: 사용하지 않는 프리셋은 dead code

## Lessons Learned

- Canvas + TimelineView 파티클 시스템은 SpriteKit 없이도 충분히 부드러운 결과를 만듦 (60 파티클 기준)
- `@State var [Struct]` 배열은 struct CoW 특성상 매번 copy → SwiftUI diff → 안쪽 view까지 re-render. 60fps 애니메이션에서는 class-backed store가 필수
- 테스트 파일 위치는 `project.yml` sources 경로와 일치해야 함 (DUNETests/ at repo root, not DUNE/DUNETests/)
