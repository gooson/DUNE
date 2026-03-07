---
topic: widget-visual-refresh
date: 2026-03-07
status: draft
confidence: high
related_solutions: []
related_brainstorms:
  - docs/brainstorms/2026-03-07-widget-visual-refresh.md
---

# Implementation Plan: Widget Visual Refresh — Density Improvement

## Context

위젯 링 기반 UI(WidgetRingView, WidgetMetricTileView 등)는 이미 구현되어 있다. 현재 padding/spacing 값이 다소 넓어 시각적 밀도가 낮다. 링 크기를 키우고 간격을 줄여 콘텐츠 영역을 확장하며, Small 위젯에 업데이트 시각 정보를 추가한다.

리서치 근거:
- `WidgetDS.Layout`: `edgePadding` 14pt, `columnSpacing`/`rowSpacing` 8pt
- `WidgetMetricTileView`: ring size 52, VStack spacing 8, padding top 10/bottom 14/horizontal 6
- Large 위젯은 footer에 `scoreUpdatedAt` timestamp 표시하지만 Small 위젯은 미표시
- 기존 코드 패턴: `WidgetDS.Layout` 토큰으로 일괄 관리

## Requirements

### Functional

- 3개 위젯(Small, Medium, Large)의 padding/spacing이 줄어들어야 한다.
- Medium 위젯의 링이 현재보다 커져야 한다.
- Small 위젯에 업데이트 시각이 표시되어야 한다.
- 기존 placeholder/no-score 상태가 정상 동작해야 한다.

### Non-functional

- 위젯 빌드가 성공해야 한다.
- 기존 accessibility label이 유지되어야 한다.

## Approach

`WidgetDS.Layout` 토큰을 조정하고, `WidgetMetricTileView` 내부 spacing/padding을 줄이며, `SmallWidgetView`에 timestamp footer를 추가한다.

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| 토큰 + 타일 내부 조정 | 최소 수정으로 밀도 개선 | — | Accept |
| 위젯별 별도 padding 토큰 | 크기별 최적화 가능 | 토큰 수 증가, 과잉 설계 | Reject |

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `DUNEWidget/DesignSystem.swift` | modify | edgePadding 14→12, columnSpacing 8→6, rowSpacing 8→6 |
| `DUNEWidget/Views/WidgetScoreComponents.swift` | modify | WidgetMetricTileView: ring 52→56, VStack spacing 8→6, padding 조정 |
| `DUNEWidget/Views/SmallWidgetView.swift` | modify | footer에 scoreUpdatedAt timestamp 추가 |

## Implementation Steps

### Step 1: Adjust WidgetDS.Layout tokens

- **Files**: `DUNEWidget/DesignSystem.swift`
- **Changes**:
  - `edgePadding` 14 → 12
  - `columnSpacing` 8 → 6
  - `rowSpacing` 8 → 6
- **Verification**: 빌드 성공

### Step 2: Tighten WidgetMetricTileView

- **Files**: `DUNEWidget/Views/WidgetScoreComponents.swift`
- **Changes**:
  - VStack spacing 8 → 6
  - Ring size 52 → 56
  - `.padding(.top, 10)` → `.padding(.top, 6)`
  - `.padding(.bottom, 14)` → `.padding(.bottom, 10)`
  - `.padding(.horizontal, 6)` → `.padding(.horizontal, 4)`
- **Verification**: 빌드 성공

### Step 3: Add timestamp to SmallWidgetView

- **Files**: `DUNEWidget/Views/SmallWidgetView.swift`
- **Changes**:
  - footer에 `entry.scoreUpdatedAt` timestamp 추가 (LargeWidgetView footerRow 패턴 참조)
  - scoreUpdatedAt이 nil이면 "Today" fallback
- **Verification**: 빌드 성공, nil 케이스 처리 확인

## Edge Cases

| Case | Handling |
|------|----------|
| 모든 score가 nil | placeholder view 그대로 표시 |
| scoreUpdatedAt이 nil | "Today" 텍스트 fallback (Large 위젯과 동일) |
| lowestMetric이 nil | "Open DUNE" 텍스트 표시 유지 |

## Testing Strategy

- Unit tests: 해당 없음 (순수 UI spacing 변경)
- Build verification: `scripts/build-ios.sh` 성공
- Manual verification: 시뮬레이터에서 3개 위젯 크기 확인

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| spacing 축소로 작은 디바이스에서 잘림 | low | medium | minimumScaleFactor 기존 적용됨 |
| ring 확대로 타일 내 overflow | low | low | Spacer(minLength: 0) + frame maxHeight 적용됨 |

## Confidence Assessment

- **Overall**: High
- **Reasoning**: 순수 레이아웃 수치 변경으로 로직 영향 없음. 기존 패턴 내 조정.
