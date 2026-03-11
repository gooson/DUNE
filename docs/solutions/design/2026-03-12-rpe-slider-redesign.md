---
tags: [rpe, slider, ux, watchos, ios, help, accessibility]
date: 2026-03-12
category: solution
status: implemented
---

# RPE 슬라이더 + 문맥 도움말 리디자인

## Problem

세트 종료 후 RPE 입력이 직관적이지 않음. 숫자(6.0-10.0)만 나열된 9-버튼 UI는 각 값의 의미를 전달하지 못해 신규 사용자의 진입 장벽이 높음.

## Solution

### 핵심 변경

1. **iOS/Watch RPE 피커**: 9-button grid → `Slider(value:in:step:)` + 색상 스펙트럼
2. **문맥 도움말**: `?` 버튼 → 도움말 시트로 RPE-RIR 매핑 설명 제공
3. **nil 상태 처리**: `@State isActive` 패턴으로 미선택 상태를 "Tap to rate" UI로 표현

### nil 상태 처리 패턴

SwiftUI `Slider`는 `nil`을 네이티브로 지원하지 않으므로:

```swift
@State private var sliderValue: Double
@State private var isActive: Bool

init(rpe: Binding<Double?>) {
    _rpe = rpe
    _sliderValue = State(initialValue: rpe.wrappedValue ?? 8.0)
    _isActive = State(initialValue: rpe.wrappedValue != nil)
}
```

- **init-time 초기화**: `.task`가 아닌 `init`에서 State를 설정하여 inactive→active 전환 flash 방지
- **기본값 8.0**: 활성화 시 슬라이더 중앙부 Hard 구간에서 시작
- **clear 버튼**: `isActive = false` + `rpe = nil`로 완전 리셋

### 색상 스펙트럼 매핑

```swift
private var currentColor: Color {
    switch sliderValue {
    case ..<7.0: DS.Color.positive      // Green (Light)
    case 7.0..<8.0: DS.Color.caution    // Yellow (Moderate)
    case 8.0..<9.0: .orange             // Orange (Hard)
    default: DS.Color.negative           // Red (Very Hard / Max)
    }
}
```

### Watch 도움말 시트 주의사항

watchOS sheet 내부에 `NavigationStack` 금지 (watch-navigation.md). 따라서:
- `.toolbar` "Done" 버튼이 렌더링되지 않음
- 대신 ScrollView 컨텐츠 하단에 명시적 `Button("Done")` 배치

### 접근성

- 아이콘 전용 버튼에 `.accessibilityLabel` 필수
- 터치 타겟: iOS 44pt / watchOS 38pt 최소 크기 (`.frame(minWidth:minHeight:)`)
- 도움말 버튼은 inactive 상태에서도 노출하여 RPE 개념을 모르는 사용자도 접근 가능

## Prevention

- **Slider + nil 조합 시**: 항상 `init`에서 `@State` 초기화. `.task`/`.onAppear` 사용 시 flash 발생
- **watchOS sheet 내 toolbar**: NavigationStack 없이 toolbar 사용 불가. 명시적 버튼 배치
- **아이콘 버튼**: `.buttonStyle(.plain)` 사용 시 hit area 자동 확장 안 됨 → `.frame(minWidth:minHeight:)` 필수
- **Watch 수동 haptic**: `.play(.click)` on every onChange → `.sensoryFeedback` 사용하여 시스템 throttle 위임

## 수정 파일

| 파일 | 변경 |
|------|------|
| `SetRPEPickerView.swift` | 버튼→슬라이더, 색상 스펙트럼, 도움말 버튼 |
| `RPEHelpSheet.swift` | 신규: iOS 도움말 시트 |
| `WatchSetRPEPickerView.swift` | 그리드→슬라이더, Digital Crown |
| `WatchRPEHelpSheet.swift` | 신규: Watch 도움말 시트 |
| `Localizable.xcstrings` (×2) | 15개 신규 문자열 en/ko/ja |
