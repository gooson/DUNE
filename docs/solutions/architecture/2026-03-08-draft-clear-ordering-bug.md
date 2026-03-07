---
tags: [draft, data-loss, guard-ordering, clearDraft, defensive-coding, silent-failure, logging]
category: architecture
date: 2026-03-08
severity: critical
related_files:
  - DUNE/Presentation/Exercise/TemplateWorkoutView.swift
  - DUNE/Presentation/Exercise/TemplateWorkoutViewModel.swift
  - DUNE/Presentation/Exercise/CompoundWorkoutView.swift
  - DUNE/Presentation/Exercise/CompoundWorkoutViewModel.swift
  - DUNE/App/AppLogger.swift
related_solutions:
  - architecture/2026-03-08-workout-draft-persistence.md
---

# Solution: clearDraft() 호출 순서 버그 및 Draft 방어적 코딩

## Problem

### Symptoms

1. **데이터 손실**: 템플릿 운동에서 `finishWorkout()` 호출 시 저장된 레코드가 없으면(`savedRecords.isEmpty`) draft가 삭제된 후 dismiss됨 — 사용자의 진행 데이터가 완전 유실
2. **Silent failure**: Draft encode/decode 실패 시 아무 로그 없이 `nil` 반환 — 디버깅 불가
3. **중복 검증**: View의 `restoreFromDraftIfNeeded()`와 ViewModel의 `restoreFromDraft()`에서 동일한 `exerciseIDs` 비교가 중복 수행

### Root Cause

1. `clearDraft()`가 `guard !savedRecords.isEmpty` **이전에** 무조건 호출됨. 저장 레코드가 없어서 early return하는 경로에서도 draft가 삭제됨
2. `try? JSONEncoder().encode(draft)`의 실패가 `guard-else { return }`으로 처리되어 어떤 오류인지 식별 불가
3. View가 ViewModel 내부의 검증 로직(exerciseIDs 비교)을 알 필요 없이 중복 구현

## Solution

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `TemplateWorkoutView.swift` | `clearDraft()`를 guard 이후 양쪽 분기로 이동 | early return에서도 draft 보존 |
| `TemplateWorkoutView.swift` | `restoreFromDraftIfNeeded()` 검증을 ViewModel에 위임 | 중복 제거 |
| `TemplateWorkoutViewModel.swift` | `restoreFromDraft() -> Bool` 반환값 추가 | View가 결과로 분기 |
| `TemplateWorkoutViewModel.swift` | Draft save/load에 `AppLogger.exercise.error()` 추가 | Silent failure 해소 |
| `CompoundWorkoutView.swift` | 동일 패턴 적용 | 일관성 |
| `CompoundWorkoutViewModel.swift` | 동일 패턴 적용 | 일관성 |
| `AppLogger.swift` | `exercise` 카테고리 추가 | 운동 관련 로깅 경로 |

### Key Code

**P1: clearDraft() 순서 수정**

```swift
// BEFORE (BUG): clearDraft가 guard 앞에서 무조건 실행
private func finishWorkout() {
    TemplateWorkoutViewModel.clearDraft()  // ← 항상 삭제
    guard !savedRecords.isEmpty else {
        dismiss()
        return
    }
    // ... 공유 등 후처리
}

// AFTER: guard 분기 각각에서 적절한 시점에 호출
private func finishWorkout() {
    guard !savedRecords.isEmpty else {
        TemplateWorkoutViewModel.clearDraft()
        dismiss()
        return
    }
    TemplateWorkoutViewModel.clearDraft()
    // ... 공유 등 후처리
}
```

**중복 검증 제거: ViewModel이 Bool 반환**

```swift
// ViewModel
@discardableResult
func restoreFromDraft(_ draft: TemplateWorkoutDraft) -> Bool {
    guard draft.exerciseIDs == config.exercises.map(\.id) else { return false }
    guard draft.exerciseSets.count == exerciseViewModels.count else { return false }
    // ... restore ...
    return true
}

// View — 검증 로직 제거, 결과만 사용
private func restoreFromDraftIfNeeded() {
    guard let draft = TemplateWorkoutDraft.load() else { return }
    guard viewModel.restoreFromDraft(draft) else {
        TemplateWorkoutDraft.clear()
        return
    }
}
```

**Silent failure 해소**

```swift
static func save(_ draft: TemplateWorkoutDraft) {
    guard let data = try? JSONEncoder().encode(draft) else {
        AppLogger.exercise.error("Failed to encode template workout draft")
        return
    }
    UserDefaults.standard.set(data, forKey: userDefaultsKey)
}
```

## Prevention

### Checklist Addition

- [ ] `guard` 이전에 side effect(삭제, 네트워크 호출 등)를 수행하지 않는가
- [ ] `try?`로 에러를 삼키는 코드에 로깅이 있는가
- [ ] View와 ViewModel 간 동일한 검증 로직이 중복되지 않는가

### Rule Addition (if applicable)

`swift-layer-boundaries.md`에 추가 고려:
- **검증 책임 소재**: 데이터 무결성 검증은 ViewModel에서 수행하고, View는 결과(Bool)만 사용

## Lessons Learned

1. **guard 이전 side effect 금지**: `guard` 문의 early return 경로에서 실행되면 안 되는 코드는 guard 이후에 배치. 특히 `clear()`, `delete()` 같은 파괴적 연산은 검증 통과 후 수행
2. **Silent failure는 디버깅의 적**: `try?`로 에러를 삼킬 때 최소한 `AppLogger`로 기록해야 프로덕션에서 문제 추적 가능
3. **검증 위임 패턴**: `restoreFromDraft() -> Bool`로 ViewModel이 검증+복원을 모두 담당하고 View는 성공/실패에 따른 UI 흐름만 처리. 검증 로직 중복과 불일치를 근본적으로 차단
