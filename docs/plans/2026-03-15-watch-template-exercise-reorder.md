---
tags: [watch, template, reorder, exercise, strength]
date: 2026-03-15
category: plan
status: draft
---

# Plan: Watch 템플릿 운동 순서 변경

## Summary

Watch에서 템플릿 운동의 순서를 임시로 변경하는 기능을 추가한다.
A) 프리뷰 화면에서 운동 시작 전 순서 변경, B) 세션 중 남은 운동 순서 변경.
원본 템플릿은 불변이며, 변경된 순서는 해당 세션에서만 적용된다.

## Affected Files

| 파일 | 변경 내용 | 신규/수정 |
|------|----------|----------|
| `DUNEWatch/Views/WorkoutPreviewView.swift` | 프리뷰 리스트에 롱프레스 + ↑↓ 이동 UI 추가 | 수정 |
| `DUNEWatch/Managers/WorkoutManager.swift` | `entries` mutable 복사, `moveExercise` 메서드, `completedSetsData`/`extraSetsPerExercise` 동기화 | 수정 |
| `DUNEWatch/Views/ControlsView.swift` | "Reorder" 버튼 추가 (세션 중 재정렬 진입점) | 수정 |
| `DUNEWatch/Views/WatchExerciseReorderView.swift` | Watch용 운동 순서 변경 Sheet (롱프레스 + ↑↓) | 신규 |
| `Shared/Resources/Localizable.xcstrings` | 새 문자열 번역 (en/ko/ja) | 수정 |

## Implementation Steps

### Step 1: WorkoutManager — mutable entries + moveExercise

**목표**: `templateSnapshot.entries`를 mutable copy로 관리하고 재정렬 메서드 추가

변경사항:
1. `WorkoutSessionTemplate.entries`를 `let` → `var`로 변경
2. `WorkoutManager`에 `moveExercise(fromIndex:direction:)` 메서드 추가
   - direction: `.up` 또는 `.down` (인접 항목과 swap)
   - `completedSetsData`, `extraSetsPerExercise` 동시 동기화
   - `currentExerciseIndex` identity 추적 (iOS `moveExercise` 패턴 참조)
   - 완료된 운동(completedSetsData[index]가 비어있지 않음) 이동 방지
3. `canMoveExercise(at:direction:)` 메서드 추가 (UI 버튼 활성화/비활성화)
4. `WorkoutRecoveryState`에 entries 순서 반영 (crash recovery 보존)

**검증 기준**:
- `moveExercise` 후 `currentEntry`가 동일 운동을 가리키는지
- `completedSetsData` 인덱스가 entries와 동기화되는지

### Step 2: WorkoutPreviewView — 프리뷰 재정렬 UI

**목표**: 운동 시작 전 순서를 변경할 수 있는 UI 추가

변경사항:
1. `snapshot`을 `@State private var entries: [TemplateEntry]`로 mutable copy
2. 각 운동 행에 `.contextMenu`로 "Move Up" / "Move Down" 버튼 추가
   - watchOS에서 롱프레스 → context menu가 표준 패턴
   - 첫 번째 항목: "Move Down"만, 마지막 항목: "Move Up"만
3. 재정렬된 entries로 `WorkoutSessionTemplate` 재구성 후 `startQuickWorkout` 호출
4. 순서 변경 시 번호(1, 2, 3...) 자동 업데이트

**검증 기준**:
- context menu에서 Move Up/Down 동작 확인
- 변경된 순서로 세션이 시작되는지

### Step 3: WatchExerciseReorderView — 세션 중 재정렬 Sheet

**목표**: 세션 중 남은 운동 순서를 변경하는 Sheet

변경사항:
1. 새 파일 `DUNEWatch/Views/WatchExerciseReorderView.swift` 생성
2. `WorkoutManager`의 entries를 표시하는 리스트
   - 현재 운동: ▶ 아이콘 + 하이라이트
   - 완료된 운동: ✓ 아이콘 + disabled
   - 미시작 운동: 번호 표시
3. 각 행에 `.contextMenu`로 "Move Up" / "Move Down"
   - 완료된 운동은 context menu 비활성
   - 현재 진행 중인 운동도 이동 가능 (위치만 변경)
4. `WorkoutManager.moveExercise(fromIndex:direction:)` 호출

**검증 기준**:
- 완료된 운동은 이동 불가
- 이동 후 currentExerciseIndex가 올바른 운동을 추적

### Step 4: ControlsView — 재정렬 진입점

**목표**: 세션 중 재정렬 Sheet로 진입하는 버튼 추가

변경사항:
1. `ControlsView`에 "Reorder" 버튼 추가 (Skip 버튼 아래)
   - 조건: strength 모드 + 미완료 운동 2개 이상
   - 아이콘: `arrow.up.arrow.down`
2. `@State private var showReorderSheet = false`
3. `.sheet(isPresented:)` → `WatchExerciseReorderView` 표시
   - watchOS sheet 내부 NavigationStack 금지 (watch-navigation.md 규칙)

**검증 기준**:
- 운동 1개 또는 모두 완료 시 Reorder 버튼 미표시
- Sheet에서 순서 변경 후 돌아오면 반영

### Step 5: Localization

**목표**: 새 UI 문자열의 en/ko/ja 번역 추가

문자열 목록:
- "Move Up" → ko: "위로 이동", ja: "上に移動"
- "Move Down" → ko: "아래로 이동", ja: "下に移動"
- "Reorder" → ko: "순서 변경", ja: "順序変更"
- "Reorder Exercises" → ko: "운동 순서 변경", ja: "エクササイズの順序変更"

## Test Strategy

### Unit Tests
- `WorkoutManagerMoveExerciseTests`: moveExercise의 entries/completedSetsData/extraSetsPerExercise 동기화 검증
- 경계 케이스: 첫 번째 항목 위로 이동, 마지막 항목 아래로 이동, 완료된 운동 이동 시도

### Manual Verification
- Watch 시뮬레이터에서 프리뷰 → context menu → 순서 변경 → 시작 → 올바른 순서 확인
- 세션 중 ControlsView → Reorder → 순서 변경 → 운동 진행 확인

## Risks & Edge Cases

| Risk | Mitigation |
|------|-----------|
| `extraSetsPerExercise`가 Int 인덱스 key 사용 | 이동 시 key 재매핑 필수 |
| Crash recovery 후 순서 복원 | `WorkoutRecoveryState.template`에 이미 entries 포함 — mutable entries 반영만 하면 됨 |
| context menu + 스크롤 충돌 | watchOS context menu는 시스템 관리이므로 충돌 없음 |
| 운동 10개+ 시 UX | 스크롤 내 context menu는 자연스러움, 추가 조치 불필요 |
| completedSetsData 인덱스 불일치 | moveExercise에서 배열 동시 이동으로 방지 |

## References

- iOS 구현: `ExerciseReorderSheet.swift`, `TemplateWorkoutViewModel.moveExercise`
- 기존 솔루션: `docs/solutions/architecture/2026-03-15-template-workout-exercise-reorder.md`
- Watch navigation 규칙: `.claude/rules/watch-navigation.md` (Sheet 내부 NavigationStack 금지)
