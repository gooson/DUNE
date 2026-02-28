---
tags: [watchconnectivity, settings-sync, rest-timer, applicationContext, sendMessage]
date: 2026-03-01
category: solution
status: implemented
---

# Watch Settings Sync Pattern

## Problem

iOS 앱의 Settings에서 설정한 값(rest time 등)이 Watch에 전달되지 않아, Watch 워크아웃에서 항상 하드코딩된 기본값이 사용됨.

추가로, `applicationContext`를 read-modify-write 패턴으로 업데이트하면 동시 호출 시 데이터 손실 발생 가능.

## Solution

### 1. 이중 전달 (Dual Delivery)

```swift
// iOS: 설정 변경 시 즉시 전달 + 영속 context 갱신
func syncWorkoutSettingsToWatch() {
    let restSeconds = WorkoutSettingsStore.shared.restSeconds

    // Immediate: sendMessage (Watch 활성 시 즉시 도달)
    if WCSession.default.isReachable {
        WCSession.default.sendMessage(["globalRestSeconds": restSeconds], ...)
    }

    // Persistent: syncExerciseLibraryToWatch() 호출로 전체 context 재구성
    syncExerciseLibraryToWatch()
}
```

### 2. applicationContext Race 방지

**금지**: read-modify-write 패턴
```swift
// BAD: 동시 호출 시 상대방 키 덮어쓰기
var context = WCSession.default.applicationContext
context["globalRestSeconds"] = value
try WCSession.default.updateApplicationContext(context)
```

**권장**: 전체 context를 한 곳에서 구성
```swift
// GOOD: transferExerciseLibrary()가 모든 키를 포함
func transferExerciseLibrary(_ exercises: [WatchExerciseInfo]) {
    let context: [String: Any] = [
        "exerciseLibrary": data,
        "globalRestSeconds": WorkoutSettingsStore.shared.restSeconds,
    ]
    try WCSession.default.updateApplicationContext(context)
}
```

### 3. Watch 수신 검증

```swift
// Watch: 수신 값 검증 (isFinite + 범위)
if let restSeconds = parsed.globalRestSeconds,
   restSeconds.isFinite, (15...600).contains(restSeconds) {
    globalRestSeconds = restSeconds
}
```

### 4. Static Method에서 @MainActor 프로퍼티 접근 금지

```swift
// BAD: static method에서 @MainActor singleton 직접 접근
private static func estimateMinutes(entries: [TemplateEntry]) -> Int? {
    let rest = entry.restDuration ?? WatchConnectivityManager.shared.globalRestSeconds
}

// GOOD: 파라미터로 전달
private static func estimateMinutes(entries: [TemplateEntry], globalRestSeconds: TimeInterval) -> Int? {
    let rest = entry.restDuration ?? globalRestSeconds
}
// Call site (init, @MainActor context):
Self.estimateMinutes(entries: entries, globalRestSeconds: WatchConnectivityManager.shared.globalRestSeconds)
```

## Prevention

- `applicationContext` 업데이트는 단일 함수에서 전체 키를 구성 (read-modify-write 금지)
- Watch 수신 값은 항상 `isFinite` + 범위 검증
- `static` 함수에서 `@MainActor` 프로퍼티 직접 접근 금지 -> 파라미터 전달
- Settings 값은 `sendMessage`(즉시) + `applicationContext`(영속) 이중 전달

## Related

- Correction #69: Watch DTO 양쪽 target 동기화
- Correction #46: Watch `isReachable`은 computed property
- `input-validation.md`: 수학 함수 방어 패턴 (isFinite, 범위 체크)
