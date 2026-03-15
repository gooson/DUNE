---
tags: [posture, accessibility, haptics, animation, swiftui, ux-polish]
date: 2026-03-15
category: solution
status: implemented
---

# Posture UX Polish Bundle (#120-#123)

## Problem

자세 측정 기능의 핵심 로직은 완성되었으나 UX 폴리시가 부족:
- VoiceOver 접근성 레이블 없음
- 촬영 흐름에 햅틱 피드백 없음
- `capturePhase` 전환이 즉시 교체 (전환 애니메이션 없음)
- 점수 링이 결과값으로 즉시 표시 (입장 애니메이션 없음)

## Solution

### 1. 접근성 레이블 (#120)

**PostureCaptureView**: 카메라 프리뷰, 촬영 버튼(+hint), 카운트다운, 에러 오버레이에 `.accessibilityLabel` / `.accessibilityHint` 추가.

**PostureResultView**: 점수 링(`.accessibilityElement(children: .ignore)` + combined label), 사진 카드, 메트릭 행, 저장 버튼 hint 추가.

xcstrings에 8개 접근성 문자열의 ko/ja 번역 등록.

### 2. 햅틱 피드백 (#121)

프로젝트 표준 패턴인 `.sensoryFeedback()` SwiftUI modifier + counter trigger 사용:

```swift
// ViewModel
private(set) var hapticCountdown: Int = 0
private(set) var hapticSuccessCount: Int = 0
private(set) var hapticErrorCount: Int = 0

// View
.sensoryFeedback(.impact(weight: .light), trigger: viewModel.hapticCountdown)
.sensoryFeedback(.success, trigger: viewModel.hapticSuccessCount)
.sensoryFeedback(.error, trigger: viewModel.hapticErrorCount)
```

### 3. 상태 전환 애니메이션 (#122)

`.animation(DS.Animation.standard, value: viewModel.capturePhase)` + 각 phase overlay에 `.transition()` 지정:
- guiding/countdown/analyzing/error: `.transition(.opacity)`
- result: `.transition(.move(edge: .bottom).combined(with: .opacity))`

`PostureCapturePhase`가 이미 `Hashable`이므로 animation value로 직접 사용.

### 4. 점수 게이지 애니메이션 (#123)

`ProgressRingView` 패턴 적용:
- `@State private var animatedScore: Double = 0`
- `.trim(from: 0, to: animatedScore)` 으로 링 애니메이션
- `.task { withAnimation(DS.Animation.slow) { animatedScore = target } }`
- `@Environment(\.accessibilityReduceMotion)` 존중
- `.contentTransition(.numericText())` 으로 숫자 카운트업

## Prevention

### `.contentTransition(.numericText())` + `.animation()` 이중 적용 주의

`withAnimation`으로 값을 보간하면서 `.animation(_:value:)`을 동시에 걸면,
`withAnimation`이 매 프레임 값을 업데이트할 때마다 `.animation`이 추가 전환을 트리거하여
digit이 빠르게 깜빡이는 문제 발생.

**해결**: `withAnimation` 블록이 이미 애니메이션을 제어하므로 `.animation()` modifier 제거.

### 햅틱 trigger 패턴

UIKit `UIImpactFeedbackGenerator` 대신 SwiftUI `.sensoryFeedback()` modifier 사용.
counter 기반 trigger(`Int` 값 변경 시 발동)가 프로젝트 표준. Task cancellation 시 trigger가
더 이상 변경되지 않으므로 자동으로 중단됨.
