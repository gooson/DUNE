---
topic: widget-visual-refresh
date: 2026-03-07
status: approved
confidence: medium
related_solutions:
  - docs/solutions/architecture/widget-extension-data-sharing.md
  - docs/solutions/general/hero-ring-label-consistency.md
related_brainstorms:
  - docs/brainstorms/2026-03-07-widget-visual-refresh.md
---

# Implementation Plan: Widget Visual Refresh

## Context

현재 위젯은 점수 전달은 되지만, Medium의 3개 컬럼 간격이 넓고 Large의 빈 공간이 커서 홈 화면에서 빠르게 읽히는 밀도가 부족하다. 이번 변경은 앱 히어로 카드의 링 감성을 widget-safe 방식으로 이식하면서, Small/Medium/Large 전체를 더 촘촘한 레이아웃으로 재구성하는 것이 목표다.

## Requirements

### Functional

- Small / Medium / Large 모든 위젯 사이즈를 개선한다.
- 각 점수(Condition / Readiness / Wellness)를 기존보다 더 빨리 비교할 수 있어야 한다.
- 히어로 카드와 동일 구현은 아니더라도, 링 중심의 시각 인상을 공유해야 한다.
- 점수 누락 시 빈 칸 삭제 대신 placeholder slot을 보여준다.
- Large 위젯의 빈 공간을 줄이고 점수-상태-메시지 위계를 정리한다.

### Non-functional

- WidgetKit 제약에 맞게 가벼운 SwiftUI 구현을 유지한다.
- 기존 status color / label 매핑은 재사용한다.
- 중복 레이아웃 로직은 widget shared component로 추출한다.
- localization 규칙을 위반하지 않도록 widget target의 문자열 리소스 경로를 점검한다.

## Approach

`DUNEWidget` 내부에 widget 전용 링/카드 컴포넌트를 추가하고, `WellnessDashboardEntry`를 3개의 고정 slot 모델로 변환해 모든 사이즈가 같은 시각 언어를 공유하도록 구성한다. Small은 대표 점수 중심으로 압축하고, Medium은 3개 미니 링 컬럼으로 재배치하며, Large는 왼쪽 링 + 오른쪽 정보 행으로 밀도를 높인다.

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| 기존 텍스트/도트 구조 유지 + spacing만 축소 | 구현이 가장 단순 | 링 도입 목표를 충족하지 못함 | 기각 |
| 앱의 `ProgressRingView`를 widget target으로 직접 공유 | 시각 일관성 최대 | `DS` / `AppTheme` 의존성 확장 비용이 큼 | 기각 |
| widget 전용 lightweight ring 구현 | 위젯 제약에 맞게 단순화 가능 | 별도 컴포넌트 유지 필요 | 채택 |

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `docs/plans/2026-03-07-widget-visual-refresh.md` | CREATE | 구현 계획 문서 |
| `DUNEWidget/Views/SmallWidgetView.swift` | MODIFY | Small 레이아웃 재구성 |
| `DUNEWidget/Views/MediumWidgetView.swift` | MODIFY | 미니 링 3컬럼 레이아웃으로 재구성 |
| `DUNEWidget/Views/LargeWidgetView.swift` | MODIFY | 고밀도 row 레이아웃 + placeholder slot 적용 |
| `DUNEWidget/WellnessDashboardEntry.swift` | MODIFY | 3개 고정 slot 표현용 helper 추가 |
| `DUNEWidget/DesignSystem.swift` | MODIFY | 링/카드용 widget visual tokens 보강 |
| `DUNEWidget/Views/WidgetPlaceholderView.swift` | MODIFY | 새 시각 언어와 균형 맞춤 |
| `DUNEWidget/Views/WidgetScoreComponents.swift` | CREATE | widget 전용 ring/tile/row 공통 컴포넌트 |
| `DUNE/project.yml` | MODIFY | 필요 시 widget target에 `Localizable.xcstrings` 공유 |
| `DUNE/Resources/Localizable.xcstrings` | MODIFY | widget 신규/재사용 문자열 등록 시 보강 |

## Implementation Steps

### Step 1: Shared widget metric abstraction

- **Files**: `DUNEWidget/WellnessDashboardEntry.swift`, `DUNEWidget/Views/WidgetScoreComponents.swift`
- **Changes**:
  - 3개 점수를 고정 순서 slot으로 노출하는 helper 모델 추가
  - score 유무와 관계없이 렌더 가능한 placeholder-aware metric shape 정의
  - lightweight ring view와 공통 label/status subview 작성
- **Verification**:
  - Small/Medium/Large가 같은 helper를 사용해 렌더링 가능
  - missing score에서도 slot 수가 유지됨

### Step 2: Refresh all widget family layouts

- **Files**: `DUNEWidget/Views/SmallWidgetView.swift`, `DUNEWidget/Views/MediumWidgetView.swift`, `DUNEWidget/Views/LargeWidgetView.swift`, `DUNEWidget/Views/WidgetPlaceholderView.swift`, `DUNEWidget/DesignSystem.swift`
- **Changes**:
  - Small: 대표 점수 우선 또는 압축형 3점수 배치로 정보 밀도 재설계
  - Medium: 미니 링 3컬럼 + 짧은 상태 텍스트 구조로 전환
  - Large: 왼쪽 링 + 오른쪽 상태/메시지 row 구성으로 빈 공간 축소
  - spacing, padding, typography hierarchy 조정
- **Verification**:
  - Medium 컬럼 간 간격이 눈에 띄게 감소
  - Large 하단/우측 빈 공간이 줄어듦
  - 점수가 없는 slot은 placeholder로 의도된 빈 상태를 표시

### Step 3: Localization and build integration

- **Files**: `DUNE/project.yml`, `DUNE/Resources/Localizable.xcstrings`
- **Changes**:
  - widget target이 app string catalog를 읽을 수 있도록 source 포함 여부 점검/수정
  - 새로 추가되는 widget 문자열이 있으면 xcstrings에 등록
- **Verification**:
  - project regeneration 후 widget target build가 통과
  - 리뷰 단계의 localization check에서 신규 누락이 없거나 최소화됨

## Edge Cases

| Case | Handling |
|------|----------|
| 1개 또는 2개 점수만 존재 | 고정 3-slot 구조 유지, 누락 slot은 placeholder 표시 |
| 낮은 점수의 어두운 색상 대비 부족 | 링 track과 텍스트 alpha를 분리해 대비 확보 |
| 긴 라벨이 좁은 폭에 들어가지 않음 | Small/Medium은 짧은 상태만 표시, message는 Large만 1줄 허용 |
| 모든 점수가 nil | 기존 full-widget placeholder 유지 |
| widget bundle localization 누락 | widget target에 xcstrings 공유 경로 추가 검토 |

## Testing Strategy

- Unit tests: 없음. 이번 변경은 SwiftUI widget view 레이아웃 중심이라 로직 테스트보다는 빌드 검증이 우선이다.
- Integration tests:
  - `scripts/build-ios.sh`
  - 필요 시 `xcodebuild build -project DUNE/DUNE.xcodeproj -scheme DUNEWidget`
- Manual verification:
  - widget preview placeholder 데이터 기준으로 Small/Medium/Large 시각 밀도 점검
  - missing score 시 placeholder slot 정렬 확인

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| Small에서 정보가 과밀해짐 | medium | medium | 대표 점수 우선 배치와 3점수 압축 배치를 비교 후 더 단순한 안 선택 |
| widget용 ring이 앱 hero와 너무 다르게 보임 | medium | low | 동일 gradient 방향성과 status color를 유지하되 디테일만 단순화 |
| localization review에서 widget 문자열 누락 발견 | high | medium | project.yml에 xcstrings 공유 추가 여부를 함께 처리 |
| project.yml 수정 후 생성물 불일치 | medium | medium | `scripts/build-ios.sh`로 regen + build 일괄 검증 |

## Confidence Assessment

- **Overall**: Medium
- **Reasoning**: 위젯 뷰 구조는 명확하지만, Small 정보 밀도와 widget target localization 처리 범위는 구현 중 조정이 필요하다.
