---
tags: [posture, ux, accessibility, haptics, animation]
date: 2026-03-15
category: plan
status: draft
---

# Posture UX Polish Bundle (#120, #121, #122, #123)

## Problem Statement

자세 측정 기능의 핵심 로직은 구현되었으나, UX 폴리시가 부족:
- VoiceOver 접근성 레이블 없음
- 촬영 흐름에 햅틱 피드백 없음
- capturePhase 전환이 즉시 교체 (전환 애니메이션 없음)
- 점수 링이 결과값으로 즉시 표시 (입장 애니메이션 없음)

## Affected Files

| 파일 | 변경 유형 | TODO |
|------|----------|------|
| `DUNE/Presentation/Posture/PostureCaptureView.swift` | 수정 | #120, #121, #122 |
| `DUNE/Presentation/Posture/PostureResultView.swift` | 수정 | #120, #123 |
| `DUNE/Presentation/Posture/PostureAssessmentViewModel.swift` | 수정 | #121 |

## Implementation Steps

### Step 1: 접근성 레이블 (#120)

**PostureCaptureView.swift**:
- 카메라 프리뷰: `.accessibilityLabel("Camera preview for posture assessment")`
- 촬영 버튼: `.accessibilityLabel("Capture photo")` + `.accessibilityHint`
- 카운트다운: `.accessibilityLabel("Countdown: \(count)")`
- 에러 오버레이: 메시지를 accessibilityLabel로

**PostureResultView.swift**:
- 점수 링: `.accessibilityLabel("Posture score \(score) out of 100")`
- 각 메트릭 행: `.accessibilityLabel` 조합 (이름 + 상태 + 값)
- 저장 버튼: `.accessibilityHint`
- 사진 카드: `.accessibilityLabel("Front/Side view capture")`

### Step 2: 햅틱 피드백 (#121)

기존 패턴: `.sensoryFeedback(.type, trigger: stateVar)` — 프로젝트 전체에서 이 SwiftUI 패턴 사용

**PostureCaptureView.swift**에 추가:
- countdown 변화: `.sensoryFeedback(.impact(weight: .light), trigger: countdownTrigger)`
  - capturePhase에서 countdown 값 추출하는 computed property 필요
- 촬영 순간 (capturing): `.sensoryFeedback(.impact(weight: .medium), trigger: capturingTrigger)`
- 분석 완료 (result): `.sensoryFeedback(.success, trigger: resultTrigger)`
- 에러: `.sensoryFeedback(.error, trigger: errorTrigger)`

**ViewModel에 trigger 프로퍼티 추가**:
- `var hapticCountdown: Int` — countdown 값 변화 시 트리거
- `var hapticSuccessCount: Int` — result 진입 시 +1
- `var hapticErrorCount: Int` — error 진입 시 +1

### Step 3: 상태 전환 애니메이션 (#122)

**PostureCaptureView.swift**:
- phaseOverlay에 `.animation(DS.Animation.standard, value: viewModel.capturePhase)` 추가
  - PostureCapturePhase가 이미 Hashable이므로 animation value로 사용 가능
- guiding → countdown: `.transition(.opacity)` 자동 적용
- countdown → capturing: flash effect는 간단한 opacity flash overlay
- analyzing → result: `.transition(.move(edge: .bottom).combined(with: .opacity))`
- error: `.transition(.opacity)`

주의: `.animation`은 body 최상위에서 적용, 개별 overlay에 `.transition` 지정

### Step 4: 점수 게이지 애니메이션 (#123)

**PostureResultView.swift**:
- 기존 `ProgressRingView` 재사용 불가 (ConditionScore 전용 gradient). 대신 동일 패턴 적용:
  - `@State private var animatedScore: Double = 0` 추가
  - `.trim(from: 0, to: CGFloat(score) / 100.0)` → `.trim(from: 0, to: animatedScore)`
  - `.task { withAnimation(DS.Animation.slow) { animatedScore = CGFloat(score) / 100.0 } }`
  - `@Environment(\.accessibilityReduceMotion)` 존중
- 숫자 카운트업: `Text("\(score)")` → `.contentTransition(.numericText())` + `.animation`

## Test Strategy

- `PostureAssessmentViewModelTests`: haptic trigger 프로퍼티 값 변화 검증 (countdown → +1, result → successCount+1, error → errorCount+1)
- UI 테스트 면제: SwiftUI View body (accessibility/animation은 UI 테스트 영역)

## Risks & Edge Cases

1. **capturePhase의 Hashable**: error(String) case가 있어 associated value 포함 — 이미 Hashable conform 확인됨
2. **reduceMotion**: 모든 애니메이션에서 `accessibilityReduceMotion` 환경 확인 필수
3. **countdown haptic**: countdown이 cancel되면 haptic도 중단되어야 함 — trigger 기반이므로 자동 처리
4. **flash effect**: 과도한 시각 효과는 photosensitive 사용자에 영향 — `accessibilityReduceMotion` 시 생략

## Existing Patterns Reused

- `.sensoryFeedback()` modifier (30+ 사용례)
- `DS.Animation.slow` / `DS.Animation.standard` (ProgressRingView 등)
- `.contentTransition(.numericText())` (PostureCaptureView countdown에 이미 사용)
- `@Environment(\.accessibilityReduceMotion)` (ProgressRingView)
