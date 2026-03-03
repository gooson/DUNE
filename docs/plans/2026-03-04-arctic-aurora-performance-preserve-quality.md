---
topic: arctic-aurora-performance-preserve-quality
date: 2026-03-04
status: approved
confidence: high
related_solutions:
  - docs/solutions/design/2026-03-03-arctic-dawn-theme.md
  - docs/solutions/design/theme-wave-visual-upgrade.md
  - docs/solutions/general/2026-03-02-forest-theme-today-animation-freeze-fix.md
related_brainstorms:
  - docs/brainstorms/2026-03-04-arctic-aurora-performance-preserve-quality.md
---

# Implementation Plan: Arctic Aurora Performance Preserve Quality

## Context

Arctic Dawn 배경은 시각 품질이 높지만 iOS에서 레이어 수와 드로우 연산이 많아 프레임 안정성 리스크가 있다.
요구사항은 오로라 핵심 레이어(커튼/리본/엣지 글로우)를 모두 유지하면서 프레임 안정성을 우선 개선하는 것이다.
또한 저전력 모드에서는 품질 축소를 허용한다.

## Requirements

### Functional

- Arctic Dawn 배경의 핵심 레이어(커튼/리본/엣지 글로우)를 유지한다.
- iOS에서 프레임 안정성을 개선한다.
- 저전력 모드에서는 디테일 밀도를 자동 축소한다.
- Tab/Detail/Sheet 배경 모두 동일 정책을 적용한다.

### Non-functional

- 기존 테마 정체성(색/구도/모티프) 회귀를 만들지 않는다.
- 접근성 Reduce Motion 동작과 충돌하지 않는다.
- 변경 로직은 테스트 가능한 형태로 분리한다.

## Approach

Arctic 전용 LOD(Quality Profile)를 도입하고, 고비용 오버레이(커튼 필라멘트/마이크로 디테일/엣지 텍스처)의 반복 수를
품질 모드에 따라 조정한다. `normal`에서는 기존 인상을 유지하고, `conserve`(저전력/Reduce Motion)에서는
레이어는 유지하되 반복 밀도와 하이라이트를 줄여 draw cost를 낮춘다.

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| 전체 레이어를 `Canvas`로 재작성 | 큰 렌더링 최적화 잠재력 | 구현 범위 큼, 회귀 위험 큼 | 보류 |
| 오버레이 레이어 일부 제거 | 즉시 성능 개선 | 사용자 요구(핵심 레이어 전부 유지) 위배 | 기각 |
| LOD 도입 + 반복 밀도/필라멘트 축소 | 회귀 위험 낮음, 단계적 최적화 가능 | 절대 최대 성능 이득은 제한적 | 채택 |

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `DUNE/Presentation/Shared/Components/OceanWaveBackground.swift` | Modify | Arctic LOD 도입, 저전력 모드에서 마이크로 디테일/필라멘트/스파클 밀도 축소 |
| `DUNETests/WaveShapeTests.swift` | Modify | Arctic LOD 계산 로직 및 경계값 테스트 추가 |
| `docs/solutions/performance/2026-03-04-arctic-aurora-lod-frame-stability.md` | Add | 최적화 해결책 문서화 |

## Implementation Steps

### Step 1: Arctic LOD 모델 추가

- **Files**: `OceanWaveBackground.swift`
- **Changes**:
  - `ArcticAuroraQualityMode(normal/conserve)` 및 파생 강도(필라멘트 수, seed 밀도) 계산 유틸리티 추가
  - 저전력 모드 + Reduce Motion에서 `conserve` 선택
- **Verification**:
  - 빌드 성공
  - 품질 모드 분기 로직 단위 테스트 통과

### Step 2: 고비용 오버레이 반복 밀도 최적화

- **Files**: `OceanWaveBackground.swift`
- **Changes**:
  - `ArcticAuroraCurtainOverlayView`의 curtain/filament 반복 수를 quality 기반으로 조정
  - `ArcticAuroraMicroDetailOverlayView`의 strand/crest/sparkle 반복 수를 quality 기반으로 조정
  - `ArcticAuroraEdgeTextureOverlayView`의 sparkle 반복 수를 quality 기반으로 조정
  - Tab/Detail/Sheet에서 quality를 동일 기준으로 전달
- **Verification**:
  - UI 회귀 없이 빌드 성공
  - 저전력 모드에서 반복 수 감소가 코드상 확인됨

### Step 3: 테스트 보강

- **Files**: `DUNETests/WaveShapeTests.swift`
- **Changes**:
  - quality 모드별 repeat-count 계산 테스트
  - 경계값(최소 1 보장, conserve < normal) 테스트
- **Verification**:
  - `WaveShapeTests` 타깃 테스트 통과

### Step 4: 품질 검증 및 문서화

- **Files**: `docs/solutions/performance/...`
- **Changes**:
  - 변경 의도, 적용 포인트, 재발 방지 체크리스트 문서화
- **Verification**:
  - 문서 frontmatter/카테고리/태그 규칙 준수

## Edge Cases

| Case | Handling |
|------|----------|
| 저전력 모드 전환 중 화면 활성 | quality 계산을 매 `body` 평가에서 반영하여 다음 렌더 사이클에 자동 적용 |
| Reduce Motion + 저전력 동시 활성 | 가장 보수적인 `conserve` 모드 사용 |
| seed 축소로 인한 지나친 평면화 | 최소 반복 수 하한(>=1) 보장 + 핵심 레이어 유지 |
| 테마 전환 직후 애니메이션 재시작 | 기존 `.task` + `.onAppear` 재시작 패턴 유지 |

## Testing Strategy

- Unit tests:
  - `WaveShapeTests`에 Arctic LOD 계산 테스트 추가
- Integration tests:
  - `xcodebuild test`로 `DUNETests/WaveShapeTests` 실행
- Manual verification:
  - Arctic Dawn 테마 Tab/Detail/Sheet 시각 인상(커튼/리본/엣지 글로우) 유지 여부 확인
  - 저전력 모드에서 디테일 감소 및 끊김 완화 확인

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| 디테일 축소로 체감 품질 저하 | Medium | Medium | normal 모드 기본 유지, conserve는 저전력/Reduce Motion에서만 적용 |
| 반복 수 축소가 특정 화면에서 과도함 | Low | Medium | 모드별 하한값 설정 + Tab/Detail/Sheet 별 튜닝 가능 구조 유지 |
| 테스트 커버리지 부족 | Low | Medium | 계산 로직을 테스트 가능한 정적 유틸리티로 분리 |

## Confidence Assessment

- **Overall**: High
- **Reasoning**: 대규모 구조 변경 없이 고비용 반복 루프를 줄이는 방식이라 회귀 위험이 낮고, 요구사항(핵심 레이어 유지/저전력 축소 허용)과 직접 정합된다.
