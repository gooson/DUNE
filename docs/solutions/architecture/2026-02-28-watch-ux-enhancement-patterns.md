---
tags: [watchos, swiftui, quick-start, template-card, set-input, session-summary, design-system, review-patterns]
date: 2026-02-28
category: architecture
status: implemented
---

# Watch UX Enhancement Patterns

## Problem

Watch 앱의 6개 화면에 정보 밀도가 부족하여 사용자가 운동 선택/실행/완료 과정에서 컨텍스트를 잃음:
1. QuickStartPickerView — 무게 표시 없음, 전체 목록이 플랫 리스트
2. TemplateCardView — 운동 수/세트 수/예상 시간 미표시
3. SetInputSheet — 이전 세트 히스토리 없어 무게/렙 기억 의존
4. SessionSummaryView — 운동별 볼륨 breakdown 없음
5. WorkoutPreviewView — 장비 아이콘 미표시

## Solution

### 1. QuickStartPickerView — 카테고리 그룹핑 + 무게 subtitle

**핵심 패턴**: `inputType` rawValue → 카테고리 라벨 매핑을 file-scope 함수로 추출.

```swift
// file-scope (두 struct에서 공유)
private func exerciseSubtitle(sets: Int, reps: Int, weight: Double?) -> String {
    var parts = "\(sets) sets · \(reps) reps"
    if let w = weight, w > 0, w <= 500 {
        parts += " · \(w.formattedWeight)kg"
    }
    return parts
}

private func categoryLabel(for inputType: String) -> String {
    switch inputType {
    case "setsRepsWeight": return "Strength"
    case "setsReps": return "Bodyweight"
    // ... exhaustive, default → "Other" + assertionFailure
    }
}
```

**그룹핑**: `Dictionary(grouping:)` + stable ordering array로 카테고리 순서 보장.

### 2. TemplateCardView — 메타 라벨 강화

```swift
// "4 exercises · 16 sets · ~45min"
private static func estimateMinutes(entries: [TemplateEntry]) -> Int? {
    let setExecutionSeconds: Double = 40
    // totalSeconds = sets × 40s + (sets-1) × restDuration
}
```

### 3. SetInputSheet — 이전 세트 히스토리 (toolbar 버튼 방식)

`previousSets: [CompletedSetData]` 파라미터로 전달. MetricsView에서 `@State cachedPreviousSets`로 캐싱하여 매 렌더 재계산 방지.

**캐시 갱신 시점**: `onAppear`, `onChange(of: currentExerciseIndex)`, `executeCompleteSet()` 후.

**레이아웃 패턴**: 이전 세트 데이터는 인라인 표시 대신 `.topBarLeading` toolbar 버튼 → NavigationStack push 방식. 무게 입력이 항상 sheet 최상단에 위치하여 즉시 접근 가능.

```swift
// Sheet 내부 NavigationStack + toolbar 버튼 패턴
NavigationStack {
    ScrollView { weightSection; repsSection }
        .toolbar {
            if !previousSets.isEmpty {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showPreviousSets = true } label: {
                        Image(systemName: "list.bullet.clipboard")
                    }
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
            }
        }
        .navigationDestination(isPresented: $showPreviousSets) {
            previousSetsDetail
        }
}
```

**핵심 원칙**: Watch 화면에서 빈번한 조작(무게 입력)은 최상단, 참고 데이터(이전 세트)는 명시적 액션 뒤에 배치.

### 4. SessionSummaryView — 볼륨 breakdown

```swift
// bodyweight(volume=0) → "3 sets", weighted → "3 sets · 2,400kg"
Text(volume > 0
    ? "\(sets.count) sets · \(volume.formattedWithSeparator)kg"
    : "\(sets.count) sets")
```

**안전장치**: `isFinite` guard + 50,000kg 상한 (Correction #85).

### 5. Double.formattedWeight

```swift
extension Double {
    var formattedWeight: String {
        WatchFormatterCache.weightFormatter.string(from: NSNumber(value: self))
            ?? String(format: "%.1f", self)
    }
}
```

`NumberFormatter` static 캐싱으로 hot path 할당 방지 (Correction #80).

## 리뷰에서 발견된 주요 패턴

| Finding | Pattern | 적용 |
|---------|---------|------|
| 같은 파일 내 동일 함수 2개 | file-scope private func 추출 | exerciseSubtitle |
| `default:` in classification switch | assertionFailure + "Other" bucket | categoryLabel |
| computed property in sheet | @State 캐싱 + 명시적 갱신 | cachedPreviousSets |
| aggregate 무한대/overflow | isFinite guard + 물리적 상한 | exerciseVolume |
| 0 값 표시 오해 | volume > 0 분기 | bodyweight "0kg" 제거 |
| stale cache on mode switch | 양쪽 분기에서 상대편 초기화 | cachedFiltered/cachedGrouped |
| onChange(of: array) | .count로 축소 (#47) | exerciseLibrary |

## Prevention

1. **같은 파일 내 struct 간 함수 중복** → file-scope private func 즉시 추출 (Correction #37 확장)
2. **분류 switch에 `default:` 금지** → assertionFailure + fallback bucket (#93)
3. **sheet에 전달하는 computed property** → @State 캐싱 + 명시적 갱신 시점 정의
4. **aggregate 값 UI 표시** → isFinite + 물리적 상한 (#85) + 0 값 분기
5. **Watch 숫자 포맷** → `formattedWeight` / `formattedWithSeparator` 경유 필수 (#97)

## Affected Files

| File | Changes |
|------|---------|
| `DUNEWatch/Views/QuickStartPickerView.swift` | 카테고리 그룹핑, weight subtitle, DRY 추출 |
| `DUNEWatch/Views/Components/TemplateCardView.swift` | 메타 라벨 (sets/time/names) |
| `DUNEWatch/Views/SetInputSheet.swift` | 이전 세트 히스토리 |
| `DUNEWatch/Views/MetricsView.swift` | @State 캐싱, index guard |
| `DUNEWatch/Views/SessionSummaryView.swift` | 볼륨 breakdown, isFinite, DS 토큰 |
| `DUNEWatch/Views/WorkoutPreviewView.swift` | 장비 아이콘 |
| `DUNEWatch/DesignSystem.swift` | tinyLabel 토큰 추가 |
