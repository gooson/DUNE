---
tags: [workout, draft, persistence, data-loss, scenePhase, userdefaults, background-termination]
category: architecture
date: 2026-03-08
severity: critical
related_files:
  - DUNE/Presentation/Exercise/CompoundWorkoutViewModel.swift
  - DUNE/Presentation/Exercise/CompoundWorkoutView.swift
  - DUNE/Presentation/Exercise/TemplateWorkoutViewModel.swift
  - DUNE/Presentation/Exercise/TemplateWorkoutView.swift
related_solutions: []
---

# Solution: 운동 중 앱 종료 시 세트 데이터 손실 방지

## Problem

### Symptoms

- 사용자가 운동 중 앱 전환/종료 시 입력한 세트 데이터 전부 유실
- 특히 장시간(30분+) 운동 후 전화/알림으로 앱이 백그라운드 종료되면 치명적

### Root Cause

`CompoundWorkoutViewModel`과 `TemplateWorkoutViewModel`의 세트 데이터가 순수 `@State`/`@Published`로만 유지됨. 앱이 백그라운드에서 OS에 의해 종료되면 메모리 상의 모든 진행 데이터가 사라짐. 영구 저장소(UserDefaults/SwiftData)로의 임시 저장 경로가 없었음.

## Solution

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `CompoundWorkoutViewModel.swift` | `CompoundWorkoutDraft` Codable struct + save/load/clear | 직렬화 가능한 드래프트 모델 |
| `CompoundWorkoutView.swift` | `.onChange(of: scenePhase)` → saveDraft | 백그라운드 전환 시 자동 저장 |
| `CompoundWorkoutView.swift` | `.onAppear` → restoreFromDraft | 앱 재시작 시 복원 |
| `CompoundWorkoutView.swift` | `saveAll()` 성공 후 clearDraft | 정상 저장 후 드래프트 정리 |
| `TemplateWorkoutViewModel.swift` | 동일 패턴 적용 (+ exerciseStatus 직렬화) | 템플릿 워크아웃도 보호 |
| `TemplateWorkoutView.swift` | 동일 scenePhase 통합 | 일관된 보호 |

### Key Code

```swift
// Draft 모델 (Codable for UserDefaults)
struct CompoundWorkoutDraft: Codable {
    struct DraftSet: Codable {
        let weight: Double
        let reps: Int
        let rpe: Double?
        let isWarmUp: Bool
        let memo: String?
    }
    let exerciseIDs: [String]
    let sets: [[DraftSet]]   // exercises × sets
    let savedAt: Date
}

// ViewModel
func saveDraft() {
    let draft = CompoundWorkoutDraft(
        exerciseIDs: exercises.map(\.id),
        sets: exercises.map { /* convert @State sets to DraftSet */ },
        savedAt: .now
    )
    CompoundWorkoutDraft.save(draft)
}

func restoreFromDraft(_ draft: CompoundWorkoutDraft) {
    // exerciseIDs 일치 확인 후 복원
    guard draft.exerciseIDs == exercises.map(\.id) else { return }
    // ... restore sets
}

// View
.onChange(of: scenePhase) { _, phase in
    if phase == .background { viewModel.saveDraft() }
}
.onAppear { restoreFromDraftIfNeeded() }
```

### 설계 결정

1. **UserDefaults 선택 이유**: SwiftData는 운동 세션 중 저장할 모델이 없고, 드래프트는 임시 데이터이므로 가벼운 UserDefaults가 적합
2. **exerciseIDs 검증**: 복원 시 현재 운동 구성과 드래프트 구성이 일치하는지 확인하여 데이터 불일치 방지
3. **clearDraft 시점**: 정상 저장(`saveAll`) 성공 후 즉시 클리어. `finishWorkout()`에서도 클리어

## Prevention

### Checklist Addition

- [ ] 장시간 사용자 입력 화면에 `scenePhase` 기반 드래프트 저장이 있는가
- [ ] 드래프트 복원 시 구성 일치 검증이 있는가
- [ ] 정상 저장 경로에서 드래프트 클리어가 호출되는가

## Lessons Learned

1. **@State 데이터의 취약성**: 장시간 입력 흐름에서 `@State`만 의존하면 OS 종료 시 데이터 유실. 중요 데이터는 `scenePhase == .background` 시점에 영구 저장소로 백업 필요
2. **Codable Draft 패턴**: ViewModel 내부에 `{Feature}Draft: Codable` struct를 정의하고, UserDefaults에 JSON으로 저장하는 패턴이 가볍고 효과적
3. **구성 검증 필수**: 드래프트 복원 시 "현재 상태와 저장 시점의 상태가 같은가" 검증 없이 복원하면 index out of bounds 등 crash 위험
