---
topic: posture-visualization-enhancement
date: 2026-03-15
status: draft
confidence: high
related_solutions: [posture-ux-polish-bundle, posture-assessment-vision-3d-pose]
related_brainstorms: []
---

# Implementation Plan: Posture Visualization Enhancement (#116, #117, #119)

## Context

자세 측정 Phase 1 (캡처+분석)과 UX 폴리시가 완료됨. 현재 결과 화면은:
- 관절 연결선이 단일 색상(흰색 0.6) — 상태별 구분 없음
- plumb line(이상 정렬선) 없음 — 편차를 직관적으로 파악 불가
- front/side 사진이 단순 HStack 나란히 배치 — 각 뷰별 메트릭 매핑 없음

이 세 TODO를 묶어 Phase 2 시각화를 완성한다.

## Requirements

### Functional

- **#116 Plumb Line**: 정면 — 두부~골반 수직선, 측면 — 귀~발목 수직선 (이상 vs 실제)
- **#117 색상 코딩 오버레이**: 관절 점/연결선을 normal(초록), caution(노랑), warning(빨강)으로 색상 코딩
- **#119 전면/측면 비교 레이아웃**: 각 사진 옆에 해당 captureType 메트릭만 표시

### Non-functional

- 기존 접근성 레이블 유지 및 확장
- `PostureStatus.color` 재사용 (PostureMetric+View.swift)
- `.clipped()` 적용 (chart rule과 동일한 이유 — overflow 방지)
- 3개 언어 xcstrings 등록

## Approach

기존 `JointOverlayView`를 확장하여 plumb line + 색상 코딩 추가. `PostureResultView`의 `captureImagesSection`을 재구성하여 per-capture metric 표시.

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| JointOverlayView에 직접 추가 | 단일 파일, 간단 | 파일이 커짐 | **채택** — 현재 120줄, 추가해도 관리 가능 |
| 별도 PlumbLineOverlay + ColorCodedOverlay | 관심사 분리 | 3개 overlay ZStack → 성능, 복잡도 | 기각 |

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `DUNE/Presentation/Posture/Components/JointOverlayView.swift` | Modify | plumb line 추가, 색상 코딩 적용 |
| `DUNE/Presentation/Posture/PostureResultView.swift` | Modify | captureImagesSection 재구성 (per-capture metrics) |
| `DUNE/Domain/Models/PostureMetric.swift` | Modify | metric → joint name 매핑 추가 |
| `Shared/Resources/Localizable.xcstrings` | Modify | 새 문자열 번역 등록 |

## Implementation Steps

### Step 1: PostureMetricType에 관련 joint name 매핑 추가

- **Files**: `PostureMetric.swift`
- **Changes**: `var affectedJointNames: Set<String>` computed property 추가. 각 metric이 영향을 미치는 관절 이름 반환.
- **Verification**: PostureMetricType.allCases 전부 affectedJointNames가 비어있지 않음

### Step 2: JointOverlayView에 색상 코딩 적용

- **Files**: `JointOverlayView.swift`
- **Changes**:
  - init에 `metrics: [PostureMetricResult]` 파라미터 추가
  - `jointColor(for:)` → metric status 기반 색상 반환
  - `connectionLines`에도 세그먼트별 색상 적용 (Path 대신 ForEach + 개별 Line)
- **Verification**: normal/caution/warning 상태의 관절이 각각 초록/노랑/빨강으로 표시

### Step 3: JointOverlayView에 plumb line 추가

- **Files**: `JointOverlayView.swift`
- **Changes**:
  - `plumbLine(scale:offsetX:offsetY:)` 메서드 추가
  - 정면: centerHead → root 사이 수직 이상선 (파란 점선) + 실제 정렬선 (흰 실선)
  - 측면: ear → ankle 수직 이상선 + 실제 정렬선
  - 이상선은 `.dash([6, 4])` 스타일
- **Verification**: 이상 정렬선과 실제 정렬선이 함께 표시되어 편차 확인 가능

### Step 4: PostureResultView 전면/측면 비교 레이아웃 재구성

- **Files**: `PostureResultView.swift`
- **Changes**:
  - `captureImagesSection` → 각 캡처 카드 아래에 해당 captureType 메트릭만 표시
  - 기존 `metricsSection`(combined 전체)은 유지하되, 캡처 카드와 연계된 서브 메트릭 표시 추가
  - 빈 캡처 카드에는 "Capture {type} view for detailed analysis" 안내
- **Verification**: front 카드 아래에 front metrics만, side 카드 아래에 side metrics만 표시

### Step 5: xcstrings 번역 등록

- **Files**: `Shared/Resources/Localizable.xcstrings`
- **Changes**: 새 UI 문자열의 ko/ja 번역 추가
- **Verification**: 3개 언어 모두 번역 존재

### Step 6: 호출부 업데이트

- **Files**: `PostureResultView.swift`
- **Changes**: `JointOverlayView` 호출에 `metrics` 파라미터 전달
- **Verification**: 빌드 성공

## Edge Cases

| Case | Handling |
|------|----------|
| 모든 metric이 unmeasurable | plumb line만 표시, 색상 코딩 없음 (기본 흰색) |
| 한쪽 캡처만 완료 | 빈 캡처 카드에 placeholder + 안내 텍스트 |
| joint imageX/imageY가 nil | plumb line에서 해당 관절 skip (기존 로직 유지) |
| metric이 없는 관절 | 기본 흰색 (현재와 동일) |

## Testing Strategy

- Unit tests: `PostureMetricType.affectedJointNames` 매핑 정확성 테스트
- Manual verification: 시뮬레이터에서 mock 데이터로 3가지 상태(normal/caution/warning) 확인
- Accessibility: VoiceOver로 새 레이블 확인

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| 연결선 색상별 분할 시 Path 성능 | Low | Low | ForEach 개별 Line은 관절 수(~16)가 적어 무시 가능 |
| plumb line이 사진 밖으로 overflow | Low | Medium | `.clipped()` 적용 |

## Confidence Assessment

- **Overall**: High
- **Reasoning**: 기존 JointOverlayView 구조가 확장에 적합하고, PostureStatus.color가 이미 정의됨. 새 로직 없이 기존 데이터의 시각화만 추가.
