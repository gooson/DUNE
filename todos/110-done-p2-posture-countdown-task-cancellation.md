---
source: review/swift-ui-expert, review/pr-reviewer
priority: p2
status: done
created: 2026-03-15
updated: 2026-03-15
---

# Countdown Task 저장 및 취소 처리

## 문제

`startCountdown()`가 `Task {}`를 저장하지 않아:
1. 빠른 이중 탭 시 두 개의 countdown Task가 동시 실행 가능
2. View dismiss 시 Task가 취소되지 않아 `performCapture()` 호출 시도
3. 취소 시 `.countdown` 상태에서 stuck

## 해결 방향

```swift
private var countdownTask: Task<Void, Never>?

func startCountdown() {
    countdownTask?.cancel()
    countdownTask = Task { ... }
}

func stopCamera() {
    countdownTask?.cancel()
    captureService.stopSession()
}
```

## 영향 파일

- `DUNE/Presentation/Posture/PostureAssessmentViewModel.swift`
