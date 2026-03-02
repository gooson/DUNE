---
tags: [theme, sakura, wave-background, premium, recovery, dark-mode, watch]
date: 2026-03-03
category: plan
status: approved
---

# Plan: Sakura WaveBackground Real Expression

## Summary

Sakura 테마를 “핑크색 테마” 수준에서 벗어나 실제 벚꽃 정체성을 가진 프리미엄 Recovery 테마로 고도화한다.  
핵심은 Forest 재활용 인상을 제거하고, WaveBackground/카드/watch 표현까지 사쿠라 고유 문법으로 통일하는 것이다.

## Affected Files

### New Files

| File | Purpose |
|------|---------|
| `DUNE/Presentation/Shared/Components/SakuraBranchShape.swift` | 사쿠라 가지 실루엣 Shape |
| `DUNETests/SakuraBranchShapeTests.swift` | SakuraBranchShape 기하/animatable 테스트 |

### Modified Files

| File | Change |
|------|--------|
| `DUNE/Presentation/Shared/Components/SakuraWaveBackground.swift` | petals/branch/haze 레이어로 사쿠라 고유 표현 강화 |
| `DUNE/Presentation/Shared/Components/SakuraPetalShape.swift` | 꽃잎 실루엣 파형 조정 (forest 유사성 제거) |
| `DUNE/Presentation/Shared/Components/GlassCard.swift` | Sakura 카드 프리미엄 강조(glow/surface) |
| `DUNEWatch/Views/WatchWaveBackground.swift` | watch 경량 Sakura 표현 추가 |
| `DUNETests/SakuraPetalShapeTests.swift` | shape 회귀/표현 강화 테스트 확장 |
| `docs/brainstorms/2026-03-03-sakura-wave-background-expression.md` | 요구사항 연결 참고 |

## Implementation Steps

### Step 1: Sakura 전용 시각 문법 확립

- `SakuraBranchShape` 추가:
  - 완만한 가지 베지어 + 미세 분지 노이즈 기반 실루엣
  - `animatableData`는 `phase`만 유지해 비용 최소화
- `SakuraPetalShape` 수식 조정:
  - 현재 ridge 중심 파형에서 벚꽃 군집형 곡선으로 이동
  - canopy-like 느낌 제거

### Step 2: WaveBackground 재구성 (iOS)

- `SakuraWaveBackground` 레이어 구조:
  - Back: ivory haze + bokashi
  - Mid: petal ridge layer
  - Front: branch silhouette accent
  - Accent: drifting petals overlay (Reduce Motion 대응)
- Tab/Detail/Sheet 모두 사쿠라 문법을 공유하되 강도만 다르게 조정

### Step 3: 다크모드 가시성 강화

- 다크모드에서 petal/haze 최소 opacity 상향
- leaf/branch 대비를 늘려 depth 유지
- 색상 블렌드가 탁해지지 않도록 overlay blend mode 정리

### Step 4: 카드 프리미엄감 강화

- `GlassCard`에 Sakura 전용:
  - border gradient 강조
  - subtle blossom glow/surface tint 추가
- “색상만 바뀐 카드”가 아닌 테마 정체성이 보이도록 조정

### Step 5: watchOS 경량화

- `WatchWaveBackground`에 Sakura 분기 추가:
  - 저비용 단일/이중 레이어 + sparse petal dots
  - 기본 sine 구조 유지하되 사쿠라 인지 가능한 시각 힌트 제공

### Step 6: 테스트 및 검증

- `SakuraBranchShapeTests` 신규:
  - path non-empty / zero rect empty / animatableData
- `SakuraPetalShapeTests` 확장:
  - phase 변이 및 profile 특성 회귀 검증
- 검증 명령:
  - `xcodebuild -project DUNE/DUNE.xcodeproj -scheme DUNE -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' build`
  - `xcodebuild -project DUNE/DUNE.xcodeproj -scheme DUNETests -destination 'generic/platform=iOS Simulator' build-for-testing`
  - 가능 시 targeted tests 실행

## Risks / Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| 레이어 증가로 렌더 비용 상승 | 중간 | watch 경량화, 파티클 수 상한, 정적 텍스처 재사용 |
| 다크모드에서 핑크톤 저대비 | 높음 | 다크 전용 opacity/contrast 보정 |
| 과한 장식으로 가독성 저하 | 중간 | 카드 강조는 subtle glow 범위로 제한, 텍스트 대비 우선 |
| Reduce Motion에서 테마 정체성 상실 | 중간 | 정적 branch/haze로 사쿠라 인지 유지 |

