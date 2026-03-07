---
tags: [localization, dead-code, parallelization, review-pipeline, String-localized, TaskGroup]
date: 2026-03-07
category: general
status: implemented
---

# 대규모 머지 후 리뷰 발견사항 일괄 수정

## Problem

16개 PR (145파일, +7550/-1960 라인) 머지 후 6관점 리뷰에서 10건의 발견사항 식별:
- P1×2: Watch 미번역 문자열, 호출되지 않는 dead code
- P2×5: 순차 쿼리, 미번역 문자열, 미연결 코드 등
- P3×3: 디바운싱, 파일 구조, 파라미터 누락

## Solution

### 1. Watch 문자열 localization (P1-1, P2-3, P2-5)

**패턴**: `String` 프로퍼티에 사용자 대면 텍스트를 할당할 때 `String(localized:)` 필수.

```swift
// BEFORE: 번역 누락
return "No movement detected"

// AFTER: 3개 언어 지원
return String(localized: "No movement detected")
```

**핵심**: Swift의 `String(localized:)` + 보간은 `String.LocalizationValue`가 컴파일 타임에 포맷 키를 생성. `"\(count) exercises"`는 xcstrings 키 `"%lld exercises"`로 올바르게 매핑됨.

### 2. Dead code 제거 (P1-2)

`shouldSuggestLevelUp()` 메서드와 관련 테스트 2건 제거. 호출자 없음 확인 후 삭제.

### 3. TaskGroup 병렬화 (P2-1)

```swift
// BEFORE: 순차 (7회 await)
for offset in 1...7 {
    let stages = try await sleepService.fetchSleepStages(for: date)
}

// AFTER: 병렬 + 정렬 복원
await withTaskGroup(of: (Int, [SleepStage])?.self) { group in
    for offset in 1...7 {
        group.addTask { ... }
    }
    // offset 기준 정렬로 원래 순서 복원
    return results.sorted { $0.0 < $1.0 }.map(\.1)
}
```

### 4. 단수/복수 처리

```swift
// 영어 단수/복수 + ko/ja (구분 불필요)
let base = count == 1
    ? String(localized: "\(count) exercise")
    : String(localized: "\(count) exercises")
```

## Prevention

1. **PR 리뷰 시 L10N 체크리스트** 활용 (`.claude/rules/localization.md`)
2. **Dead code 감지**: 새 기능 추가 시 이전 구현 잔재 확인
3. **HealthKit 쿼리 4개+**: 자동으로 TaskGroup 패턴 적용 (`.claude/rules/healthkit-patterns.md`)
4. **리뷰어 false positive 주의**: Swift `String(localized:)` 보간 메커니즘에 대한 오해 빈발 — 컴파일러가 `String.LocalizationValue` 생성하므로 런타임 키 불일치 주장은 대부분 false positive
