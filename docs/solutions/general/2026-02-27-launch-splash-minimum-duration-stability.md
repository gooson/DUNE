---
tags: [swiftui, splash-screen, launch-screen, startup-ux, task-cancellation, animation]
category: general
date: 2026-02-27
status: implemented
severity: important
related_files:
  - DUNE/App/DUNEApp.swift
  - CLAUDE.md
related_solutions:
  - docs/solutions/general/2026-02-26-app-icon-launch-screen-integration.md
---

# Solution: Launch Splash 최소 노출 1초 + 전환 안정화

## Problem

앱 실행 시 스플래시가 너무 빨리 사라져 브랜드 인지가 약했고, 커스텀 스플래시 전환에서 시각적 점프와 타이밍 불안정 가능성이 있었다.

### Symptoms

- 앱 시작 직후 스플래시가 빠르게 사라져 체감상 "깜빡임"처럼 보임
- 시스템 Launch Screen에서 커스텀 스플래시로 넘어갈 때 로고 크기가 순간적으로 달라 보일 수 있음
- 최소 노출 시간을 `Task.sleep`으로 구현했지만 취소 시 즉시 닫혀 1초 보장이 깨질 수 있음

### Root Cause

- 최소 노출 시간 게이트가 앱 루트에 없었음
- 커스텀 스플래시 로고를 고정 프레임으로 렌더링해 Launch Screen 실표시 크기와 불일치 가능성 존재
- `try? await Task.sleep(...)`이 cancellation을 삼켜 조기 종료 경로를 허용

## Solution

`DUNEApp` 루트에서 스플래시 게이트를 도입하고, cancellation-safe 타이머 및 전환 안정화 처리를 적용했다.

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `DUNE/App/DUNEApp.swift` | `isShowingLaunchSplash`, `minimumLaunchSplashDuration(.seconds(1))` 추가 | 스플래시 최소 노출 1초 보장 |
| `DUNE/App/DUNEApp.swift` | 루트 `Group`에서 `LaunchSplashView` → `appContent` 분기 + opacity transition | 앱 시작 전환 흐름 명시화 |
| `DUNE/App/DUNEApp.swift` | `dismissLaunchSplashAfterMinimumDuration()`에서 `CancellationError` 명시 처리 + `Task.isCancelled` guard | cancellation 시 조기 dismiss 방지 |
| `DUNE/App/DUNEApp.swift` | `LaunchSplashView` 로고 고정 frame 제거 | Launch→Custom 스플래시 전환 점프 완화 |

### Key Code

```swift
@MainActor
private func dismissLaunchSplashAfterMinimumDuration() async {
    do {
        try await Task.sleep(for: Self.minimumLaunchSplashDuration)
    } catch is CancellationError {
        // Keep splash state unchanged when the task is cancelled.
        return
    } catch {
        return
    }

    guard !Task.isCancelled, isShowingLaunchSplash else { return }
    withAnimation(.easeOut(duration: 0.2)) {
        isShowingLaunchSplash = false
    }
}
```

```swift
private struct LaunchSplashView: View {
    var body: some View {
        ZStack {
            Color("LaunchBackground").ignoresSafeArea()
            Image("LaunchLogo")
        }
    }
}
```

## Prevention

### Checklist Addition

- [ ] 최소 노출 타이머 구현 시 `Task.sleep` cancellation 경로를 명시적으로 처리한다.
- [ ] Launch Screen과 연속 전환되는 커스텀 스플래시에서는 로고 크기 하드코딩을 피한다.
- [ ] 앱 진입 UI 게이트는 XCTest/UITest 동작(스킵 여부)을 의도적으로 분리한다.
- [ ] 변경 후 `xcodebuild build-for-testing`으로 최소 컴파일 회귀를 확인한다.

### Rule Addition (if applicable)

새 rule 파일은 추가하지 않았고, 재발 방지 지식은 `CLAUDE.md` Correction Log #141, #142로 축적했다.

## Lessons Learned

- "최소 노출 시간" 요구사항은 타이머 설정만으로 끝나지 않고 cancellation semantics까지 포함해야 한다.
- Launch Screen과 커스텀 스플래시를 이어붙일 때는 동일 자산을 쓰더라도 렌더링 제약(고정 프레임 여부) 차이로 체감 품질이 크게 달라진다.
- 스플래시 수정은 기능 검증뿐 아니라 시작 전환의 시각적 일관성까지 같이 확인해야 회귀가 줄어든다.
