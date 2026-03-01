---
tags: [swiftui, animation, repeatForever, theme, environment, onAppear, task]
date: 2026-03-01
category: solution
status: implemented
---

# Wave Animation Freezes on Theme Change

## Problem

테마(Desert ↔ Ocean) 전환 시 웨이브 배경 애니메이션이 멈추고 재시작되지 않음.

## Root Cause

`TabWaveBackground`의 `switch theme` 분기가 뷰 트리를 재구성할 때, 새 뷰의 `.onAppear` 내 `withAnimation(.repeatForever)` 호출이 부모의 환경 변경 트랜잭션(environment transaction)과 충돌하여 애니메이션이 시작되지 않거나 즉시 소멸됨.

**발생 체인:**
1. `\.appTheme` environment 값 변경
2. `TabWaveBackground` switch branch 전환 → 기존 뷰 제거, 새 뷰 삽입
3. 새 `WaveOverlayView`/`OceanWaveOverlayView`의 `.onAppear` 실행
4. `.onAppear`가 부모 트랜잭션 내에서 동기 실행됨
5. `withAnimation(.repeatForever)` 가 해당 트랜잭션에 병합 → 애니메이션 소실

## Solution

`.onAppear` → `.task` 교체. `.task`는 async 컨텍스트로 실행되어 부모 트랜잭션을 자연스럽게 벗어남.

```swift
// BAD: .onAppear는 부모 트랜잭션 내에서 동기 실행
.onAppear {
    withAnimation(.linear(duration: 6).repeatForever(autoreverses: false)) {
        phase = 2 * .pi
    }
}

// GOOD: .task는 async 컨텍스트로 트랜잭션 격리 + 뷰 dismiss 시 자동 취소
.task {
    withAnimation(.linear(duration: 6).repeatForever(autoreverses: false)) {
        phase = 2 * .pi
    }
}
```

## Why `.task` over `DispatchQueue.main.async`

| 기준 | `.task` | `DispatchQueue.main.async` |
|------|---------|---------------------------|
| 트랜잭션 격리 | async 컨텍스트 | 다음 런루프 |
| 뷰 dismiss 안전성 | 자동 취소 | 취소 안 됨 (stale mutation 위험) |
| SwiftUI 네이티브 | O | X |
| 코드 의도 명확성 | 높음 | 낮음 (왜 async인지 불명확) |

## Prevention

- `.repeatForever` 애니메이션을 `.onAppear`에서 시작할 때, 부모 뷰가 environment 변경으로 재구성될 가능성이 있다면 `.task`를 사용
- environment 변경으로 switch/if-else 분기가 전환되는 뷰 내부의 애니메이션은 특히 주의

## Affected Files

- `DUNE/Presentation/Shared/Components/WaveShape.swift` (WaveOverlayView)
- `DUNE/Presentation/Shared/Components/OceanWaveShape.swift` (OceanWaveOverlayView)
