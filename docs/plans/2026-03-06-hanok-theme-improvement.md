---
topic: hanok-theme-improvement
date: 2026-03-06
status: implemented
confidence: high
related_solutions:
  - docs/solutions/design/hanok-theme-implementation.md
  - docs/solutions/design/hanok-dancheong-theme-renewal.md
  - docs/solutions/design/2026-03-05-shanks-theme-motif-enhancement.md
related_brainstorms:
  - docs/brainstorms/2026-03-05-hanok-theme-renewal.md
  - docs/brainstorms/2026-03-06-hanok-theme-improvement.md
---

# Implementation Plan: Hanok Theme Improvement

## Context

현재 한옥 테마는 옥색 기반 단청 리뉴얼과 sway animation까지는 반영되어 있지만, 사용자가 요구한 "한옥 특유의 그림/소재감"은 아직 약하다. 특히 궁전 기와 끝 문양, 기와 실루엣의 상징성, 한지 재료감이 충분하지 않아 앱 전체에서 premium한 한옥 인상이 부족하다.

## Requirements

### Functional

- Hanok theme가 iOS 주요 배경(Tab/Detail/Sheet)에서 기와/처마/궁전 기와 끝 문양을 더 명확히 보여야 한다.
- Hanok palette가 기와 청회색, 단청 포인트, 한지 surface 방향으로 재정렬되어야 한다.
- ThemePicker에서도 Hanok 테마의 정체성이 기존 테마 대비 더 잘 드러나야 한다.
- Watch 배경도 최소한의 Hanok motif를 반영해 iOS와 theme parity를 맞춰야 한다.

### Non-functional

- 기존 theme architecture와 asset prefix 규칙을 유지한다.
- `Reduce Motion`에서 animation은 자연스럽게 degrade 되어야 한다.
- 새 로직/shape는 기존 테스트 패턴을 따라 smoke test를 추가한다.
- project/xcodegen 재생성 없이 기존 파일 수정 중심으로 끝낸다.

## Approach

색상 토큰 이름은 유지하고 Hanok colorset 값을 재조정한다. 시각 정체성 강화를 위해 `HanokWaveBackground.swift`에 재사용 가능한 한옥 장식 모티프(shape + overlay)를 추가하고, Tab/Detail/Sheet 강도만 다르게 적용한다. Watch는 기존 `WatchWaveBackground.swift`에 Hanok 전용 분기를 추가해 parity를 맞춘다.

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| colorset만 추가 조정 | 변경 범위가 작음 | 사용자가 지적한 "그림/소재감 부재"를 해결 못함 | 기각 |
| Hanok 전용 신규 background 파일을 iOS/watch 모두 추가 | 구조가 명확함 | project/source 등록, 파급 범위 증가 | 기각 |
| 기존 Hanok background와 Watch background에 motif overlay를 삽입 | 현재 아키텍처 유지, 구현 속도 빠름, 회귀 위험 낮음 | 기존 파일 복잡도 소폭 증가 | 채택 |

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `docs/plans/2026-03-06-hanok-theme-improvement.md` | Add | 구현 계획 문서 |
| `Shared/Resources/Colors.xcassets/Hanok*.colorset/Contents.json` | Edit | 기와/단청/한지 방향으로 Hanok palette 재조정 |
| `DUNE/Presentation/Shared/Components/HanokWaveBackground.swift` | Edit | 한옥 장식 모티프, 기와 끝 문양, 한지/기와 highlight 강화 |
| `DUNE/Presentation/Settings/Components/ThemePickerSection.swift` | Edit | Hanok 선택 row의 시각 정체성 강화 |
| `DUNEWatch/Views/WatchWaveBackground.swift` | Edit | watch용 Hanok-specific background 처리 |
| `DUNETests/HanokEaveShapeTests.swift` | Edit | 새 motif shape smoke tests 추가 |
| `docs/solutions/design/2026-03-06-hanok-theme-materiality-enhancement.md` | Add | 해결책 문서화 |

## Implementation Steps

### Step 1: Hanok palette를 기와/단청/한지 방향으로 재정렬

- **Files**: `Shared/Resources/Colors.xcassets/Hanok*.colorset/Contents.json`
- **Changes**:
  - base, surface, score, tab/weather 계열을 더 기와 중심의 청회색/먹회색/한지톤으로 재조정
  - 단청 주홍/청록 포인트는 강조색으로 제한
- **Verification**:
  - asset 이름 변경 없이 existing code가 그대로 해석된다
  - light/dark 모두 대비가 유지된다

### Step 2: iOS Hanok background에 모티프 overlay 추가

- **Files**: `DUNE/Presentation/Shared/Components/HanokWaveBackground.swift`
- **Changes**:
  - 궁전 기와 끝 문양을 단순화한 shape 추가
  - Tab/Detail/Sheet 공통 재사용 overlay 추가
  - 기와 crest highlight와 한지 texture 밀도 조정
- **Verification**:
  - background가 컴파일되고 preview 구조를 깨지 않는다
  - `Reduce Motion`에서도 정적 표현으로 남는다

### Step 3: ThemePicker와 Watch 배경 parity 강화

- **Files**: `DUNE/Presentation/Settings/Components/ThemePickerSection.swift`, `DUNEWatch/Views/WatchWaveBackground.swift`
- **Changes**:
  - ThemePicker에서 Hanok row에 작은 장식 badge/feedback 추가
  - watch 배경에서 Hanok 전용 색상/overlay 분기 추가
- **Verification**:
  - Hanok 선택 시 iOS settings와 watch 홈 모두에서 정체성이 강화된다
  - 다른 테마 동작은 유지된다

### Step 4: 회귀 테스트와 문서화

- **Files**: `DUNETests/HanokEaveShapeTests.swift`, `docs/solutions/design/2026-03-06-hanok-theme-materiality-enhancement.md`
- **Changes**:
  - 새 한옥 motif shape smoke test 추가
  - 구현 이유, 체크리스트, 재발 방지 포인트를 solution doc으로 기록
- **Verification**:
  - `HanokEaveShapeTests`, `AppThemeTests` 중심 테스트가 통과한다
  - solution 문서가 documentation standard를 만족한다

## Edge Cases

| Case | Handling |
|------|----------|
| 장식 모티프가 작은 화면에서 노이즈처럼 보임 | 낮은 opacity + 단순화된 silhouette만 사용 |
| Dark mode에서 한지 질감이 탁해짐 | dark 전용 opacity 축소 + 대비 보정 |
| `Reduce Motion` 사용 시 배경이 빈약해짐 | animation만 비활성화하고 motif는 정적으로 유지 |
| watch 성능 저하 | watch는 저비용 overlay와 기존 wave 재사용만 허용 |

## Testing Strategy

- Unit tests: `DUNETests/HanokEaveShapeTests.swift`, `DUNETests/AppThemeTests.swift`
- Integration tests: `xcodebuild test`로 DUNETests 타깃 검증
- Manual verification:
  - iPhone light/dark에서 Hanok Today/Train/Wellness/Life 확인
  - Settings ThemePicker에서 Hanok row 시각 확인
  - Watch background에서 Hanok 색감/모티프 확인

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| motif overlay가 과해져 데이터 가독성 저하 | Medium | High | opacity를 낮게 유지하고 top/background 영역에만 배치 |
| colorset 재조정으로 기존 card/ring 대비가 깨짐 | Medium | Medium | shared theme surfaces와 ring gradient를 같이 확인 |
| watch 전용 분기 추가로 시각적 복잡도 상승 | Low | Medium | 신규 shape 없이 기존 wave 기반 오버레이만 사용 |

## Confidence Assessment

- **Overall**: High
- **Reasoning**: 기존 한옥 구현과 샹크스 모티프 강화 패턴이 이미 있어, 이번 작업은 같은 구조를 Hanok 쪽에 좁게 적용하면 된다.
