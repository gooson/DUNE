---
topic: Sakura Dark Mode Readability Polish
date: 2026-03-03
status: implemented
confidence: medium
related_solutions:
  - docs/solutions/general/2026-03-03-sakura-wave-real-expression.md
  - docs/solutions/design/2026-03-02-sakura-calm-theme.md
related_brainstorms:
  - docs/brainstorms/2026-03-03-dark-sakura-mode.md
---

# Implementation Plan: Sakura Dark Mode Readability Polish

## Context

Sakura 테마는 라이트 모드에서 감성 품질이 좋지만, 다크 모드에서는 배경/카드 오버레이 강도가 높아 정보 레이어 분리가 약해진다.  
사용자 요구는 벚꽃 무드는 유지하면서 가독성을 은은하게 끌어올리고, 전체 인상을 더 고급스럽게 정제하는 것이다.

## Requirements

### Functional

- 다크 모드에서 Today/Detail/Sheet의 정보 식별성을 높인다.
- 사쿠라 테마의 벚꽃 모티프(꽃잎/가지)는 유지한다.
- 라이트 모드 비주얼은 최대한 유지한다.

### Non-functional

- UI 변경은 성능 저하 없이 동작해야 한다.
- 기존 테마 아키텍처(`AppTheme` + shared components)를 유지한다.
- 변경 범위는 사쿠라 전용 분기(dark-first) 중심으로 제한한다.

## Approach

다크 모드에서 “밝은 레이어 누적”을 줄이고 “깊이/분리감”을 늘리는 방향으로 조정한다.
- 배경: `SakuraWaveBackground` dark 강도(visibility/gradient/petal)를 미세 하향
- 카드: `GlassCard`/`SectionGroup` dark 사쿠라 surface/border/bloom 강도를 재균형
- 정보 우선: 배경과 카드 사이에 subtle dark veil을 추가해 텍스트 대비 확보

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| Text token 자체를 밝게 조정 (`TextSecondary` 등) | 즉시 가독성 상승 | 전 테마/전 화면 영향, 사쿠라 한정 개선 어려움 | 기각 |
| Sakura xcassets dark 값을 대폭 재설계 | 테마 일관성 강화 가능 | 영향 범위 큼, 회귀 위험 큼 | 보류 |
| 사쿠라 전용 dark overlay 강도 조정 + veil 추가 | 영향 범위 제한적, 목적 정합 높음 | 값 튜닝 필요 | 채택 |

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `DUNE/Presentation/Shared/Components/SakuraWaveBackground.swift` | Modify | dark 모드 배경 레이어 강도 및 스크림 보정 |
| `DUNE/Presentation/Shared/Components/GlassCard.swift` | Modify | dark 사쿠라 카드 surface/border/bloom 강도 정제 |
| `DUNE/Presentation/Shared/Components/SectionGroup.swift` | Modify | dark 사쿠라 섹션 surface/border 강도 정제 |

## Implementation Steps

### Step 1: Sakura Tab/Detail/Sheet 배경 dark 강도 조정

- **Files**: `SakuraWaveBackground.swift`
- **Changes**:
  - `visibilityBoost` 및 dark gradient opacity 하향
  - `SakuraPetalDriftView` dark boost 하향
  - 콘텐츠 영역 분리용 subtle dark veil 추가
- **Verification**:
  - 다크 모드 Today 화면에서 배경이 카드 텍스트를 방해하지 않는지 확인
  - 라이트 모드 시각 변화가 거의 없는지 확인

### Step 2: Sakura 카드 표면/보더 레이어 정제

- **Files**: `GlassCard.swift`, `SectionGroup.swift`
- **Changes**:
  - dark에서 밝은 ivory/petal 오버레이 비중 축소
  - dusk 기반 depth 레이어 추가
  - border/bloom 강도 소폭 하향으로 정돈된 프리미엄 무드 확보
- **Verification**:
  - Hero/Standard/Inline 카드의 정보 가독성 향상 확인
  - 사쿠라 감성이 유지되는지 육안 검증

### Step 3: Build/Test 기반 안정성 확인

- **Files**: 없음 (검증 단계)
- **Changes**:
  - iOS build 실행
  - 가능 시 테스트 스킴 빌드 확인
- **Verification**:
  - `xcodebuild` 결과 오류 0

## Edge Cases

| Case | Handling |
|------|----------|
| 날씨 atmosphere가 활성화된 Today 화면 | dark gradient + veil 조합으로 과도한 상단 광량 억제 |
| Reduce Motion 활성화 | petal drift 감소 상태에서도 branch/haze로 테마 인지 유지 |
| 다량 카드 노출 화면 | 카드/배경 명도 분리 강화로 텍스트 대비 유지 |

## Testing Strategy

- Unit tests: UI 스타일 조정 중심 변경으로 신규 유닛 테스트는 생략
- Integration tests: 없음
- Manual verification: iOS dark/light에서 Today/Detail/Sheet, Hero/Standard/Inline 카드 육안 점검

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| 다크에서 사쿠라 존재감이 약해짐 | Medium | Medium | dark boost를 완전 제거하지 않고 완만히 하향 |
| 카드가 너무 어두워져 무드 손실 | Low | Medium | dusk 레이어를 얇게 추가해 깊이만 확보 |
| 라이트 모드 회귀 | Low | High | dark 분기 위주로만 수정 |

## Confidence Assessment

- **Overall**: Medium
- **Reasoning**: 영향 파일이 명확하고 dark 분기 위주로 제한 가능하지만, 최종 품질 평가는 시각적 튜닝 결과에 의존한다.
